import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/audit/pharmacy_audit_hooks.dart';
import '../../../core/constants/app_routes.dart';
import '../../../core/constants/receipt_branding.dart';
import '../../../core/supabase/supabase_bootstrap.dart';
import '../../settings/application/pharmacy_settings_providers.dart';
import '../../settings/domain/pharmacy_branding.dart';
import '../../../core/navigation/kpms_breakpoints.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/kpms_feedback.dart';
import '../../notifications/application/kpms_pharmacy_success_notifications.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/kpms_mobile_bottom_nav.dart';
import '../../../core/widgets/kpms_page_shell.dart';
import '../../debts/application/debt_customers_notifier.dart';
import '../../debts/presentation/debt_customer_picker_sheet.dart';
import '../../medicines/data/medicine_catalog_notifier.dart';
import '../../medicines/domain/medicine.dart';
import '../../medicines/domain/medicine_type_style.dart';
import '../application/pos_cart_notifier.dart';
import '../application/sales_ledger_notifier.dart';
import '../domain/cart_line.dart';
import '../../staff/application/staff_providers.dart';
import '../domain/completed_sale_invoice.dart';
import '../domain/sale_invoice.dart';
import '../domain/sale_settlement.dart';
import 'checkout_payment_workflow.dart';
import 'pharmacy_invoice_dialog.dart';

/// Full-screen checkout — list cart lines, summary, cash tender, complete sale.
class CheckoutScreen extends ConsumerStatefulWidget {
  const CheckoutScreen({super.key});

  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  final _discountCtrl = TextEditingController();
  final _cashCtrl = TextEditingController();
  final _customerNameCtrl = TextEditingController();
  final _customerPhoneCtrl = TextEditingController();
  final _customerNotesCtrl = TextEditingController();

  String _paymentMethod = CheckoutPaymentWorkflow.paymentMethods.first;
  SaleSettlementMode _settlement = SaleSettlementMode.paidInFull;
  bool _prefilledCashForSession = false;

  @override
  void dispose() {
    _discountCtrl.dispose();
    _cashCtrl.dispose();
    _customerNameCtrl.dispose();
    _customerPhoneCtrl.dispose();
    _customerNotesCtrl.dispose();
    super.dispose();
  }

  void _resetCheckoutAfterSuccessfulSale() {
    _discountCtrl.clear();
    _cashCtrl.clear();
    _customerNameCtrl.clear();
    _customerPhoneCtrl.clear();
    _customerNotesCtrl.clear();
    _paymentMethod = CheckoutPaymentWorkflow.paymentMethods.first;
    _settlement = SaleSettlementMode.paidInFull;
    _prefilledCashForSession = false;
    ref.read(posCartProvider.notifier).clear();
  }

  Future<void> _editSellPrice(BuildContext context, CartLine line) async {
    final ctrl = TextEditingController(text: line.unitSell.toStringAsFixed(2));
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Selling price · ${line.name}'),
        content: TextField(
          controller: ctrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          autofocus: true,
          decoration: const InputDecoration(prefixText: r'$ ', labelText: 'Per unit'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Apply')),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      final v = double.tryParse(ctrl.text);
      ctrl.dispose();
      if (v == null) return;
      ref.read(posCartProvider.notifier).setUnitSell(line.id, v);
      if (v < line.unitBuy) {
        kpmsSnack(context, 'Price below buying cost — fix before completing sale.', isError: true);
      }
      setState(() {});
    } else {
      ctrl.dispose();
    }
  }

  Future<void> _completeSale(
    BuildContext context, {
    required double subtotal,
    required double discount,
    required double tax,
    required double taxRate,
    required double grandTotal,
    required double recordProfit,
    required PharmacyBranding branding,
  }) async {
    final notifier = ref.read(posCartProvider.notifier);
    if (ref.read(posCartProvider).isEmpty) {
      kpmsSnack(context, 'Cart is empty', isError: true);
      return;
    }
    if (notifier.hasBlockingPrice) {
      showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          icon: Icon(Icons.gpp_maybe_rounded, color: Colors.orange.shade700, size: 36),
          title: const Text('Cannot complete'),
          content: const Text('Every line must sell at or above cost. Adjust prices in red first.'),
          actions: [FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK'))],
        ),
      );
      return;
    }

    final collected = double.tryParse(_cashCtrl.text.trim()) ?? 0;
    if (_settlement == SaleSettlementMode.paidInFull && collected + 0.009 < grandTotal) {
      kpmsSnack(context, 'Collected amount must cover the grand total', isError: true);
      return;
    }
    if (_settlement == SaleSettlementMode.partialDebt) {
      if (collected <= 0.009 || collected >= grandTotal - 0.009) {
        kpmsSnack(
          context,
          'Partial credit: enter an amount greater than 0 and less than the total',
          isError: true,
        );
        return;
      }
    }
    if (_settlement == SaleSettlementMode.fullDebt && collected > 0.009) {
      kpmsSnack(context, 'Credit sale: collected amount must be \$0', isError: true);
      return;
    }
    if (_settlement != SaleSettlementMode.paidInFull) {
      final n = _customerNameCtrl.text.trim();
      final p = _customerPhoneCtrl.text.trim();
      if (n.isEmpty || p.isEmpty) {
        kpmsSnack(context, 'Enter customer name and phone for credit sales', isError: true);
        return;
      }
    }

    final now = DateTime.now();
    final cartLines = ref.read(posCartProvider);
    final invoiceNumber = SaleInvoice.generateInvoiceNumber(now);
    final customerName = _customerNameCtrl.text.trim().isEmpty
        ? 'Walk-in customer'
        : _customerNameCtrl.text.trim();
    final customerPhoneRaw = _customerPhoneCtrl.text.trim();
    final customerPhoneLedger = customerPhoneRaw;
    final customerPhoneReceipt =
        customerPhoneRaw.isEmpty ? '—' : customerPhoneRaw;

    final debtNotes = _customerNotesCtrl.text.trim();
    String? debtCustomerId;
    List<SaleDebtLedgerEntry> debtLedger = [];
    double paidToward = grandTotal;
    double remaining = 0;
    SaleSettlementMode settlement = SaleSettlementMode.paidInFull;
    String ledgerPayMethod = _paymentMethod;

    switch (_settlement) {
      case SaleSettlementMode.paidInFull:
        settlement = SaleSettlementMode.paidInFull;
        paidToward = grandTotal;
        remaining = 0;
        debtLedger = [];
        break;
      case SaleSettlementMode.partialDebt:
        settlement = SaleSettlementMode.partialDebt;
        paidToward = collected.clamp(0.0, grandTotal);
        remaining = (grandTotal - paidToward).clamp(0.0, double.infinity);
        ledgerPayMethod = 'Partial · $_paymentMethod';
        debtLedger = [
          SaleDebtLedgerEntry(
            recordedAt: now,
            amount: paidToward,
            label: 'Paid at sale ($_paymentMethod)',
          ),
        ];
        final cust = ref.read(debtCustomersProvider.notifier).findOrCreate(
              name: customerName,
              phoneDisplay: customerPhoneRaw,
              notes: debtNotes,
            );
        debtCustomerId = cust.id;
        break;
      case SaleSettlementMode.fullDebt:
        settlement = SaleSettlementMode.fullDebt;
        paidToward = 0;
        remaining = grandTotal;
        ledgerPayMethod = 'Credit';
        debtLedger = [];
        final cust = ref.read(debtCustomersProvider.notifier).findOrCreate(
              name: customerName,
              phoneDisplay: customerPhoneRaw,
              notes: debtNotes,
            );
        debtCustomerId = cust.id;
        break;
    }

    final soldLines = <SoldLineItem>[
      for (var i = 0; i < cartLines.length; i++)
        SoldLineItem(
          lineId: 'sl_${now.microsecondsSinceEpoch}_$i',
          medicineId: cartLines[i].medicineId,
          name: cartLines[i].name,
          quantitySold: cartLines[i].quantity,
          quantityReturned: 0,
          unitSell: cartLines[i].unitSell,
          unitBuy: cartLines[i].unitBuy,
        ),
    ];

    final ledgerInvoice = CompletedSaleInvoice(
      invoiceNumber: invoiceNumber,
      issuedAt: now,
      customerName: customerName,
      customerPhone: customerPhoneLedger,
      paymentMethod: ledgerPayMethod,
      cashierName: branding.cashierLabel ?? KpmsReceiptBranding.defaultCashier,
      lines: soldLines,
      subtotal: subtotal,
      taxRate: taxRate,
      taxAmount: tax,
      discountAmount: discount,
      total: grandTotal,
      profitAtSale: recordProfit,
      settlementMode: settlement,
      paidTowardInvoice: paidToward,
      remainingBalance: remaining,
      debtCustomerId: debtCustomerId,
      debtCustomerNotes: debtNotes,
      debtLedger: debtLedger,
      cashierUserId: SupabaseBootstrap.clientOrNull?.auth.currentUser?.id,
    );

    final invoice = SaleInvoice(
      pharmacyName: branding.businessName,
      addressLine: branding.addressLine,
      phoneLine: branding.phoneLine,
      invoiceNumber: invoiceNumber,
      issuedAt: now,
      cashierLabel: branding.cashierLabel ?? KpmsReceiptBranding.defaultCashier,
      customerName: customerName,
      customerPhone: customerPhoneReceipt,
      paymentMethod: ledgerPayMethod,
      lines: [
        for (final l in cartLines)
          SaleInvoiceLine(
            itemName: l.name,
            quantity: l.quantity,
            amount: l.lineSubtotal,
          ),
      ],
      subtotal: subtotal,
      taxRate: taxRate,
      taxAmount: tax,
      discountAmount: discount,
      discountLabel: discount > 0.009 ? 'Discount (Member)' : 'Discount',
      total: grandTotal,
      paidTowardBill: settlement == SaleSettlementMode.paidInFull ? null : paidToward,
      balanceDueAfterSale: settlement == SaleSettlementMode.paidInFull ? null : remaining,
      creditStatusLabel: settlement.shortLabel,
      receiptFooter: branding.receiptFooter,
      showReceiptQr: branding.showReceiptQr,
      logoUrl: branding.logoUrl,
    );

    if (!notifier.completeSale(recordRevenue: grandTotal, recordProfit: recordProfit)) {
      return;
    }

    ref.read(salesLedgerProvider.notifier).addInvoice(ledgerInvoice);
    unawaited(PharmacyAuditHooks.saleCompleted(
      invoiceNumber: invoiceNumber,
      total: grandTotal,
    ));
    unawaited(
      ref.read(staffRepositoryProvider).tryLogActivity(
            action: 'sale_completed',
            entityType: 'sale_invoice',
            entityRef: invoiceNumber,
          ),
    );
    _resetCheckoutAfterSuccessfulSale();

    HapticFeedback.mediumImpact();
    if (!context.mounted) return;
    kpmsSnackSuccess(context, 'Sale completed');
    unawaited(KpmsPharmacySuccessNotifications.saleCompleted(
      ref,
      invoiceNumber: invoiceNumber,
      total: grandTotal,
    ));
    await showPharmacyInvoiceDialog(context, invoice);
    if (!context.mounted) return;
    context.canPop() ? context.pop() : context.go(AppRoutes.pos);
  }

  Medicine? _medicineFor(List<Medicine> catalog, CartLine line) {
    for (final m in catalog) {
      if (m.id == line.medicineId) return m;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final width = MediaQuery.sizeOf(context).width;
    final pad = KpmsBreakpoints.pagePaddingHorizontal(width);
    final wide = width >= 960;
    final clearance = KpmsMobileBottomNav.scrollClearanceBottom(context);

    final lines = ref.watch(posCartProvider);
    final notifier = ref.read(posCartProvider.notifier);
    final catalog = ref.watch(medicineCatalogProvider);
    final branding = ref.watch(pharmacyBrandingProvider);
    final taxRate = branding.taxRateFraction;

    if (lines.isEmpty) {
      _prefilledCashForSession = false;
    } else if (!_prefilledCashForSession && _settlement == SaleSettlementMode.paidInFull) {
      _prefilledCashForSession = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final sub = notifier.subtotal;
        final disc = (double.tryParse(_discountCtrl.text.trim()) ?? 0).clamp(0.0, sub);
        final taxable = (sub - disc).clamp(0.0, double.infinity);
        final g = taxable + taxable * taxRate;
        _cashCtrl.text = g.toStringAsFixed(2);
        setState(() {});
      });
    }

    final subtotal = notifier.subtotal;
    final grossProfit = notifier.totalProfit;

    final discountRaw = double.tryParse(_discountCtrl.text.trim()) ?? 0;
    final discount = discountRaw.clamp(0.0, subtotal);
    final taxable = (subtotal - discount).clamp(0.0, double.infinity);
    final tax = taxable * taxRate;
    final grandTotal = taxable + tax;
    final profitAdjusted =
        subtotal > 0 ? grossProfit * (taxable / subtotal) : 0.0;

    bool canComplete() {
      if (notifier.hasBlockingPrice) return false;
      final collected = double.tryParse(_cashCtrl.text.trim()) ?? 0;
      final nameOk = _customerNameCtrl.text.trim().isNotEmpty;
      final phoneOk = _customerPhoneCtrl.text.trim().isNotEmpty;
      switch (_settlement) {
        case SaleSettlementMode.paidInFull:
          return collected + 0.009 >= grandTotal;
        case SaleSettlementMode.partialDebt:
          return nameOk &&
              phoneOk &&
              collected > 0.009 &&
              collected < grandTotal - 0.009;
        case SaleSettlementMode.fullDebt:
          return nameOk && phoneOk && collected <= 0.009;
      }
    }

    if (lines.isEmpty) {
      return KpmsPageShell(
        title: 'Checkout',
        subtitle: 'Review cart and payment',
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.shopping_cart_outlined, size: 64, color: theme.hintColor),
                const SizedBox(height: 16),
                Text('Nothing to checkout', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                Text(
                  'Add items from Point of sale first.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(color: theme.hintColor),
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: () => context.go(AppRoutes.pos),
                  child: const Text('Go to POS'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final listSection = _CheckoutLineList(
      lines: lines,
      catalog: catalog,
      medicineFor: _medicineFor,
      onRemove: (id) {
        ref.read(posCartProvider.notifier).remove(id);
        setState(() {});
      },
      onQty: (id, q) {
        ref.read(posCartProvider.notifier).setQuantity(id, q);
        setState(() {});
      },
      onEditSell: (line) => _editSellPrice(context, line),
    );

    final paymentWorkflow = CheckoutPaymentWorkflow(
      settlement: _settlement,
      onSettlementChanged: (m) {
        setState(() {
          _settlement = m;
          if (m == SaleSettlementMode.paidInFull) {
            _cashCtrl.text = grandTotal.toStringAsFixed(2);
          } else if (m == SaleSettlementMode.fullDebt) {
            _cashCtrl.text = '0';
          } else {
            _cashCtrl.clear();
          }
        });
      },
      grandTotal: grandTotal,
      collectedController: _cashCtrl,
      onCollectedChanged: () => setState(() {}),
      paymentMethod: _paymentMethod,
      onPaymentMethodChanged: (v) => setState(() => _paymentMethod = v),
      customerNameController: _customerNameCtrl,
      customerPhoneController: _customerPhoneCtrl,
      customerNotesController: _customerNotesCtrl,
      onPickCustomer: () async {
        final c = await showDebtCustomerPickerSheet(
          context,
          initialName: _customerNameCtrl.text,
          initialPhone: _customerPhoneCtrl.text,
          initialNotes: _customerNotesCtrl.text,
        );
        if (c != null && context.mounted) {
          setState(() {
            _customerNameCtrl.text = c.name;
            _customerPhoneCtrl.text = c.phoneDisplay;
            if (c.notes.isNotEmpty) _customerNotesCtrl.text = c.notes;
          });
        }
      },
    );

    final summaryCard = _CheckoutSummaryCard(
      subtotal: subtotal,
      discount: discount,
      discountController: _discountCtrl,
      onDiscountChanged: () {
        if (_settlement == SaleSettlementMode.paidInFull) {
          final d = (double.tryParse(_discountCtrl.text.trim()) ?? 0).clamp(0.0, subtotal);
          final tx = (subtotal - d).clamp(0.0, double.infinity);
          final g = tx + tx * taxRate;
          _cashCtrl.text = g.toStringAsFixed(2);
        }
        setState(() {});
      },
      profit: profitAdjusted,
      taxRate: taxRate,
      tax: tax,
      grandTotal: grandTotal,
    );

    final completeBtn = _CheckoutCompleteButton(
      enabled: canComplete(),
      onPressed: () => _completeSale(
        context,
        subtotal: subtotal,
        discount: discount,
        tax: tax,
        taxRate: taxRate,
        grandTotal: grandTotal,
        recordProfit: profitAdjusted,
        branding: branding,
      ),
    );

    final body = wide
        ? Padding(
            padding: EdgeInsets.fromLTRB(pad, 8, pad, 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  flex: 5,
                  child: ScrollConfiguration(
                    behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
                    child: SingleChildScrollView(
                      child: listSection,
                    ),
                  ),
                ),
                const SizedBox(width: 24),
                Expanded(
                  flex: 4,
                  child: ScrollConfiguration(
                    behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          summaryCard,
                          const SizedBox(height: 16),
                          paymentWorkflow,
                          const SizedBox(height: 24),
                          completeBtn,
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          )
        : SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(pad, 8, pad, 16 + clearance),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                listSection,
                const SizedBox(height: 20),
                summaryCard,
                const SizedBox(height: 16),
                paymentWorkflow,
                const SizedBox(height: 20),
                completeBtn,
              ],
            ),
          );

    return KpmsPageShell(
      title: 'Checkout',
      subtitle: '${notifier.itemCount} items · review & pay',
      constrainContentWidth: false,
      body: body,
    );
  }
}

class _CheckoutLineList extends StatelessWidget {
  const _CheckoutLineList({
    required this.lines,
    required this.catalog,
    required this.medicineFor,
    required this.onRemove,
    required this.onQty,
    required this.onEditSell,
  });

  final List<CartLine> lines;
  final List<Medicine> catalog;
  final Medicine? Function(List<Medicine> catalog, CartLine line) medicineFor;
  final void Function(String id) onRemove;
  final void Function(String id, int qty) onQty;
  final void Function(CartLine line) onEditSell;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Order items',
          style: t.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.2),
        ),
        const SizedBox(height: 12),
        ...List.generate(lines.length, (i) {
          final line = lines[i];
          final med = medicineFor(catalog, line);
          return Padding(
            padding: EdgeInsets.only(bottom: i == lines.length - 1 ? 0 : 10),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: Duration(milliseconds: 240 + i * 35),
              curve: Curves.easeOutCubic,
              builder: (context, t, child) => Opacity(
                opacity: t,
                child: Transform.translate(offset: Offset(0, 8 * (1 - t)), child: child),
              ),
              child: _CheckoutLineTile(
                line: line,
                medicine: med,
                onRemove: () => onRemove(line.id),
                onQty: (q) => onQty(line.id, q),
                onEditSell: () => onEditSell(line),
              ),
            ),
          );
        }),
      ],
    );
  }
}

class _CheckoutLineTile extends StatelessWidget {
  const _CheckoutLineTile({
    required this.line,
    required this.medicine,
    required this.onRemove,
    required this.onQty,
    required this.onEditSell,
  });

  final CartLine line;
  final Medicine? medicine;
  final VoidCallback onRemove;
  final void Function(int qty) onQty;
  final VoidCallback onEditSell;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = medicine != null ? MedicineTypeStyle.resolve(medicine!) : null;
    final bad = line.priceViolatesFloor;

    return Material(
      color: theme.colorScheme.surface,
      elevation: 0,
      shadowColor: Colors.black.withValues(alpha: 0.12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: theme.colorScheme.outline.withValues(alpha: bad ? 0.45 : 0.14)),
      ),
      child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: SizedBox(
                  width: 52,
                  height: 52,
                  child: medicine?.imageBytes != null
                      ? Image.memory(medicine!.imageBytes!, fit: BoxFit.cover)
                      : DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: style != null
                                ? LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      style.softBg,
                                      style.accent.withValues(alpha: 0.2),
                                    ],
                                  )
                                : null,
                            color: style == null ? theme.colorScheme.surfaceContainerHighest : null,
                          ),
                          child: Icon(
                            style?.icon ?? Icons.medication_liquid_rounded,
                            color: style?.accent ?? AppColors.primary,
                            size: 26,
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      line.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: bad ? theme.colorScheme.error : null,
                      ),
                    ),
                    const SizedBox(height: 6),
                    InkWell(
                      onTap: onEditSell,
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          children: [
                            Text(
                              'Sell each ',
                              style: theme.textTheme.labelSmall?.copyWith(color: theme.hintColor),
                            ),
                            Text(
                              '\$${line.unitSell.toStringAsFixed(2)}',
                              style: theme.textTheme.labelLarge?.copyWith(
                                fontWeight: FontWeight.w900,
                                color: bad ? theme.colorScheme.error : AppColors.primary,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(Icons.edit_outlined, size: 15, color: theme.hintColor),
                          ],
                        ),
                      ),
                    ),
                    if (bad)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          'Below cost — adjust sell price',
                          style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.error),
                        ),
                      ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  IconButton(
                    tooltip: 'Remove',
                    onPressed: onRemove,
                    icon: Icon(Icons.close_rounded, color: theme.hintColor),
                    visualDensity: VisualDensity.compact,
                  ),
                  _QtyRow(
                    qty: line.quantity,
                    onMinus: () => onQty(line.quantity - 1),
                    onPlus: () => onQty(line.quantity + 1),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Line total',
                    style: theme.textTheme.labelSmall?.copyWith(color: theme.hintColor),
                  ),
                  Text(
                    '\$${line.lineSubtotal.toStringAsFixed(2)}',
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
                  ),
                ],
              ),
            ],
          ),
        ),
    );
  }
}

class _QtyRow extends StatelessWidget {
  const _QtyRow({required this.qty, required this.onMinus, required this.onPlus});

  final int qty;
  final VoidCallback onMinus;
  final VoidCallback onPlus;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.8),
        border: Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.15)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            onPressed: onMinus,
            icon: const Icon(Icons.remove_rounded, size: 20),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text('$qty', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900)),
          ),
          IconButton(
            onPressed: onPlus,
            icon: const Icon(Icons.add_rounded, size: 20),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          ),
        ],
      ),
    );
  }
}

class _CheckoutSummaryCard extends StatelessWidget {
  const _CheckoutSummaryCard({
    required this.subtotal,
    required this.discount,
    required this.discountController,
    required this.onDiscountChanged,
    required this.profit,
    required this.taxRate,
    required this.tax,
    required this.grandTotal,
  });

  final double subtotal;
  final double discount;
  final TextEditingController discountController;
  final VoidCallback onDiscountChanged;
  final double profit;
  final double taxRate;
  final double tax;
  final double grandTotal;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GlassCard(
      borderRadius: 20,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Summary',
            style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 16),
          _sumRow(theme, 'Subtotal', '\$${subtotal.toStringAsFixed(2)}'),
          const SizedBox(height: 12),
          Text(
            'Discount',
            style: theme.textTheme.labelMedium?.copyWith(color: theme.hintColor, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: discountController,
            onChanged: (_) => onDiscountChanged(),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}'))],
            decoration: InputDecoration(
              prefixText: r'$ ',
              hintText: '0.00',
              isDense: true,
              filled: true,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
          if (discount > 0) ...[
            const SizedBox(height: 6),
            Text(
              'Applied −\$${discount.toStringAsFixed(2)}',
              style: theme.textTheme.labelSmall?.copyWith(color: AppColors.tertiary, fontWeight: FontWeight.w600),
            ),
          ],
          const SizedBox(height: 14),
          _sumRow(theme, 'Est. profit', '\$${profit.toStringAsFixed(2)}', highlightProfit: true),
          const SizedBox(height: 10),
          _sumRow(theme, 'Tax (${(taxRate * 100).toStringAsFixed(0)}%)', '\$${tax.toStringAsFixed(2)}'),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Divider(height: 1, color: theme.colorScheme.outline.withValues(alpha: 0.15)),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Text(
                  'Grand total',
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
              Text(
                '\$${grandTotal.toStringAsFixed(2)}',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: AppColors.primary,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _sumRow(ThemeData theme, String label, String value, {bool highlightProfit = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: theme.textTheme.bodyMedium?.copyWith(color: theme.hintColor)),
        Text(
          value,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
            color: highlightProfit ? AppColors.tertiary : null,
          ),
        ),
      ],
    );
  }
}

class _CheckoutCompleteButton extends StatelessWidget {
  const _CheckoutCompleteButton({required this.enabled, required this.onPressed});

  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: Colors.transparent,
      child: SizedBox(
        width: double.infinity,
        height: 56,
        child: FilledButton(
          onPressed: enabled ? onPressed : null,
          style: FilledButton.styleFrom(
            elevation: enabled ? 3 : 0,
            shadowColor: AppColors.primary.withValues(alpha: 0.45),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.receipt_long_rounded, size: 22, color: theme.colorScheme.onPrimary),
              const SizedBox(width: 10),
              Text(
                'Complete sale',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: theme.colorScheme.onPrimary,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
