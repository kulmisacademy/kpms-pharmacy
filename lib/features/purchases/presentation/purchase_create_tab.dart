import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/kpms_payment_methods.dart';
import '../../../core/constants/receipt_branding.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/kpms_payment_method_selector.dart';
import '../../../core/utils/kpms_feedback.dart';
import '../../medicines/data/medicine_catalog_notifier.dart';
import '../../medicines/domain/medicine.dart';
import '../../suppliers/application/suppliers_notifier.dart';
import '../../suppliers/domain/supplier.dart';
import '../application/purchase_ledger_notifier.dart';
import '../domain/purchase_invoice.dart';
import 'purchase_invoice_dialog.dart';
import 'purchase_quick_add_sheet.dart';
import 'purchase_supplier_sheet.dart';

/// How the pharmacy pays the supplier for this purchase.
enum _PurchasePayMode {
  /// Pay supplier in full now (any channel: Cash, EVC Plus, …).
  paidInFull,
  /// Pay part now; remainder is supplier balance.
  partialPayment,
  /// No payment now; full amount owed to supplier.
  supplierCredit,
}

class _DraftLine {
  _DraftLine({
    required this.lineId,
    required this.medicineId,
    required this.quantity,
    required this.buyingPrice,
    required this.sellingPrice,
    this.expiryDate,
  });

  final String lineId;
  final String medicineId;
  int quantity;
  double buyingPrice;

  /// Synced to catalog & POS — never shown on purchase invoice print.
  double sellingPrice;
  DateTime? expiryDate;

  double get lineTotal => quantity * buyingPrice;
}

class PurchaseCreateTab extends ConsumerStatefulWidget {
  const PurchaseCreateTab({super.key, required this.bottomInset});

  final double bottomInset;

  @override
  ConsumerState<PurchaseCreateTab> createState() => _PurchaseCreateTabState();
}

class _PurchaseCreateTabState extends ConsumerState<PurchaseCreateTab> {
  final _discountCtrl = TextEditingController(text: '0');
  final _paidCtrl = TextEditingController(text: '0');
  final _notesCtrl = TextEditingController();
  String? _supplierId;
  _PurchasePayMode _payMode = _PurchasePayMode.paidInFull;
  String _paymentMethod = KpmsPosPaymentMethods.all.first;
  final List<_DraftLine> _lines = [];

  @override
  void dispose() {
    _discountCtrl.dispose();
    _paidCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Medicine? _med(String id) {
    for (final m in ref.read(medicineCatalogProvider)) {
      if (m.id == id) return m;
    }
    return null;
  }

  double get _subtotal => _lines.fold(0.0, (s, l) => s + l.lineTotal);

  double get _discount {
    final v = double.tryParse(_discountCtrl.text.trim()) ?? 0;
    return v.clamp(0.0, _subtotal);
  }

  double get _grand => (_subtotal - _discount).clamp(0.0, double.infinity);

  void _syncPaidField() {
    if (_payMode == _PurchasePayMode.paidInFull) {
      final t = _grand.toStringAsFixed(2);
      if (_paidCtrl.text != t) _paidCtrl.text = t;
    } else if (_payMode == _PurchasePayMode.supplierCredit) {
      if (_paidCtrl.text != '0') _paidCtrl.text = '0';
    }
  }

  double _resolvePaidAmount() {
    if (_payMode == _PurchasePayMode.paidInFull) return _grand;
    if (_payMode == _PurchasePayMode.supplierCredit) return 0;
    final v = double.tryParse(_paidCtrl.text.trim()) ?? 0;
    return v.clamp(0.0, _grand);
  }

  (PurchaseSettlementMode settlement, String method) _resolveSettlementAndMethod(double paid) {
    final remaining = (_grand - paid).clamp(0.0, double.infinity);
    if (_payMode == _PurchasePayMode.paidInFull) {
      return (PurchaseSettlementMode.paidInFull, _paymentMethod);
    }
    if (_payMode == _PurchasePayMode.supplierCredit) {
      return (PurchaseSettlementMode.onAccount, 'Credit');
    }
    // Partial payment path
    if (remaining <= 0.009) {
      return (PurchaseSettlementMode.paidInFull, _paymentMethod);
    }
    if (paid <= 0.009) {
      return (PurchaseSettlementMode.onAccount, 'Credit');
    }
    return (PurchaseSettlementMode.partialPayment, 'Partial · $_paymentMethod');
  }

  void _addFromMedicine(Medicine m) {
    setState(() {
      _lines.add(
        _DraftLine(
          lineId: 'pl_${DateTime.now().microsecondsSinceEpoch}',
          medicineId: m.id,
          quantity: 1,
          buyingPrice: m.buyingPrice,
          sellingPrice: m.sellingPrice,
          expiryDate: m.expiryDate,
        ),
      );
    });
  }

  void _removeLine(String lineId) {
    setState(() => _lines.removeWhere((l) => l.lineId == lineId));
  }

  void _updateLine(
    String lineId, {
    int? quantity,
    double? buyingPrice,
    double? sellingPrice,
    DateTime? expiryDate,
  }) {
    setState(() {
      for (final l in _lines) {
        if (l.lineId == lineId) {
          if (quantity != null) l.quantity = quantity;
          if (buyingPrice != null) l.buyingPrice = buyingPrice;
          if (sellingPrice != null) l.sellingPrice = sellingPrice;
          if (expiryDate != null) l.expiryDate = expiryDate;
        }
      }
    });
  }

  Future<void> _savePurchase() async {
    if (_supplierId == null) {
      kpmsSnack(context, 'Select or add a supplier', isError: true);
      return;
    }
    if (_lines.isEmpty) {
      kpmsSnack(context, 'Add at least one medicine', isError: true);
      return;
    }
    final sup = ref.read(suppliersProvider.notifier).byId(_supplierId!);
    if (sup == null) return;

    final paid = _resolvePaidAmount();
    final (settlement, method) = _resolveSettlementAndMethod(paid);
    final remaining = (_grand - paid).clamp(0.0, double.infinity);

    for (final l in _lines) {
      if (l.sellingPrice + 0.001 < l.buyingPrice) {
        kpmsSnack(context, 'POS sell must be ≥ buy price for every line', isError: true);
        return;
      }
    }

    final now = DateTime.now();
    final invLines = <PurchaseInvoiceLine>[];
    for (final l in _lines) {
      final m = _med(l.medicineId);
      if (m == null) continue;
      invLines.add(
        PurchaseInvoiceLine(
          medicineId: l.medicineId,
          name: m.name,
          formType: m.formType,
          customFormLabel: m.customFormLabel,
          expiryDate: l.expiryDate ?? m.expiryDate,
          quantity: l.quantity,
          buyingPrice: l.buyingPrice,
          sellingPrice: l.sellingPrice,
          lineTotal: l.lineTotal,
        ),
      );
    }
    if (invLines.length != _lines.length) {
      kpmsSnack(context, 'Some lines reference missing medicines', isError: true);
      return;
    }

    final invoice = PurchaseInvoice(
      invoiceNumber: PurchaseInvoice.generateInvoiceNumber(now),
      issuedAt: now,
      supplierId: sup.id,
      supplierName: sup.name,
      supplierPhone: sup.phone,
      supplierAddress: sup.address,
      cashierName: KpmsReceiptBranding.defaultCashier,
      notes: _notesCtrl.text.trim(),
      lines: invLines,
      subtotal: _subtotal,
      discount: _discount,
      taxRate: 0,
      taxAmount: 0,
      grandTotal: _grand,
      paidAmount: paid,
      remainingBalance: remaining,
      settlementMode: settlement,
      paymentMethod: method,
    );

    final err = ref.read(purchaseLedgerProvider.notifier).completePurchase(invoice);
    if (!mounted) return;
    if (err != null) {
      kpmsSnack(context, err, isError: true);
      return;
    }
    setState(() {
      _lines.clear();
      _notesCtrl.clear();
      _discountCtrl.text = '0';
      _paidCtrl.text = '0';
      _supplierId = null;
      _payMode = _PurchasePayMode.paidInFull;
      _paymentMethod = KpmsPosPaymentMethods.all.first;
    });
    await showPurchaseInvoiceDialog(context, invoice);
    if (mounted) kpmsSnack(context, 'Purchase saved · stock updated');
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(medicineCatalogProvider);
    final suppliers = ref.watch(suppliersProvider);
    final theme = Theme.of(context);
    final wide = MediaQuery.sizeOf(context).width >= 1000;
    _syncPaidField();

    final paid = _resolvePaidAmount();
    final remaining = (_grand - paid).clamp(0.0, double.infinity);
    Supplier? supplier;
    if (_supplierId != null) {
      for (final s in suppliers) {
        if (s.id == _supplierId) {
          supplier = s;
          break;
        }
      }
    }

    final supplierBlock = _SupplierStrip(
      suppliers: suppliers,
      selectedId: _supplierId,
      onSelect: (id) => setState(() => _supplierId = id),
      onAdd: () => showPurchaseSupplierSheet(context, ref, onSaved: (id) => setState(() => _supplierId = id)),
      onEdit: supplier == null
          ? null
          : () => showPurchaseSupplierSheet(context, ref, existing: supplier, onSaved: (_) => setState(() {})),
    );

    final searchToolbar = _SearchToolbar(
      onSelected: _addFromMedicine,
      onQuickAdd: () async {
        final m = await showPurchaseQuickAddMedicineSheet(context, ref);
        if (m != null && mounted) _addFromMedicine(m);
      },
    );

    final notesField = TextField(
      controller: _notesCtrl,
      onChanged: (_) => setState(() {}),
      maxLines: 1,
      style: theme.textTheme.bodyMedium,
      decoration: InputDecoration(
        hintText: 'Invoice notes (optional)',
        isDense: true,
        filled: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );

    Widget lineRowBuilder(int i, {required bool isLast}) {
      final line = _lines[i];
      final med = _med(line.medicineId);
      if (med == null) return const SizedBox.shrink();
      return _LineTableRow(
        key: ValueKey(line.lineId),
        index: i,
        showBottomDivider: !isLast,
        medicine: med,
        line: line,
        onRemove: () => _removeLine(line.lineId),
        onChanged: (q, b, s, e) => _updateLine(
          line.lineId,
          quantity: q,
          buyingPrice: b,
          sellingPrice: s,
          expiryDate: e,
        ),
      );
    }

    final sidePanel = _PaymentSummaryPanel(
      payMode: _payMode,
      onPayMode: (m) => setState(() {
        _payMode = m;
        if (m == _PurchasePayMode.paidInFull) {
          _paidCtrl.text = _grand.toStringAsFixed(2);
        } else if (m == _PurchasePayMode.supplierCredit) {
          _paidCtrl.text = '0';
        } else {
          _paidCtrl.clear();
        }
      }),
      paymentMethod: _paymentMethod,
      onPaymentMethodChanged: (s) => setState(() => _paymentMethod = s),
      paidCtrl: _paidCtrl,
      onPaidChanged: () => setState(() {}),
      subtotal: _subtotal,
      discountCtrl: _discountCtrl,
      onDiscountChanged: () => setState(() {}),
      grand: _grand,
      paid: paid,
      remaining: remaining,
      onSave: _savePurchase,
      bottomInset: widget.bottomInset,
    );

    final invoiceBorder = AppColors.outlineMuted.withValues(alpha: 0.75);

    if (wide) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            flex: 62,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                supplierBlock,
                const SizedBox(height: 8),
                notesField,
                const SizedBox(height: 10),
                searchToolbar,
                const SizedBox(height: 10),
                Text(
                  'LINE ITEMS',
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: theme.hintColor,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 6),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      if (_lines.isEmpty) {
                        return Align(
                          alignment: Alignment.topCenter,
                          child: ConstrainedBox(
                            constraints: BoxConstraints(maxWidth: constraints.maxWidth),
                            child: Container(
                              decoration: BoxDecoration(
                                color: theme.colorScheme.surface,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: invoiceBorder),
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: const _EmptyLinesState(compact: true),
                            ),
                          ),
                        );
                      }
                      final sep = theme.colorScheme.outline.withValues(alpha: 0.12);
                      return ScrollConfiguration(
                        behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
                        child: SingleChildScrollView(
                          child: ConstrainedBox(
                            constraints: BoxConstraints(minWidth: constraints.maxWidth),
                            child: Container(
                              decoration: BoxDecoration(
                                color: theme.colorScheme.surface,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: invoiceBorder),
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  _TableHeaderRow(theme: theme),
                                  Divider(height: 1, color: sep),
                                  ...List.generate(
                                    _lines.length,
                                    (i) => lineRowBuilder(i, isLast: i == _lines.length - 1),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            flex: 36,
            child: ScrollConfiguration(
              behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
              child: SingleChildScrollView(child: sidePanel),
            ),
          ),
        ],
      );
    }

    return ScrollConfiguration(
      behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                supplierBlock,
                const SizedBox(height: 8),
                notesField,
                const SizedBox(height: 10),
                searchToolbar,
                const SizedBox(height: 10),
                Text(
                  'LINE ITEMS',
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: theme.hintColor,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 6),
              ],
            ),
          ),
          if (_lines.isEmpty)
            SliverToBoxAdapter(
              child: Container(
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: invoiceBorder),
                ),
                child: const _EmptyLinesState(compact: true),
              ),
            )
          else
            SliverToBoxAdapter(
              child: Container(
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: invoiceBorder),
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var i = 0; i < _lines.length; i++) ...[
                      if (i > 0)
                        Divider(
                          height: 1,
                          thickness: 1,
                          color: theme.colorScheme.outline.withValues(alpha: 0.1),
                        ),
                      Builder(
                        builder: (context) {
                          final line = _lines[i];
                          final med = _med(line.medicineId);
                          if (med == null) return const SizedBox.shrink();
                          return _LineCard(
                            key: ValueKey(line.lineId),
                            index: i,
                            showBottomDivider: false,
                            medicine: med,
                            line: line,
                            onRemove: () => _removeLine(line.lineId),
                            onChanged: (q, b, s, e) => _updateLine(
                              line.lineId,
                              quantity: q,
                              buyingPrice: b,
                              sellingPrice: s,
                              expiryDate: e,
                            ),
                          );
                        },
                      ),
                    ],
                  ],
                ),
              ),
            ),
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.only(top: 12, bottom: 8 + widget.bottomInset),
              child: sidePanel,
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchToolbar extends StatelessWidget {
  const _SearchToolbar({
    required this.onSelected,
    required this.onQuickAdd,
  });

  final void Function(Medicine m) onSelected;
  final VoidCallback onQuickAdd;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final border = AppColors.outlineMuted.withValues(alpha: 0.55);
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      child: LayoutBuilder(
        builder: (context, c) {
          final narrow = c.maxWidth < 520;
          final search = _MedicineSearchBox(onSelected: onSelected);
          final addBtn = OutlinedButton.icon(
            onPressed: onQuickAdd,
            icon: const Icon(Icons.add_rounded, size: 20),
            label: const Text('New item'),
            style: OutlinedButton.styleFrom(
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          );
          if (narrow) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                search,
                const SizedBox(height: 8),
                addBtn,
              ],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: search),
              const SizedBox(width: 8),
              addBtn,
            ],
          );
        },
      ),
    );
  }
}

class _SupplierStrip extends StatelessWidget {
  const _SupplierStrip({
    required this.suppliers,
    required this.selectedId,
    required this.onSelect,
    required this.onAdd,
    this.onEdit,
  });

  final List<Supplier> suppliers;
  final String? selectedId;
  final ValueChanged<String?> onSelect;
  final VoidCallback onAdd;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.outlineMuted.withValues(alpha: 0.55)),
      ),
      child: Row(
        children: [
          Expanded(
            child: DropdownButtonFormField<String?>(
              key: ValueKey(selectedId ?? 'none'),
              initialValue: selectedId,
              isDense: true,
              decoration: InputDecoration(
                labelText: 'Supplier',
                isDense: true,
                filled: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
              items: [
                for (final s in suppliers)
                  DropdownMenuItem(value: s.id, child: Text(s.name)),
              ],
              onChanged: onSelect,
            ),
          ),
          const SizedBox(width: 6),
          IconButton(
            tooltip: 'Add supplier',
            onPressed: onAdd,
            icon: Icon(Icons.person_add_alt_1_rounded, color: theme.colorScheme.onSurfaceVariant),
          ),
          if (onEdit != null)
            IconButton(
              tooltip: 'Edit supplier',
              onPressed: onEdit,
              icon: Icon(Icons.edit_outlined, color: theme.colorScheme.onSurfaceVariant),
            ),
        ],
      ),
    );
  }
}

class _EmptyLinesState extends StatelessWidget {
  const _EmptyLinesState({this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.symmetric(vertical: compact ? 28 : 36, horizontal: compact ? 16 : 20),
      child: Column(
        children: [
          Icon(Icons.receipt_long_outlined, size: compact ? 32 : 40, color: theme.hintColor.withValues(alpha: 0.65)),
          const SizedBox(height: 10),
          Text(
            'No line items',
            style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            'Search or add a medicine to start this purchase.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
          ),
        ],
      ),
    );
  }
}

class _TableHeaderRow extends StatelessWidget {
  const _TableHeaderRow({required this.theme});

  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    TextStyle s() => theme.textTheme.labelSmall!.copyWith(
          fontWeight: FontWeight.w800,
          color: theme.hintColor,
          letterSpacing: 0.3,
        );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          const SizedBox(width: 40),
          Expanded(flex: 4, child: Text('ITEM', style: s())),
          SizedBox(width: 84, child: Text('EXP', style: s())),
          SizedBox(width: 56, child: Text('QTY', style: s())),
          SizedBox(width: 84, child: Text('BUY', style: s())),
          SizedBox(width: 84, child: Text('POS', style: s())),
          SizedBox(width: 92, child: Text('AMOUNT', textAlign: TextAlign.right, style: s())),
          const SizedBox(width: 40),
        ],
      ),
    );
  }
}

class _LineTableRow extends StatefulWidget {
  const _LineTableRow({
    super.key,
    required this.index,
    required this.showBottomDivider,
    required this.medicine,
    required this.line,
    required this.onRemove,
    required this.onChanged,
  });

  final int index;
  final bool showBottomDivider;
  final Medicine medicine;
  final _DraftLine line;
  final VoidCallback onRemove;
  final void Function(int q, double b, double s, DateTime? e) onChanged;

  @override
  State<_LineTableRow> createState() => _LineTableRowState();
}

class _LineTableRowState extends State<_LineTableRow> {
  late final TextEditingController _qty;
  late final TextEditingController _buy;
  late final TextEditingController _sell;

  @override
  void initState() {
    super.initState();
    _qty = TextEditingController(text: '${widget.line.quantity}');
    _buy = TextEditingController(text: widget.line.buyingPrice.toStringAsFixed(2));
    _sell = TextEditingController(text: widget.line.sellingPrice.toStringAsFixed(2));
  }

  @override
  void dispose() {
    _qty.dispose();
    _buy.dispose();
    _sell.dispose();
    super.dispose();
  }

  void _notify() {
    final q = int.tryParse(_qty.text) ?? widget.line.quantity;
    final b = double.tryParse(_buy.text) ?? widget.line.buyingPrice;
    final s = double.tryParse(_sell.text) ?? widget.line.sellingPrice;
    widget.onChanged(q.clamp(1, 999999), b, s, widget.line.expiryDate);
  }

  InputDecoration _cellDec(ThemeData theme) => InputDecoration(
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        filled: true,
        fillColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: theme.colorScheme.outline.withValues(alpha: 0.18)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: theme.colorScheme.outline.withValues(alpha: 0.18)),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final exp = widget.line.expiryDate ?? widget.medicine.expiryDate;
    final expStr = exp == null
        ? '—'
        : '${exp.year}-${exp.month.toString().padLeft(2, '0')}-${exp.day.toString().padLeft(2, '0')}';
    final thumbBg = theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.55);
    final sep = theme.colorScheme.outline.withValues(alpha: 0.12);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: 40,
                  height: 40,
                  child: widget.medicine.imageBytes != null
                      ? Image.memory(widget.medicine.imageBytes!, fit: BoxFit.cover)
                      : ColoredBox(
                          color: thumbBg,
                          child: Icon(Icons.medication_liquid_rounded, color: theme.hintColor, size: 22),
                        ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 4,
                child: Text(
                  widget.medicine.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              SizedBox(
                width: 84,
                child: TextButton(
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  onPressed: () async {
                    final now = DateTime.now();
                    final d = await showDatePicker(
                      context: context,
                      initialDate: widget.line.expiryDate ?? now.add(const Duration(days: 365)),
                      firstDate: now,
                      lastDate: DateTime(now.year + 8),
                    );
                    if (d != null) {
                      final q = int.tryParse(_qty.text) ?? widget.line.quantity;
                      final b = double.tryParse(_buy.text) ?? widget.line.buyingPrice;
                      final s = double.tryParse(_sell.text) ?? widget.line.sellingPrice;
                      widget.onChanged(q.clamp(1, 999999), b, s, d);
                      setState(() {});
                    }
                  },
                  child: Text(
                    expStr,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              SizedBox(
                width: 56,
                child: TextField(
                  controller: _qty,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  style: theme.textTheme.bodyMedium,
                  decoration: _cellDec(theme),
                  onChanged: (_) => _notify(),
                ),
              ),
              const SizedBox(width: 6),
              SizedBox(
                width: 84,
                child: TextField(
                  controller: _buy,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: theme.textTheme.bodyMedium,
                  decoration: _cellDec(theme).copyWith(prefixText: r'$ '),
                  onChanged: (_) => _notify(),
                ),
              ),
              const SizedBox(width: 6),
              SizedBox(
                width: 84,
                child: TextField(
                  controller: _sell,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: theme.textTheme.bodyMedium,
                  decoration: _cellDec(theme).copyWith(
                    prefixText: r'$ ',
                    hintText: 'POS',
                    hintStyle: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
                  ),
                  onChanged: (_) => _notify(),
                ),
              ),
              const SizedBox(width: 6),
              SizedBox(
                width: 92,
                child: Text(
                  '\$${widget.line.lineTotal.toStringAsFixed(2)}',
                  textAlign: TextAlign.right,
                  style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
              SizedBox(
                width: 40,
                child: IconButton(
                  tooltip: 'Remove line',
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                  onPressed: widget.onRemove,
                  icon: Icon(Icons.close_rounded, size: 20, color: theme.hintColor),
                ),
              ),
            ],
          ),
        ),
        if (widget.showBottomDivider) Divider(height: 1, thickness: 1, color: sep),
      ],
    );
  }
}

class _LineCard extends StatefulWidget {
  const _LineCard({
    super.key,
    required this.index,
    required this.showBottomDivider,
    required this.medicine,
    required this.line,
    required this.onRemove,
    required this.onChanged,
  });

  final int index;
  final bool showBottomDivider;
  final Medicine medicine;
  final _DraftLine line;
  final VoidCallback onRemove;
  final void Function(int q, double b, double s, DateTime? e) onChanged;

  @override
  State<_LineCard> createState() => _LineCardState();
}

class _LineCardState extends State<_LineCard> {
  late final TextEditingController _qty;
  late final TextEditingController _buy;
  late final TextEditingController _sell;

  @override
  void initState() {
    super.initState();
    _qty = TextEditingController(text: '${widget.line.quantity}');
    _buy = TextEditingController(text: widget.line.buyingPrice.toStringAsFixed(2));
    _sell = TextEditingController(text: widget.line.sellingPrice.toStringAsFixed(2));
  }

  @override
  void dispose() {
    _qty.dispose();
    _buy.dispose();
    _sell.dispose();
    super.dispose();
  }

  void _notify() {
    final q = int.tryParse(_qty.text) ?? widget.line.quantity;
    final b = double.tryParse(_buy.text) ?? widget.line.buyingPrice;
    final s = double.tryParse(_sell.text) ?? widget.line.sellingPrice;
    widget.onChanged(q.clamp(1, 999999), b, s, widget.line.expiryDate);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final exp = widget.line.expiryDate ?? widget.medicine.expiryDate;
    final expStr = exp == null
        ? '—'
        : '${exp.year}-${exp.month.toString().padLeft(2, '0')}-${exp.day.toString().padLeft(2, '0')}';
    final thumbBg = theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.55);
    final sep = theme.colorScheme.outline.withValues(alpha: 0.12);
    final fieldDec = InputDecoration(
      isDense: true,
      filled: true,
      fillColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.25),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: theme.colorScheme.outline.withValues(alpha: 0.2)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: theme.colorScheme.outline.withValues(alpha: 0.2)),
      ),
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: SizedBox(
                      width: 44,
                      height: 44,
                      child: widget.medicine.imageBytes != null
                          ? Image.memory(widget.medicine.imageBytes!, fit: BoxFit.cover)
                          : ColoredBox(
                              color: thumbBg,
                              child: Icon(Icons.medication_liquid_rounded, color: theme.hintColor, size: 24),
                            ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.medicine.name,
                          style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Exp $expStr · ${widget.medicine.typeDisplayName}',
                          style: theme.textTheme.labelSmall?.copyWith(color: theme.hintColor),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Remove',
                    visualDensity: VisualDensity.compact,
                    onPressed: widget.onRemove,
                    icon: Icon(Icons.close_rounded, color: theme.hintColor),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _qty,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: fieldDec.copyWith(labelText: 'Qty'),
                      onChanged: (_) => _notify(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: TextField(
                      controller: _buy,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: fieldDec.copyWith(labelText: 'Buy', prefixText: r'$ '),
                      onChanged: (_) => _notify(),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _sell,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: fieldDec.copyWith(
                  labelText: 'POS sell (not on supplier invoice)',
                  prefixText: r'$ ',
                ),
                onChanged: (_) => _notify(),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  TextButton.icon(
                    onPressed: () async {
                      final now = DateTime.now();
                      final d = await showDatePicker(
                        context: context,
                        initialDate: widget.line.expiryDate ?? now.add(const Duration(days: 365)),
                        firstDate: now,
                        lastDate: DateTime(now.year + 8),
                      );
                      if (d != null) {
                        final q = int.tryParse(_qty.text) ?? widget.line.quantity;
                        final b = double.tryParse(_buy.text) ?? widget.line.buyingPrice;
                        final s = double.tryParse(_sell.text) ?? widget.line.sellingPrice;
                        widget.onChanged(q.clamp(1, 999999), b, s, d);
                        setState(() {});
                      }
                    },
                    icon: const Icon(Icons.event_rounded, size: 18),
                    label: const Text('Change expiry'),
                  ),
                  const Spacer(),
                  Text(
                    'Line \$${widget.line.lineTotal.toStringAsFixed(2)}',
                    style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (widget.showBottomDivider) Divider(height: 1, thickness: 1, color: sep),
      ],
    );
  }
}

class _PaymentSummaryPanel extends StatelessWidget {
  const _PaymentSummaryPanel({
    required this.payMode,
    required this.onPayMode,
    required this.paymentMethod,
    required this.onPaymentMethodChanged,
    required this.paidCtrl,
    required this.onPaidChanged,
    required this.subtotal,
    required this.discountCtrl,
    required this.onDiscountChanged,
    required this.grand,
    required this.paid,
    required this.remaining,
    required this.onSave,
    required this.bottomInset,
  });

  final _PurchasePayMode payMode;
  final ValueChanged<_PurchasePayMode> onPayMode;
  final String paymentMethod;
  final ValueChanged<String> onPaymentMethodChanged;
  final TextEditingController paidCtrl;
  final VoidCallback onPaidChanged;
  final double subtotal;
  final TextEditingController discountCtrl;
  final VoidCallback onDiscountChanged;
  final double grand;
  final double paid;
  final double remaining;
  final Future<void> Function() onSave;
  final double bottomInset;

  String _statusLabel() {
    return switch (payMode) {
      _PurchasePayMode.paidInFull => 'Paid in full',
      _PurchasePayMode.partialPayment => 'Partial payment',
      _PurchasePayMode.supplierCredit => 'Supplier credit',
    };
  }

  String _methodSummary() {
    if (payMode == _PurchasePayMode.supplierCredit) return '—';
    return paymentMethod;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final outline = theme.colorScheme.outline.withValues(alpha: 0.2);
    final showChannel = payMode == _PurchasePayMode.paidInFull || payMode == _PurchasePayMode.partialPayment;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.outlineMuted.withValues(alpha: 0.65)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.payments_rounded, color: AppColors.primary, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Supplier payment',
                  style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'How you settle this purchase with the supplier.',
            style: theme.textTheme.labelSmall?.copyWith(color: theme.hintColor, height: 1.35),
          ),
          const SizedBox(height: 14),
          Text(
            'PAYMENT STATUS',
            style: theme.textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: 0.85,
              color: theme.hintColor,
            ),
          ),
          const SizedBox(height: 8),
          LayoutBuilder(
            builder: (context, c) {
              if (c.maxWidth < 300) {
                return Column(
                  children: [
                    _PurchasePayModeCard(
                      selected: payMode == _PurchasePayMode.paidInFull,
                      icon: Icons.check_circle_outline_rounded,
                      title: 'Paid',
                      subtitle: 'Full amount now',
                      onTap: () => onPayMode(_PurchasePayMode.paidInFull),
                    ),
                    const SizedBox(height: 8),
                    _PurchasePayModeCard(
                      selected: payMode == _PurchasePayMode.partialPayment,
                      icon: Icons.call_split_rounded,
                      title: 'Partial',
                      subtitle: 'Pay part · owe rest',
                      onTap: () => onPayMode(_PurchasePayMode.partialPayment),
                    ),
                    const SizedBox(height: 8),
                    _PurchasePayModeCard(
                      selected: payMode == _PurchasePayMode.supplierCredit,
                      icon: Icons.receipt_long_outlined,
                      title: 'Credit',
                      subtitle: 'All on account',
                      onTap: () => onPayMode(_PurchasePayMode.supplierCredit),
                    ),
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _PurchasePayModeCard(
                      selected: payMode == _PurchasePayMode.paidInFull,
                      icon: Icons.check_circle_outline_rounded,
                      title: 'Paid',
                      subtitle: 'Full',
                      compact: true,
                      onTap: () => onPayMode(_PurchasePayMode.paidInFull),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _PurchasePayModeCard(
                      selected: payMode == _PurchasePayMode.partialPayment,
                      icon: Icons.call_split_rounded,
                      title: 'Partial',
                      subtitle: 'Split',
                      compact: true,
                      onTap: () => onPayMode(_PurchasePayMode.partialPayment),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _PurchasePayModeCard(
                      selected: payMode == _PurchasePayMode.supplierCredit,
                      icon: Icons.receipt_long_outlined,
                      title: 'Credit',
                      subtitle: 'Full AP',
                      compact: true,
                      onTap: () => onPayMode(_PurchasePayMode.supplierCredit),
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: outline),
            ),
            child: Column(
              children: [
                _paySummaryRow(theme, 'Invoice total', '\$${grand.toStringAsFixed(2)}', strong: true),
                const SizedBox(height: 8),
                _paySummaryRow(theme, 'Paid amount', '\$${paid.toStringAsFixed(2)}'),
                const SizedBox(height: 8),
                _paySummaryRow(
                  theme,
                  'Remaining to supplier',
                  '\$${remaining.toStringAsFixed(2)}',
                  warn: remaining > 0.009,
                ),
                const SizedBox(height: 8),
                _paySummaryRow(theme, 'Payment status', _statusLabel()),
                const SizedBox(height: 8),
                _paySummaryRow(theme, 'Payment method', _methodSummary()),
              ],
            ),
          ),
          const SizedBox(height: 14),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            child: payMode == _PurchasePayMode.supplierCredit
                ? Padding(
                    key: const ValueKey('cred'),
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      'No payment today — full balance owed to supplier.',
                      style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor, height: 1.4),
                    ),
                  )
                : const SizedBox(key: ValueKey('empty'), height: 0),
          ),
          if (payMode == _PurchasePayMode.partialPayment) ...[
            Text(
              'AMOUNT PAID NOW',
              style: theme.textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: 0.85,
                color: theme.hintColor,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: paidCtrl,
              onChanged: (_) => onPaidChanged(),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}'))],
              decoration: InputDecoration(
                labelText: 'Paid to supplier',
                prefixText: r'$ ',
                filled: true,
                isDense: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 14),
          ],
          if (showChannel) ...[
            Text(
              'PAYMENT CHANNEL',
              style: theme.textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: 0.85,
                color: theme.hintColor,
              ),
            ),
            const SizedBox(height: 8),
            KpmsPaymentMethodSelector(
              selected: paymentMethod,
              onSelected: onPaymentMethodChanged,
            ),
            if (payMode == _PurchasePayMode.paidInFull) ...[
              const SizedBox(height: 8),
              Text(
                'Amount paid equals invoice total.',
                style: theme.textTheme.labelSmall?.copyWith(color: theme.hintColor),
              ),
            ],
            const SizedBox(height: 8),
          ],
          const SizedBox(height: 12),
          Divider(color: theme.colorScheme.outline.withValues(alpha: 0.12)),
          const SizedBox(height: 12),
          Text('Totals', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900)),
          const SizedBox(height: 12),
          _sumRow(theme, 'Subtotal', subtotal),
          const SizedBox(height: 10),
          TextField(
            controller: discountCtrl,
            onChanged: (_) => onDiscountChanged(),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'Discount',
              prefixText: r'$ ',
              isDense: true,
              filled: true,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Divider(height: 1),
          ),
          _sumRow(theme, 'Grand total', grand, highlight: true),
          const SizedBox(height: 8),
          _sumRow(theme, 'Paid amount', paid),
          _sumRow(theme, 'Remaining balance', remaining, warn: remaining > 0.009),
          SizedBox(height: 18 + bottomInset),
          FilledButton.icon(
            onPressed: onSave,
            icon: const Icon(Icons.check_rounded),
            label: const Text('Save purchase invoice'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _paySummaryRow(ThemeData theme, String label, String value, {bool strong = false, bool warn = false}) {
    final c = warn ? Colors.orange.shade900 : null;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor, fontWeight: FontWeight.w600),
          ),
        ),
        Text(
          value,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: strong ? FontWeight.w900 : FontWeight.w700,
            color: c,
          ),
          textAlign: TextAlign.right,
        ),
      ],
    );
  }

  Widget _sumRow(ThemeData theme, String label, double value, {bool highlight = false, bool warn = false}) {
    final c = warn ? Colors.orange.shade800 : (highlight ? AppColors.primary : null);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: warn ? c : theme.hintColor,
              fontWeight: highlight ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
          Text(
            '\$${value.toStringAsFixed(2)}',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w900,
              color: c,
              fontSize: highlight ? 18 : null,
            ),
          ),
        ],
      ),
    );
  }
}

class _PurchasePayModeCard extends StatelessWidget {
  const _PurchasePayModeCard({
    required this.selected,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.compact = false,
  });

  final bool selected;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = AppColors.primary;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          padding: EdgeInsets.symmetric(horizontal: compact ? 8 : 12, vertical: compact ? 10 : 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              width: selected ? 2 : 1,
              color: selected ? primary : theme.colorScheme.outline.withValues(alpha: 0.25),
            ),
            color: selected ? primary.withValues(alpha: 0.08) : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.25),
          ),
          child: compact
              ? Column(
                  children: [
                    Icon(icon, color: selected ? primary : theme.hintColor, size: 22),
                    const SizedBox(height: 6),
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                        color: selected ? primary : theme.colorScheme.onSurface,
                      ),
                    ),
                    Text(
                      subtitle,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      style: theme.textTheme.labelSmall?.copyWith(color: theme.hintColor, height: 1.15),
                    ),
                  ],
                )
              : Row(
                  children: [
                    Icon(icon, color: selected ? primary : theme.hintColor, size: 26),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w900,
                              color: selected ? primary : null,
                            ),
                          ),
                          Text(subtitle, style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor)),
                        ],
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _MedicineSearchBox extends ConsumerStatefulWidget {
  const _MedicineSearchBox({required this.onSelected});

  final void Function(Medicine m) onSelected;

  @override
  ConsumerState<_MedicineSearchBox> createState() => _MedicineSearchBoxState();
}

class _MedicineSearchBoxState extends ConsumerState<_MedicineSearchBox> {
  final _focus = FocusNode();
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _focus.dispose();
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final catalog = ref.watch(medicineCatalogProvider);

    return RawAutocomplete<Medicine>(
      focusNode: _focus,
      textEditingController: _ctrl,
      displayStringForOption: (m) => m.name,
      optionsBuilder: (text) {
        final q = text.text.trim().toLowerCase();
        if (q.isEmpty) return catalog.take(12);
        return catalog.where((m) {
          if (m.name.toLowerCase().contains(q)) return true;
          final bc = m.barcode;
          return bc != null && bc.contains(q);
        }).take(24);
      },
      onSelected: (m) {
        widget.onSelected(m);
        _ctrl.clear();
        _focus.unfocus();
      },
      fieldViewBuilder: (context, c, focusNode, onFieldSubmitted) {
        final theme = Theme.of(context);
        return TextField(
          controller: c,
          focusNode: focusNode,
          style: theme.textTheme.bodyMedium,
          decoration: InputDecoration(
            hintText: 'Search medicine or scan barcode…',
            isDense: true,
            prefixIcon: Icon(Icons.search_rounded, color: theme.hintColor, size: 22),
            filled: true,
            fillColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: theme.colorScheme.outline.withValues(alpha: 0.15)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: theme.colorScheme.outline.withValues(alpha: 0.15)),
            ),
          ),
          onSubmitted: (_) => onFieldSubmitted(),
        );
      },
      optionsViewBuilder: (context, onSelected, options) {
        final opts = options.toList();
        final theme = Theme.of(context);
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 6,
            shadowColor: Colors.black26,
            color: theme.colorScheme.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: theme.colorScheme.outline.withValues(alpha: 0.12)),
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 280, maxWidth: 480),
              child: ListView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: opts.length,
                itemBuilder: (context, i) {
                  final m = opts[i];
                  return InkWell(
                    onTap: () => onSelected(m),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  m.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${m.typeDisplayName} · Stock ${m.quantity}',
                                  style: theme.textTheme.labelSmall?.copyWith(color: theme.hintColor),
                                ),
                              ],
                            ),
                          ),
                          Icon(Icons.add_circle_outline_rounded, size: 20, color: theme.hintColor),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}
