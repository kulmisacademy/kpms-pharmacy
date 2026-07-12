import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_routes.dart';
import '../../../core/navigation/kpms_breakpoints.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/kpms_mobile_bottom_nav.dart';
import '../../../core/widgets/kpms_page_shell.dart';
import '../../purchases/application/purchase_ledger_notifier.dart';
import '../../sales/application/sales_ledger_notifier.dart';
import '../../suppliers/application/suppliers_notifier.dart';
import '../application/debt_customers_notifier.dart';
import '../application/supplier_payments_notifier.dart';
import '../../dashboard/application/dashboard_providers.dart';

class DebtsDashboardScreen extends ConsumerWidget {
  const DebtsDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final debtSummary = ref.watch(dashboardDebtSummaryProvider);
    final clearance = KpmsMobileBottomNav.scrollClearanceBottom(context);

    final ledger = ref.read(salesLedgerProvider.notifier);
    final customers = ref.read(debtCustomersProvider);
    final purchases = ref.watch(purchaseLedgerProvider).invoices;
    final supPay = ref.watch(supplierPaymentsProvider);

    final customerDebtTotal = debtSummary.customerDebtTotal;
    final supplierDebtTotal = debtSummary.supplierDebtTotal;

    final openSaleInvoices = ref
        .read(salesLedgerProvider)
        .invoices
        .where((i) => i.remainingBalance > 0.009)
        .toList()
      ..sort((a, b) => b.issuedAt.compareTo(a.issuedAt));

    final unpaidPurchases = purchases.where((p) {
      return p.effectiveRemainingBalance > 0.009;
    }).toList()
      ..sort((a, b) => b.issuedAt.compareTo(a.issuedAt));

    final recentSupPay = [...supPay]..sort((a, b) => b.paidAt.compareTo(a.paidAt));

    return KpmsPageShell(
      title: 'Debts & credit',
      subtitle: 'Customer AR · supplier AP',
      body: ListView(
        padding: KpmsBreakpoints.pageScrollPadding(context, bottomExtra: clearance + 8),
        children: [
          Row(
            children: [
              Expanded(
                child: _StatTile(
                  label: 'Customer debt',
                  value: '\$${customerDebtTotal.toStringAsFixed(2)}',
                  icon: Icons.people_outline_rounded,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _StatTile(
                  label: 'Supplier debt',
                  value: '\$${supplierDebtTotal.toStringAsFixed(2)}',
                  icon: Icons.local_shipping_outlined,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            'CUSTOMERS WITH PROFILES',
            style: theme.textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: 0.7,
              color: theme.hintColor,
            ),
          ),
          const SizedBox(height: 8),
          if (customers.isEmpty)
            Text('No debt customers yet — credit sales create profiles.', style: theme.textTheme.bodySmall)
          else
            ...customers.map((c) {
              final bal = ledger.openDebtTotalForCustomer(c.id);
              return _LinkRow(
                title: c.name,
                subtitle: c.phoneDisplay.isEmpty ? 'No phone' : c.phoneDisplay,
                trailing: '\$${bal.toStringAsFixed(2)}',
                onTap: () => context.push(AppRoutes.debtsCustomerProfile(c.id)),
              );
            }),
          const SizedBox(height: 20),
          Text(
            'OPEN SALE INVOICES',
            style: theme.textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: 0.7,
              color: theme.hintColor,
            ),
          ),
          const SizedBox(height: 8),
          if (openSaleInvoices.isEmpty)
            Text('None', style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor))
          else
            ...openSaleInvoices.take(8).map((inv) {
              return _LinkRow(
                title: inv.invoiceNumber,
                subtitle: inv.customerName,
                trailing: '\$${inv.remainingBalance.toStringAsFixed(2)}',
                onTap: () => context.push(
                  AppRoutes.debtsInvoice(inv.invoiceNumber),
                ),
              );
            }),
          const SizedBox(height: 20),
          Text(
            'UNPAID / PARTIAL PURCHASES',
            style: theme.textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: 0.7,
              color: theme.hintColor,
            ),
          ),
          const SizedBox(height: 8),
          if (unpaidPurchases.isEmpty)
            Text('None', style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor))
          else
            ...unpaidPurchases.take(8).map((p) {
              return _LinkRow(
                title: p.invoiceNumber,
                subtitle: p.supplierName,
                trailing: '\$${p.effectiveRemainingBalance.toStringAsFixed(2)} due',
                onTap: () => context.push('${AppRoutes.supplierFinance}/${p.supplierId}'),
              );
            }),
          const SizedBox(height: 20),
          Text(
            'RECENT SUPPLIER PAYMENTS',
            style: theme.textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: 0.7,
              color: theme.hintColor,
            ),
          ),
          const SizedBox(height: 8),
          if (recentSupPay.isEmpty)
            Text('None yet', style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor))
          else
            ...recentSupPay.take(6).map((r) {
              final sup = ref.read(suppliersProvider.notifier).byId(r.supplierId);
              return _LinkRow(
                title: '\$${r.amount.toStringAsFixed(2)}',
                subtitle: sup?.name ?? r.supplierId,
                trailing: '${r.paidAt.month}/${r.paidAt.day}',
                onTap: () => context.push('${AppRoutes.supplierFinance}/${r.supplierId}'),
              );
            }),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.outlineMuted.withValues(alpha: 0.75)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 22, color: theme.hintColor),
          const SizedBox(height: 8),
          Text(label, style: theme.textTheme.labelSmall?.copyWith(color: theme.hintColor)),
          const SizedBox(height: 4),
          Text(value, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}

class _LinkRow extends StatelessWidget {
  const _LinkRow({
    required this.title,
    required this.subtitle,
    required this.trailing,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final String trailing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
                      Text(subtitle, style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor)),
                    ],
                  ),
                ),
                Text(trailing, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
                Icon(Icons.chevron_right_rounded, color: theme.hintColor),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
