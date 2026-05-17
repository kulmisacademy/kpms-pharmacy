import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_routes.dart';
import '../../../core/navigation/kpms_breakpoints.dart';
import '../../../core/theme/app_colors.dart';
import '../../analytics/application/sales_analytics_notifier.dart';
import '../../debts/application/debt_customers_notifier.dart';
import '../../medicines/data/medicine_catalog_notifier.dart';
import '../../purchases/application/purchase_ledger_notifier.dart';
import '../application/report_hub_preview.dart';
import '../domain/kpms_report_id.dart';
import '../../../core/widgets/kpms_page_shell.dart';
import 'widgets/kpms_report_hub_card.dart';

/// PRD §5.12 — Enterprise analytics hub (detail pages: charts, tables, filters, export).
class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _entrance;

  @override
  void initState() {
    super.initState();
    _entrance = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
    _entrance.forward();
  }

  @override
  void dispose() {
    _entrance.dispose();
    super.dispose();
  }

  Animation<double> _itemCurve(int index) {
    final n = (index * 0.05).clamp(0.0, 0.4);
    return CurvedAnimation(
      parent: _entrance,
      curve: Interval(0.08 + n, 1.0, curve: Curves.easeOutCubic),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final analytics = ref.watch(salesAnalyticsProvider);
    final catalog = ref.watch(medicineCatalogProvider);
    final purchaseCount = ref.watch(purchaseLedgerProvider).invoices.length;
    final debtCount = ref.watch(debtCustomersProvider).length;
    final width = MediaQuery.sizeOf(context).width;
    const cross = 2;
    final aspect = width >= 720 ? 1.72 : 1.48;

    return KpmsPageShell(
      title: 'Reports',
      subtitle: 'Enterprise analytics · PDF · Excel · CSV',
      body: Padding(
        padding: KpmsBreakpoints.pageBodyInsets(context),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: FadeTransition(
                opacity: CurvedAnimation(parent: _entrance, curve: const Interval(0.0, 0.35, curve: Curves.easeOut)),
                child: SlideTransition(
                  position: Tween<Offset>(begin: const Offset(0, 0.05), end: Offset.zero).animate(
                    CurvedAnimation(parent: _entrance, curve: const Interval(0.0, 0.4, curve: Curves.easeOutCubic)),
                  ),
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      color: theme.colorScheme.surface,
                      border: Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.25)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            color: AppColors.primary.withValues(alpha: theme.brightness == Brightness.dark ? 0.22 : 0.12),
                          ),
                          child: Icon(Icons.auto_graph_rounded, size: 22, color: AppColors.primary),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Core & enterprise reports',
                                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'P&L, inventory, debt, suppliers, cashiers, and more — filters and exports on each detail page.',
                                style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor, height: 1.45),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 18)),
            SliverToBoxAdapter(
              child: Material(
                color: theme.colorScheme.surface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: theme.colorScheme.outline.withValues(alpha: 0.25)),
                ),
                child: ListTile(
                  leading: const Icon(Icons.payments_outlined),
                  title: const Text('Expense ledger'),
                  subtitle: const Text('Track rent, payroll, utilities — tenant-scoped'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => context.push(AppRoutes.expenses),
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 12)),
            SliverGrid(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: cross,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: aspect,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, i) {
                  final id = KpmsReportId.values[i];
                  final preview = reportHubPreview(
                    id: id,
                    analytics: analytics,
                    catalog: catalog,
                    purchaseInvoiceCount: purchaseCount,
                    debtCustomerCount: debtCount,
                  );
                  return KpmsReportHubCard(
                    report: id,
                    previewLine1: preview.line1,
                    previewLine2: preview.line2,
                    trendPct: preview.trendPct,
                    animation: _itemCurve(i),
                    onTap: () {
                      if (id == KpmsReportId.sales) {
                        context.push(AppRoutes.reportDetail('sales'));
                        return;
                      }
                      context.push(AppRoutes.reportDetail(id.slug));
                    },
                  );
                },
                childCount: KpmsReportId.values.length,
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
          ],
        ),
      ),
    );
  }
}
