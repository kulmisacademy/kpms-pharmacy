import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_routes.dart';
import '../../../core/navigation/kpms_breakpoints.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/kpms_mobile_bottom_nav.dart';
import '../../../core/widgets/kpms_page_shell.dart';
import '../../sales/application/sales_ledger_notifier.dart';
import '../application/debt_customers_notifier.dart';
import 'pay_customer_debt_sheet.dart';

class CustomerDebtProfileScreen extends ConsumerWidget {
  const CustomerDebtProfileScreen({super.key, required this.customerId});

  final String customerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    ref.watch(salesLedgerProvider);
    ref.watch(debtCustomersProvider);
    final customer = ref.read(debtCustomersProvider.notifier).byId(customerId);
    final ledger = ref.read(salesLedgerProvider.notifier);
    final invoices = ledger.invoicesForDebtCustomer(customerId);
    final open = ledger.openDebtTotalForCustomer(customerId);
    final paidLife = ledger.lifetimePaidForCustomer(customerId);
    final clearance = KpmsMobileBottomNav.scrollClearanceBottom(context);

    DateTime? lastPay;
    for (final inv in invoices) {
      for (final e in inv.debtLedger) {
        final lp = lastPay;
        if (lp == null || e.recordedAt.isAfter(lp)) lastPay = e.recordedAt;
      }
      if (inv.paidTowardInvoice > 0.009 && inv.debtLedger.isEmpty) {
        final lp = lastPay;
        if (lp == null || inv.issuedAt.isAfter(lp)) lastPay = inv.issuedAt;
      }
    }

    if (customer == null) {
      return KpmsPageShell(
        title: 'Customer',
        subtitle: 'Debt profile',
        body: Center(child: Text('Customer not found.', style: theme.textTheme.bodyLarge)),
      );
    }

    return KpmsPageShell(
      title: customer.name,
      subtitle: 'Accounts receivable',
      floatingActionButton: open > 0.009
          ? FloatingActionButton.extended(
              onPressed: () => showPayCustomerDebtSheet(
                context,
                ref,
                debtCustomerId: customerId,
                customerName: customer.name,
              ),
              icon: const Icon(Icons.payments_rounded),
              label: const Text('Pay debt'),
            )
          : null,
      body: ListView(
        padding: KpmsBreakpoints.pageScrollPadding(context, bottomExtra: clearance + 72),
        children: [
          _SummaryCard(
            phone: customer.phoneDisplay,
            notes: customer.notes,
            open: open,
            paidLife: paidLife,
            invoiceCount: invoices.length,
            lastPayment: lastPay,
          ),
          const SizedBox(height: 16),
          Text(
            'INVOICES',
            style: theme.textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
              color: theme.hintColor,
            ),
          ),
          const SizedBox(height: 8),
          ...invoices.map((inv) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Material(
                color: theme.colorScheme.surface,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: AppColors.outlineMuted.withValues(alpha: 0.75)),
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => context.push(
                    AppRoutes.debtsInvoice(inv.invoiceNumber),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                inv.invoiceNumber,
                                style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${inv.issuedAt.year}-${inv.issuedAt.month.toString().padLeft(2, '0')}-${inv.issuedAt.day.toString().padLeft(2, '0')}'
                                ' · Total \$${inv.total.toStringAsFixed(2)}',
                                style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              inv.hasOpenDebt ? 'Due' : 'Settled',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: inv.hasOpenDebt ? Colors.orange.shade800 : theme.hintColor,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              '\$${inv.remainingBalance.toStringAsFixed(2)}',
                              style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.phone,
    required this.notes,
    required this.open,
    required this.paidLife,
    required this.invoiceCount,
    required this.lastPayment,
  });

  final String phone;
  final String notes;
  final double open;
  final double paidLife;
  final int invoiceCount;
  final DateTime? lastPayment;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.outlineMuted.withValues(alpha: 0.75)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _row(theme, 'Phone', phone.isEmpty ? '—' : phone),
          if (notes.isNotEmpty) _row(theme, 'Notes', notes),
          const Divider(height: 20),
          _row(theme, 'Total invoices', '$invoiceCount'),
          _row(theme, 'Lifetime paid', '\$${paidLife.toStringAsFixed(2)}'),
          _row(theme, 'Remaining balance', '\$${open.toStringAsFixed(2)}', strong: true),
          _row(
            theme,
            'Last payment',
            lastPayment == null
                ? '—'
                : '${lastPayment!.year}-${lastPayment!.month.toString().padLeft(2, '0')}-${lastPayment!.day.toString().padLeft(2, '0')}',
          ),
        ],
      ),
    );
  }

  Widget _row(ThemeData theme, String k, String v, {bool strong = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 132,
            child: Text(
              k,
              style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor, fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(
            child: Text(
              v,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: strong ? FontWeight.w900 : FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
