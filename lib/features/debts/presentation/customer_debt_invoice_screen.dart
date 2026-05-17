import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/navigation/kpms_breakpoints.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/kpms_page_shell.dart';
import '../../sales/application/sales_ledger_notifier.dart';

/// Single sale invoice view focused on debt / payment history (staff or customer link).
class CustomerDebtInvoiceScreen extends ConsumerWidget {
  const CustomerDebtInvoiceScreen({super.key, required this.invoiceNumber});

  final String invoiceNumber;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    ref.watch(salesLedgerProvider);
    final inv = ref.read(salesLedgerProvider.notifier).invoiceByNumber(invoiceNumber);

    if (inv == null) {
      return KpmsPageShell(
        title: 'Invoice',
        subtitle: invoiceNumber,
        body: Center(child: Text('Invoice not found.', style: theme.textTheme.bodyLarge)),
      );
    }

    return KpmsPageShell(
      title: inv.invoiceNumber,
      subtitle: 'Balance & payments',
      body: ListView(
        padding: KpmsBreakpoints.pageScrollPadding(context, bottomExtra: 24),
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
                _kv(theme, 'Date',
                    '${inv.issuedAt.year}-${inv.issuedAt.month.toString().padLeft(2, '0')}-${inv.issuedAt.day.toString().padLeft(2, '0')}'),
                _kv(theme, 'Customer', inv.customerName),
                _kv(theme, 'Phone', inv.customerPhone.isEmpty ? '—' : inv.customerPhone),
                _kv(theme, 'Payment type', inv.paymentMethod),
                if (inv.debtCustomerNotes.isNotEmpty) _kv(theme, 'Notes', inv.debtCustomerNotes),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'ITEMS',
            style: theme.textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
              color: theme.hintColor,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.outlineMuted.withValues(alpha: 0.75)),
            ),
            child: Column(
              children: [
                for (var i = 0; i < inv.lines.length; i++) ...[
                  if (i > 0) Divider(height: 1, color: theme.colorScheme.outline.withValues(alpha: 0.1)),
                  ListTile(
                    title: Text(inv.lines[i].name, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700)),
                    subtitle: Text('Qty ${inv.lines[i].quantitySold} × \$${inv.lines[i].unitSell.toStringAsFixed(2)}'),
                    trailing: Text(
                      '\$${inv.lines[i].lineSaleTotal.toStringAsFixed(2)}',
                      style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'TOTALS',
            style: theme.textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
              color: theme.hintColor,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.outlineMuted.withValues(alpha: 0.75)),
            ),
            child: Column(
              children: [
                _sumRow(theme, 'Invoice total', inv.total),
                _sumRow(theme, 'Paid to date', inv.paidTowardInvoice),
                _sumRow(theme, 'Remaining', inv.remainingBalance, warn: inv.remainingBalance > 0.009),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'PAYMENT HISTORY',
            style: theme.textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
              color: theme.hintColor,
            ),
          ),
          const SizedBox(height: 8),
          if (inv.debtLedger.isEmpty)
            Text('No ledger entries yet.', style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor))
          else
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.outlineMuted.withValues(alpha: 0.75)),
              ),
              child: Column(
                children: [
                  for (var i = 0; i < inv.debtLedger.length; i++) ...[
                    if (i > 0) Divider(height: 1, color: theme.colorScheme.outline.withValues(alpha: 0.1)),
                    ListTile(
                      title: Text(inv.debtLedger[i].label),
                      subtitle: Text(
                        '${inv.debtLedger[i].recordedAt.year}-${inv.debtLedger[i].recordedAt.month.toString().padLeft(2, '0')}-${inv.debtLedger[i].recordedAt.day.toString().padLeft(2, '0')}',
                      ),
                      trailing: Text(
                        '\$${inv.debtLedger[i].amount.toStringAsFixed(2)}',
                        style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _kv(ThemeData theme, String k, String v) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(k, style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor)),
          ),
          Expanded(child: Text(v, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }

  Widget _sumRow(ThemeData theme, String label, double value, {bool warn = false}) {
    final c = warn ? theme.colorScheme.error : null;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: theme.textTheme.bodyMedium?.copyWith(color: theme.hintColor)),
          Text(
            '\$${value.toStringAsFixed(2)}',
            style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900, color: c),
          ),
        ],
      ),
    );
  }
}
