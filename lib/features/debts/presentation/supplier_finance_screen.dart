import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/navigation/kpms_breakpoints.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/kpms_feedback.dart';
import '../../../core/widgets/kpms_mobile_bottom_nav.dart';
import '../../../core/widgets/kpms_page_shell.dart';
import '../../purchases/application/purchase_ledger_notifier.dart';
import '../../suppliers/application/suppliers_notifier.dart';
import '../application/supplier_payments_notifier.dart';

class SupplierFinanceScreen extends ConsumerStatefulWidget {
  const SupplierFinanceScreen({super.key, required this.supplierId});

  final String supplierId;

  @override
  ConsumerState<SupplierFinanceScreen> createState() => _SupplierFinanceScreenState();
}

class _SupplierFinanceScreenState extends ConsumerState<SupplierFinanceScreen> {
  final _payAmount = TextEditingController();
  final _payNote = TextEditingController();

  @override
  void dispose() {
    _payAmount.dispose();
    _payNote.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    ref.watch(suppliersProvider);
    ref.watch(purchaseLedgerProvider);
    ref.watch(supplierPaymentsProvider);
    final clearance = KpmsMobileBottomNav.scrollClearanceBottom(context);
    final sup = ref.read(suppliersProvider.notifier).byId(widget.supplierId);
    final purchases =
        ref.read(purchaseLedgerProvider).invoices.where((p) => p.supplierId == widget.supplierId).toList()
          ..sort((a, b) => b.issuedAt.compareTo(a.issuedAt));
    final payments = ref.read(supplierPaymentsProvider.notifier).forSupplier(widget.supplierId);

    if (sup == null) {
      return KpmsPageShell(
        title: 'Supplier',
        subtitle: 'Finance',
        body: const Center(child: Text('Supplier not found.')),
      );
    }

    var paidOnPurchases = 0.0;
    for (final p in purchases) {
      paidOnPurchases += p.paidAmount;
    }

    return KpmsPageShell(
      title: sup.name,
      subtitle: 'Invoices · payments · balance',
      body: ListView(
        padding: KpmsBreakpoints.pageScrollPadding(context, bottomExtra: clearance + 24),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.outlineMuted.withValues(alpha: 0.75)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _kv(theme, 'Phone', sup.phone),
                _kv(theme, 'Address', sup.address),
                const Divider(height: 20),
                _kv(theme, 'Outstanding', '\$${sup.balanceOwed.toStringAsFixed(2)}', strong: true),
                _kv(theme, 'Purchase invoices', '${purchases.length}'),
                _kv(theme, 'Recorded payments', '\$${paidOnPurchases.toStringAsFixed(2)} (on POs)'),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'RECORD PAYMENT',
            style: theme.textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: 0.7,
              color: theme.hintColor,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextField(
                  controller: _payAmount,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}'))],
                  decoration: InputDecoration(
                    labelText: 'Amount',
                    prefixText: r'$ ',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _payNote,
                  decoration: InputDecoration(
                    labelText: 'Note',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              onPressed: () {
                final amt = double.tryParse(_payAmount.text.trim()) ?? 0;
                final err = ref.read(supplierPaymentsProvider.notifier).recordPayment(
                      supplierId: widget.supplierId,
                      amount: amt,
                      note: _payNote.text.trim(),
                    );
                if (!context.mounted) return;
                if (err != null) {
                  kpmsSnack(context, err, isError: true);
                  return;
                }
                _payAmount.clear();
                _payNote.clear();
                kpmsSnack(context, 'Payment saved');
                setState(() {});
              },
              icon: const Icon(Icons.check_rounded),
              label: const Text('Save payment'),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'PAYMENT HISTORY',
            style: theme.textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: 0.7,
              color: theme.hintColor,
            ),
          ),
          const SizedBox(height: 8),
          if (payments.isEmpty)
            Text('No payments yet.', style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor))
          else
            ...payments.map((p) {
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.outlineMuted.withValues(alpha: 0.65)),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '\$${p.amount.toStringAsFixed(2)}',
                            style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900),
                          ),
                          if (p.note.isNotEmpty)
                            Text(p.note, style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor)),
                        ],
                      ),
                    ),
                    Text(
                      '${p.paidAt.year}-${p.paidAt.month.toString().padLeft(2, '0')}-${p.paidAt.day.toString().padLeft(2, '0')}',
                      style: theme.textTheme.labelSmall?.copyWith(color: theme.hintColor),
                    ),
                  ],
                ),
              );
            }),
          const SizedBox(height: 20),
          Text(
            'PURCHASE INVOICES',
            style: theme.textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: 0.7,
              color: theme.hintColor,
            ),
          ),
          const SizedBox(height: 8),
          ...purchases.map((p) {
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.outlineMuted.withValues(alpha: 0.65)),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(p.invoiceNumber, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
                      Text(
                        p.paymentStatusLabel,
                        style: theme.textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: p.remainingBalance > 0.009 ? Colors.orange.shade800 : theme.hintColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Grand \$${p.grandTotal.toStringAsFixed(2)} · Paid \$${p.paidAmount.toStringAsFixed(2)} · Due \$${p.remainingBalance.toStringAsFixed(2)}',
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _kv(ThemeData theme, String k, String v, {bool strong = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(k, style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor)),
          ),
          Expanded(
            child: Text(
              v,
              style: theme.textTheme.bodyMedium?.copyWith(fontWeight: strong ? FontWeight.w900 : FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
