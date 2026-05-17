import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/kpms_permission_context.dart';
import '../../../core/auth/permission_providers.dart';
import '../../../core/constants/app_routes.dart';
import '../../../core/supabase/supabase_bootstrap.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/responsive/responsive_breakpoints.dart';
import '../../../core/widgets/kpms_page_shell.dart';
import '../../../core/widgets/kpms_mobile_bottom_nav.dart';
import '../../settings/application/pharmacy_settings_providers.dart';
import '../../debts/application/debt_customers_notifier.dart';
import '../../debts/application/supplier_payments_notifier.dart';
import '../../suppliers/application/suppliers_notifier.dart';
import '../../analytics/application/sales_analytics_notifier.dart';
import '../../medicines/data/medicine_catalog_notifier.dart';
import '../../medicines/domain/medicine.dart';
import '../../purchases/application/purchase_ledger_notifier.dart';
import '../../sales/application/sales_ledger_notifier.dart';
import '../../../core/widgets/kpms_empty_state.dart';
import '../../../l10n/app_localizations.dart';
import '../../../l10n/l10n_context.dart';

/// Pharmacy home — KPI grid, session analytics, and activity (mobile-first layout).
class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _entrance;
  int _analyticsPeriod = 0; // 0 daily · 1 weekly · 2 monthly

  bool _routeAllowed(KpmsPermissionContext? p, String route) {
    if (p == null) return false;
    if (p.isPharmacyAdminTier) return true;
    return p.canAccessLocation(route);
  }

  @override
  void initState() {
    super.initState();
    _entrance = AnimationController(vsync: this, duration: const Duration(milliseconds: 880));
    _entrance.forward();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final c = SupabaseBootstrap.clientOrNull;
      if (c != null) {
        c.rpc('touch_my_tenant_activity').catchError((_) {});
      }
    });
  }

  @override
  void dispose() {
    _entrance.dispose();
    super.dispose();
  }

  Animation<double> _itemCurve(int index, {double start = 0.12}) {
    final n = (index * 0.045).clamp(0.0, 0.35);
    return CurvedAnimation(
      parent: _entrance,
      curve: Interval(start + n, 1.0, curve: Curves.easeOutCubic),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final outline = theme.colorScheme.outline.withValues(alpha: 0.35);
    final analytics = ref.watch(salesAnalyticsProvider);
    final canFin = ref.watch(kpmsCanViewFinancialMetricsProvider);
    final perm = ref.watch(kpmsPermissionContextProvider).valueOrNull;
    final lowStock = ref.watch(lowStockMedicinesProvider);
    final meds = ref.watch(medicineCatalogProvider);
    final salesLedger = ref.watch(salesLedgerProvider);
    final purchaseLedger = ref.watch(purchaseLedgerProvider);
    final debtCustomers = ref.watch(debtCustomersProvider);
    final suppliers = ref.watch(suppliersProvider);
    final supPay = ref.watch(supplierPaymentsProvider);

    final ledger = ref.read(salesLedgerProvider.notifier);
    var customerDebtTotal = 0.0;
    for (final c in debtCustomers) {
      customerDebtTotal += ledger.openDebtTotalForCustomer(c.id);
    }
    final supplierDebtTotal = suppliers.fold(0.0, (s, x) => s + x.balanceOwed);
    final suppliersNotifier = ref.read(suppliersProvider.notifier);

    final recentItems = <({DateTime at, String title, String subtitle, IconData icon, Color accent, String route})>[];
    for (final inv in salesLedger.invoices.take(40)) {
      recentItems.add((
        at: inv.issuedAt,
        title: l.dashRecentSaleTitle(inv.invoiceNumber),
        subtitle: canFin
            ? l.dashRecentSaleSubtitleWithAmount('\$${inv.total.toStringAsFixed(2)}', inv.paymentMethod)
            : l.dashRecentSaleSubtitleNoAmount(inv.paymentMethod),
        icon: Icons.receipt_long_rounded,
        accent: AppColors.tertiary,
        route: AppRoutes.pos,
      ));
    }
    for (final p in purchaseLedger.invoices.take(40)) {
      recentItems.add((
        at: p.issuedAt,
        title: l.dashRecentPurchaseTitle(p.invoiceNumber),
        subtitle: l.dashRecentPurchaseSubtitle(p.supplierName),
        icon: Icons.local_shipping_rounded,
        accent: AppColors.secondary,
        route: AppRoutes.purchases,
      ));
    }
    for (final pay in supPay.take(30)) {
      final sup = suppliersNotifier.byId(pay.supplierId);
      recentItems.add((
        at: pay.paidAt,
        title: l.dashRecentSupplierPayment,
        subtitle: l.dashRecentSupplierPaymentSubtitle(sup?.name ?? l.dashSupplierFallback, '\$${pay.amount.toStringAsFixed(2)}'),
        icon: Icons.account_balance_rounded,
        accent: AppColors.primary,
        route: '${AppRoutes.supplierFinance}/${pay.supplierId}',
      ));
    }
    recentItems.sort((a, b) => b.at.compareTo(a.at));
    final recentRows = recentItems
        .where((e) => _routeAllowed(perm, e.route))
        .take(12)
        .map(
          (e) => (
            title: e.title,
            subtitle: e.subtitle,
            icon: e.icon,
            accent: e.accent,
            route: e.route,
          ),
        )
        .toList(growable: false);

    final salesSpotsRaw = analytics.dailySeries.isNotEmpty
        ? [for (var i = 0; i < analytics.dailySeries.length; i++) FlSpot(i.toDouble(), analytics.dailySeries[i])]
        : (analytics.dailyTotal > 0.009 ? [FlSpot(0, analytics.dailyTotal)] : <FlSpot>[]);
    final salesSpots = canFin ? salesSpotsRaw : <FlSpot>[];

    final monthlySpotsRaw = analytics.monthlySeries.isNotEmpty
        ? [for (var i = 0; i < analytics.monthlySeries.length; i++) FlSpot(i.toDouble(), analytics.monthlySeries[i])]
        : (analytics.monthlyTotal > 0.009 ? [FlSpot(0, analytics.monthlyTotal)] : <FlSpot>[]);
    final monthlySpots = canFin ? monthlySpotsRaw : <FlSpot>[];

    final barGroups = [
      for (var i = 0; i < analytics.topSelling.length && i < 5; i++)
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: analytics.topSelling[i].$2.toDouble().clamp(0, 1e9),
              color: AppColors.primary,
              width: 10,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
            ),
          ],
        ),
    ];
    final barLabels = [
      for (var i = 0; i < analytics.topSelling.length && i < 5; i++)
        analytics.topSelling[i].$1.length > 12 ? '${analytics.topSelling[i].$1.substring(0, 11)}…' : analytics.topSelling[i].$1,
    ];

    final showPerfCharts = salesSpots.isNotEmpty || barGroups.isNotEmpty;
    final expiringSoon = meds.where((m) {
      final e = m.expiryDate;
      if (e == null) return false;
      return e.difference(DateTime.now()).inDays <= 90;
    }).length;

    final pharmacyName = ref.watch(pharmacyBrandingProvider).businessName;

    return KpmsPageShell(
      title: l.dashboardTitle,
      subtitle: pharmacyName.isEmpty ? l.dashboardSubtitleOverview : pharmacyName,
      body: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(0, 12, 0, 16),
            sliver: SliverToBoxAdapter(
              child: FadeTransition(
                opacity: CurvedAnimation(parent: _entrance, curve: const Interval(0.0, 0.45, curve: Curves.easeOut)),
                child: SlideTransition(
                  position: Tween<Offset>(begin: const Offset(0, 0.04), end: Offset.zero).animate(
                    CurvedAnimation(parent: _entrance, curve: const Interval(0.0, 0.5, curve: Curves.easeOutCubic)),
                  ),
                  child: _DashKpiStrip(
                    outline: outline,
                    perm: perm,
                    canFin: canFin,
                    analytics: analytics,
                    medicineCount: meds.length,
                    lowStockCount: lowStock.length,
                    expiringSoonCount: expiringSoon,
                    customerCreditTotal: customerDebtTotal,
                    supplierDebtTotal: supplierDebtTotal,
                  ),
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.only(bottom: 8),
            sliver: SliverToBoxAdapter(
              child: _SectionTitle(
                icon: Icons.show_chart_rounded,
                label: l.dashSectionSalesProfit,
                hint: l.dashSectionSalesProfitHint,
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.only(bottom: 16),
            sliver: SliverToBoxAdapter(
              child: LayoutBuilder(
                builder: (context, c) {
                  if (!showPerfCharts) {
                    return _ChartShell(
                      outline: outline,
                      child: KpmsEmptyState(
                        icon: Icons.insert_chart_outlined,
                        title: l.dashEmptySalesAnalyticsTitle,
                        message: l.dashEmptySalesAnalyticsMessage,
                        actionLabel: _routeAllowed(perm, AppRoutes.pos) ? l.dashOpenPos : null,
                        onAction: _routeAllowed(perm, AppRoutes.pos) ? () => context.push(AppRoutes.pos) : null,
                      ),
                    );
                  }
                  final twoCol = c.maxWidth > 820;
                  Widget chartCard({required Widget child}) => _ChartShell(outline: outline, child: child);
                  final line = chartCard(
                    child: !canFin
                        ? Padding(
                            padding: const EdgeInsets.fromLTRB(0, 24, 0, 32),
                            child: Text(
                              l.dashRevenueHiddenRole,
                              textAlign: TextAlign.center,
                              style: theme.textTheme.bodyMedium?.copyWith(color: theme.hintColor),
                            ),
                          )
                        : salesSpots.isEmpty
                            ? Padding(
                                padding: const EdgeInsets.fromLTRB(0, 24, 0, 32),
                                child: Text(
                                  l.dashRevenueTrendPlaceholder,
                                  textAlign: TextAlign.center,
                                  style: theme.textTheme.bodyMedium?.copyWith(color: theme.hintColor),
                                ),
                              )
                            : _SalesLineChart(
                                spots: salesSpots,
                                isDark: theme.brightness == Brightness.dark,
                                title: l.dashDailySales,
                                subtitle: l.dashRevenuePulse,
                              ),
                  );
                  final bars = chartCard(
                    child: barGroups.isEmpty
                        ? Padding(
                            padding: const EdgeInsets.fromLTRB(0, 24, 0, 32),
                            child: Text(
                              l.dashTopSellingPlaceholder,
                              textAlign: TextAlign.center,
                              style: theme.textTheme.bodyMedium?.copyWith(color: theme.hintColor),
                            ),
                          )
                        : _CategoryBarChart(
                            groups: barGroups,
                            barLabels: barLabels,
                            isDark: theme.brightness == Brightness.dark,
                          ),
                  );
                  if (twoCol) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: line),
                        const SizedBox(width: 14),
                        Expanded(child: bars),
                      ],
                    );
                  }
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      line,
                      const SizedBox(height: 14),
                      bars,
                    ],
                  );
                },
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.only(bottom: 16),
            sliver: SliverToBoxAdapter(
              child: LayoutBuilder(
                builder: (context, c) {
                  final twoCol = c.maxWidth > 720;
                  Widget monthChart() {
                    return _ChartShell(
                      outline: outline,
                      child: !canFin
                          ? Padding(
                              padding: const EdgeInsets.fromLTRB(0, 24, 0, 32),
                              child: Text(
                                l.dashMonthlyTrendHidden,
                                textAlign: TextAlign.center,
                                style: theme.textTheme.bodyMedium?.copyWith(color: theme.hintColor),
                              ),
                            )
                          : monthlySpots.isEmpty
                              ? Padding(
                                  padding: const EdgeInsets.fromLTRB(0, 24, 0, 32),
                                  child: Text(
                                    l.dashMonthlySeriesPlaceholder,
                                    textAlign: TextAlign.center,
                                    style: theme.textTheme.bodyMedium?.copyWith(color: theme.hintColor),
                                  ),
                                )
                              : _SalesLineChart(
                                  spots: monthlySpots,
                                  isDark: theme.brightness == Brightness.dark,
                                  title: l.dashMonthlySales,
                                  subtitle: l.dashMonthlyTrajectory,
                                ),
                    );
                  }
                  final profit = _ChartShell(
                    outline: outline,
                    child: _ProfitMtdPanel(canFin: canFin, profit: analytics.totalProfitMonth),
                  );
                  if (twoCol) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: monthChart()),
                        const SizedBox(width: 14),
                        Expanded(child: profit),
                      ],
                    );
                  }
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      monthChart(),
                      const SizedBox(height: 14),
                      profit,
                    ],
                  );
                },
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.only(bottom: 8),
            sliver: SliverToBoxAdapter(
              child: _SectionTitle(
                icon: Icons.inventory_2_outlined,
                label: l.dashSectionInventory,
                hint: l.dashSectionInventoryHint,
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.only(bottom: 16),
            sliver: SliverToBoxAdapter(
              child: _InventoryInsightsRow(
                outline: outline,
                perm: perm,
                lowStock: lowStock,
                expiringSoon: expiringSoon,
                topSelling: analytics.topSelling,
              ),
            ),
          ),
          if (lowStock.isNotEmpty)
            SliverPadding(
              padding: const EdgeInsets.only(bottom: 14),
              sliver: SliverToBoxAdapter(
                child: _LowStockAlertBanner(
                  lowStock: lowStock,
                  outline: outline,
                  canOpenMedicines: _routeAllowed(perm, AppRoutes.medicines),
                ),
              ),
            ),
          SliverPadding(
            padding: const EdgeInsets.only(bottom: 16),
            sliver: SliverToBoxAdapter(
              child: _AnalyticsInsightsCard(
                analytics: analytics,
                lowStock: lowStock,
                outline: outline,
                periodIndex: _analyticsPeriod,
                onPeriodChanged: (i) => setState(() => _analyticsPeriod = i),
                isDark: theme.brightness == Brightness.dark,
                showFinancialMetrics: canFin,
              ),
            ),
          ),
          if (perm != null && (perm.isPharmacyAdminTier || perm.canManageStaffDirectory))
            SliverPadding(
              padding: const EdgeInsets.only(bottom: 16),
              sliver: SliverToBoxAdapter(
                child: _StaffOpsCard(outline: outline),
              ),
            ),
          SliverPadding(
            padding: const EdgeInsets.only(bottom: 8),
            sliver: SliverToBoxAdapter(
              child: FadeTransition(
                opacity: CurvedAnimation(parent: _entrance, curve: const Interval(0.22, 0.72, curve: Curves.easeOut)),
                child: _SectionTitle(
                  icon: Icons.history_rounded,
                  label: l.dashSectionRecentActivity,
                  hint: l.dashSectionRecentActivityHint,
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: EdgeInsets.fromLTRB(0, 0, 0, 28 + KpmsMobileBottomNav.scrollClearanceBottom(context)),
            sliver: recentRows.isEmpty
                ? SliverToBoxAdapter(
                    child: _ChartShell(
                      outline: outline,
                      child: KpmsEmptyState(
                        icon: Icons.history_rounded,
                        title: l.dashEmptyRecentTitle,
                        message: l.dashEmptyRecentMessage,
                        actionLabel: _routeAllowed(perm, AppRoutes.pos) ? l.dashStartSale : null,
                        onAction: _routeAllowed(perm, AppRoutes.pos) ? () => context.push(AppRoutes.pos) : null,
                      ),
                    ),
                  )
                : SliverList.separated(
                    itemCount: recentRows.length,
                    separatorBuilder: (context, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final row = recentRows[index];
                      final fadeAnim = _itemCurve(index, start: 0.26);
                      final slideAnim = _itemCurve(index, start: 0.26);
                      return FadeTransition(
                        opacity: fadeAnim,
                        child: SlideTransition(
                          position: Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero).animate(slideAnim),
                          child: _RecentRow(
                            title: row.title,
                            subtitle: row.subtitle,
                            icon: row.icon,
                            accent: row.accent,
                            outline: outline,
                            onTap: () => context.push(row.route),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({
    required this.icon,
    required this.label,
    required this.hint,
  });

  final IconData icon;
  final String label;
  final String hint;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: AppColors.primary.withValues(alpha: 0.92)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.25),
                ),
                Text(
                  hint,
                  style: theme.textTheme.labelSmall?.copyWith(color: theme.hintColor, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DashKpiStrip extends StatelessWidget {
  const _DashKpiStrip({
    required this.outline,
    required this.perm,
    required this.canFin,
    required this.analytics,
    required this.medicineCount,
    required this.lowStockCount,
    required this.expiringSoonCount,
    required this.customerCreditTotal,
    required this.supplierDebtTotal,
  });

  final Color outline;
  final KpmsPermissionContext? perm;
  final bool canFin;
  final SalesAnalyticsState analytics;
  final int medicineCount;
  final int lowStockCount;
  final int expiringSoonCount;
  final double customerCreditTotal;
  final double supplierDebtTotal;

  bool _allow(BuildContext context, String route) {
    final p = perm;
    if (p == null) return false;
    if (p.isPharmacyAdminTier) return true;
    return p.canAccessLocation(route);
  }

  static String _money0(double v) => '\$${v.toStringAsFixed(0)}';

  static int _crossAxisCount(double w) {
    if (w < ResponsiveBreakpoints.mobile) return 2;
    if (w < ResponsiveBreakpoints.desktop) return 3;
    return 4;
  }

  static double _rowExtent(BuildContext context, int cols) {
    final scale = MediaQuery.textScalerOf(context).scale(14) / 14.0;
    final double base;
    if (cols <= 2) {
      base = 122;
    } else if (cols <= 3) {
      base = 116;
    } else {
      base = 120;
    }
    return (base * scale.clamp(1.0, 1.22)).clamp(108.0, 136.0);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return LayoutBuilder(
      builder: (context, c) {
        final w = c.maxWidth.isFinite ? c.maxWidth : MediaQuery.sizeOf(context).width;
        final cols = _crossAxisCount(w);
        final gap = 10.0;
        final rowExtent = _rowExtent(context, cols);

        final cards = <Widget>[];
        void addCard(Widget w) => cards.add(w);

        if (_allow(context, AppRoutes.pos)) {
          addCard(
            _DashMetricCard(
              outline: outline,
              icon: Icons.payments_outlined,
              label: l.dashKpiTotalSales,
              value: !canFin ? '•••' : (analytics.monthlyTotal > 0.009 ? _money0(analytics.monthlyTotal) : '—'),
              foot: l.dashKpiThisMonth,
              trend: canFin && analytics.monthlyTotal > 0.009 ? _SalesTrendBadge(monthly: analytics.monthlyTotal, weekly: analytics.weeklyTotal) : null,
              onTap: () => context.push(AppRoutes.pos),
            ),
          );
        }
        if (_allow(context, AppRoutes.debts)) {
          addCard(
            _DashMetricCard(
              outline: outline,
              icon: Icons.people_outline,
              label: l.dashKpiCustomerCredits,
              value: !canFin ? '•••' : _money0(customerCreditTotal),
              foot: l.dashKpiOpenAr,
              onTap: () => context.push(AppRoutes.debts),
            ),
          );
        }
        if (_allow(context, AppRoutes.suppliers)) {
          addCard(
            _DashMetricCard(
              outline: outline,
              icon: Icons.local_shipping_outlined,
              label: l.dashKpiSupplierDebts,
              value: !canFin ? '•••' : _money0(supplierDebtTotal),
              foot: l.dashKpiOpenAp,
              onTap: () => context.push(AppRoutes.suppliers),
            ),
          );
        }
        if (_allow(context, AppRoutes.medicines)) {
          addCard(
            _DashMetricCard(
              outline: outline,
              icon: Icons.medication_outlined,
              label: l.dashKpiTotalMedicines,
              value: '$medicineCount',
              foot: l.dashKpiCatalogSkus,
              onTap: () => context.push(AppRoutes.medicines),
            ),
          );
        }
        if (_allow(context, AppRoutes.inventory)) {
          addCard(
            _DashMetricCard(
              outline: outline,
              icon: Icons.inventory_2_outlined,
              label: l.dashKpiLowStock,
              value: lowStockCount > 0 ? '$lowStockCount' : '—',
              foot: l.dashKpiBelowMinimum,
              trend: lowStockCount > 0 ? const Icon(Icons.warning_amber_rounded, size: 16, color: Color(0xFFD97706)) : null,
              onTap: () => context.push(AppRoutes.inventory),
            ),
          );
        }
        if (_allow(context, AppRoutes.medicines)) {
          addCard(
            _DashMetricCard(
              outline: outline,
              icon: Icons.event_busy_outlined,
              label: l.dashKpiExpiringSoon,
              value: expiringSoonCount > 0 ? '$expiringSoonCount' : '—',
              foot: l.dashKpiWithin90Days,
              trend: expiringSoonCount > 0 ? Icon(Icons.schedule_rounded, size: 16, color: Colors.orange.shade800) : null,
              onTap: () => context.push(AppRoutes.medicines),
            ),
          );
        }

        if (cards.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 12),
            child: Text(
              'No KPI shortcuts are available for your assigned permissions.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).hintColor, height: 1.35),
            ),
          );
        }

        return GridView(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: cols,
            mainAxisExtent: rowExtent,
            crossAxisSpacing: gap,
            mainAxisSpacing: gap,
          ),
          children: cards,
        );
      },
    );
  }
}

class _SalesTrendBadge extends StatelessWidget {
  const _SalesTrendBadge({required this.monthly, required this.weekly});

  final double monthly;
  final double weekly;

  @override
  Widget build(BuildContext context) {
    if (monthly <= 0.009) return const SizedBox.shrink();
    final pace = weekly * 4.2;
    IconData icon;
    Color color;
    if (monthly > pace * 1.06) {
      icon = Icons.trending_up_rounded;
      color = const Color(0xFF15803D);
    } else if (monthly < pace * 0.88) {
      icon = Icons.trending_down_rounded;
      color = const Color(0xFFC2410C);
    } else {
      icon = Icons.trending_flat_rounded;
      color = const Color(0xFF64748B);
    }
    return Icon(icon, size: 15, color: color);
  }
}

class _DashMetricCard extends StatefulWidget {
  const _DashMetricCard({
    required this.outline,
    required this.icon,
    required this.label,
    required this.value,
    required this.foot,
    this.trend,
    this.onTap,
  });

  final Color outline;
  final IconData icon;
  final String label;
  final String value;
  final String foot;
  final Widget? trend;
  final VoidCallback? onTap;

  @override
  State<_DashMetricCard> createState() => _DashMetricCardState();
}

class _DashMetricCardState extends State<_DashMetricCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = AppColors.primary.withValues(alpha: 0.9);
    final muted = theme.hintColor;

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: theme.colorScheme.surface,
          border: Border.all(color: widget.outline.withValues(alpha: _hover ? 0.5 : 0.36)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: theme.brightness == Brightness.dark ? 0.22 : 0.06),
              blurRadius: _hover ? 12 : 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: widget.onTap,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Icon(widget.icon, size: 18, color: primary),
                      const Spacer(),
                      if (widget.trend != null)
                        SizedBox(height: 20, width: 22, child: FittedBox(fit: BoxFit.scaleDown, child: widget.trend!)),
                    ],
                  ),
                  const Spacer(),
                  Text(
                    widget.value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.35,
                      height: 1.05,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    widget.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: muted,
                      height: 1.15,
                      fontSize: 11,
                    ),
                  ),
                  Text(
                    widget.foot,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: muted.withValues(alpha: 0.88),
                      fontSize: 10,
                      height: 1.1,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ProfitMtdPanel extends StatelessWidget {
  const _ProfitMtdPanel({
    required this.canFin,
    required this.profit,
  });

  final bool canFin;
  final double profit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l = context.l10n;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l.dashProfitTrend, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 2),
          Text(l.dashProfitMtdSession, style: theme.textTheme.labelSmall?.copyWith(color: theme.hintColor)),
          const SizedBox(height: 16),
          if (!canFin)
            Text(l.dashHiddenForRole, style: theme.textTheme.bodyMedium?.copyWith(color: theme.hintColor))
          else ...[
            Text(
              '\$${profit.toStringAsFixed(2)}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900, letterSpacing: -0.6),
            ),
            const SizedBox(height: 10),
            Text(
              l.dashProfitHintBody,
              softWrap: true,
              maxLines: 5,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor, height: 1.45),
            ),
          ],
        ],
      ),
    );
  }
}

class _InventoryInsightsRow extends StatelessWidget {
  const _InventoryInsightsRow({
    required this.outline,
    required this.perm,
    required this.lowStock,
    required this.expiringSoon,
    required this.topSelling,
  });

  final Color outline;
  final KpmsPermissionContext? perm;
  final List<Medicine> lowStock;
  final int expiringSoon;
  final List<(String, int)> topSelling;

  bool _allow(BuildContext context, String route) {
    final p = perm;
    if (p == null) return false;
    if (p.isPharmacyAdminTier) return true;
    return p.canAccessLocation(route);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        var w = c.maxWidth;
        if (!w.isFinite || w <= 0) {
          w = MediaQuery.sizeOf(context).width;
        }
        final gap = 10.0;
        final l = context.l10n;
        /// Phones / narrow: 2 equal columns on first row, third card full width (no horizontal overflow).
        final useTwoColLayout = w < 720;
        final lowLines = lowStock.take(4).map((m) => '${m.name} (${m.quantity})').join('\n');
        final topLines = topSelling.isEmpty
            ? l.dashInsightVelocityPlaceholder
            : topSelling.take(4).map((t) => l.dashTopSellingLine(t.$1, '${t.$2}')).join('\n');

        Widget cell({
          required IconData icon,
          required String title,
          required String body,
          required VoidCallback? onTap,
          bool expandToParent = true,
        }) {
          return _InsightCell(outline: outline, icon: icon, title: title, body: body, onTap: onTap, expandToParent: expandToParent);
        }

        final a = cell(
          icon: Icons.warning_amber_outlined,
          title: l.dashInsightLowStock,
          body: lowStock.isEmpty ? l.dashInsightLowStockAllOk : lowLines,
          onTap: _allow(context, AppRoutes.inventory) ? () => context.push(AppRoutes.inventory) : null,
        );
        final b = cell(
          icon: Icons.event_busy_outlined,
          title: l.dashInsightExpiringSoon,
          body: expiringSoon > 0 ? l.dashInsightExpiringSkuCount('$expiringSoon') : l.dashInsightExpiringNone,
          onTap: _allow(context, AppRoutes.medicines) ? () => context.push(AppRoutes.medicines) : null,
        );
        final d = cell(
          icon: Icons.bolt_outlined,
          title: l.dashInsightFastSelling,
          body: topLines,
          onTap: _allow(context, AppRoutes.pos) ? () => context.push(AppRoutes.pos) : null,
          expandToParent: !useTwoColLayout,
        );

        if (useTwoColLayout) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                // [stretch] + unbounded sliver height => infinite cross-axis; breaks layout (blank dashboard).
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: a),
                  SizedBox(width: gap),
                  Expanded(child: b),
                ],
              ),
              SizedBox(height: gap),
              d,
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: a),
            SizedBox(width: gap),
            Expanded(child: b),
            SizedBox(width: gap),
            Expanded(child: d),
          ],
        );
      },
    );
  }
}

class _InsightCell extends StatefulWidget {
  const _InsightCell({
    required this.outline,
    required this.icon,
    required this.title,
    required this.body,
    required this.onTap,
    this.expandToParent = true,
  });

  final Color outline;
  final IconData icon;
  final String title;
  final String body;
  final VoidCallback? onTap;
  /// When true (cells inside a stretched [Row]), fill height so siblings match. False for full-width stacked cells.
  final bool expandToParent;

  @override
  State<_InsightCell> createState() => _InsightCellState();
}

class _InsightCellState extends State<_InsightCell> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: theme.colorScheme.surface,
          border: Border.all(color: widget.outline.withValues(alpha: _hover ? 0.55 : 0.4)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: theme.brightness == Brightness.dark ? 0.22 : 0.04),
              blurRadius: _hover ? 12 : 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Material(
          color: Colors.transparent,
          clipBehavior: Clip.antiAlias,
          child: widget.onTap == null
              ? Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(14, 14, 14, 14),
                  child: _InsightCardContent(
                    expandToParent: widget.expandToParent,
                    icon: widget.icon,
                    title: widget.title,
                    body: widget.body,
                  ),
                )
              : InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: widget.onTap,
                  child: _InsightCardContent(
                    expandToParent: widget.expandToParent,
                    icon: widget.icon,
                    title: widget.title,
                    body: widget.body,
                  ),
                ),
        ),
      ),
    );
  }
}

class _InsightCardContent extends StatelessWidget {
  const _InsightCardContent({
    required this.expandToParent,
    required this.icon,
    required this.title,
    required this.body,
  });

  final bool expandToParent;
  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    Widget column({required bool fillBody}) {
      return Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(14, 14, 14, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.start,
          mainAxisSize: fillBody ? MainAxisSize.max : MainAxisSize.min,
          children: [
            Icon(icon, size: 26, color: AppColors.primary.withValues(alpha: 0.9)),
            const SizedBox(height: 10),
            Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            if (fillBody)
              Expanded(
                child: Align(
                  alignment: AlignmentDirectional.topStart,
                  child: Text(
                    body,
                    softWrap: true,
                    maxLines: 8,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor, height: 1.35),
                  ),
                ),
              )
            else
              Text(
                body,
                softWrap: true,
                maxLines: 8,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor, height: 1.35),
              ),
          ],
        ),
      );
    }

    if (!expandToParent) {
      return column(fillBody: false);
    }

    // Inside a sliver / unbounded vertical parent, max height is infinite; [Expanded] + [SizedBox.expand] assert.
    return LayoutBuilder(
      builder: (context, constraints) {
        final bounded = constraints.hasBoundedHeight;
        if (bounded) {
          return SizedBox.expand(child: column(fillBody: true));
        }
        return column(fillBody: false);
      },
    );
  }
}

class _StaffOpsCard extends StatelessWidget {
  const _StaffOpsCard({required this.outline});

  final Color outline;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l = context.l10n;
    return Material(
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: outline.withValues(alpha: 0.4)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => context.push(AppRoutes.staff),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Row(
            children: [
              Icon(Icons.badge_outlined, color: AppColors.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l.dashStaffPermissionsTitle, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
                    Text(
                      l.dashStaffPermissionsHint,
                      style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor, height: 1.35),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: theme.hintColor.withValues(alpha: 0.7)),
            ],
          ),
        ),
      ),
    );
  }
}

class _LowStockAlertBanner extends StatelessWidget {
  const _LowStockAlertBanner({
    required this.lowStock,
    required this.outline,
    this.canOpenMedicines = true,
  });

  final List<Medicine> lowStock;
  final Color outline;
  final bool canOpenMedicines;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l = context.l10n;
    return Material(
      color: Colors.orange.withValues(alpha: 0.12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: Colors.orange.withValues(alpha: 0.45)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange.shade800),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l.dashLowStockBanner(lowStock.length),
                    style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    lowStock.map((m) => '${m.name} (${m.quantity})').take(4).join(' · ') +
                        (lowStock.length > 4 ? '…' : ''),
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor, height: 1.35),
                  ),
                ],
              ),
            ),
            TextButton(
              onPressed: canOpenMedicines ? () => context.push(AppRoutes.medicines) : null,
              child: Text(l.dashReview),
            ),
          ],
        ),
      ),
    );
  }
}

class _AnalyticsInsightsCard extends StatelessWidget {
  const _AnalyticsInsightsCard({
    required this.analytics,
    required this.lowStock,
    required this.outline,
    required this.periodIndex,
    required this.onPeriodChanged,
    required this.isDark,
    required this.showFinancialMetrics,
  });

  final SalesAnalyticsState analytics;
  final List<Medicine> lowStock;
  final Color outline;
  final int periodIndex;
  final ValueChanged<int> onPeriodChanged;
  final bool isDark;
  final bool showFinancialMetrics;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l = context.l10n;
    final textTheme = theme.textTheme;
    final grid = theme.colorScheme.outline.withValues(alpha: isDark ? 0.22 : 0.35);

    final series = switch (periodIndex) {
      0 => analytics.dailySeries,
      1 => analytics.weeklySeries,
      _ => analytics.monthlySeries,
    };
    final headline = switch (periodIndex) {
      0 => analytics.dailyTotal,
      1 => analytics.weeklyTotal,
      _ => analytics.monthlyTotal,
    };
    final profit = analytics.totalProfitMonth;

    final hasSeries = series.isNotEmpty && series.any((v) => v > 0.009);
    final safeSeries = hasSeries ? series : <double>[];
    final maxY = safeSeries.isEmpty ? 1.0 : safeSeries.reduce((a, b) => a > b ? a : b);
    final spots = [for (var i = 0; i < safeSeries.length; i++) FlSpot(i.toDouble(), safeSeries[i])];

    return Material(
      color: theme.colorScheme.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22), side: BorderSide(color: outline)),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LayoutBuilder(
              builder: (context, c) {
                final periodPicker = SegmentedButton<int>(
                  segments: [
                    ButtonSegment(value: 0, label: Text(l.dashSegmentDay)),
                    ButtonSegment(value: 1, label: Text(l.dashSegmentWeek)),
                    ButtonSegment(value: 2, label: Text(l.dashSegmentMonth)),
                  ],
                  selected: {periodIndex},
                  onSelectionChanged: (s) => onPeriodChanged(s.first),
                );
                if (c.maxWidth < 400) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(l.dashInsightsTitle, style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
                      const SizedBox(height: 10),
                      periodPicker,
                    ],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Text(
                        l.dashInsightsTitle,
                        style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      fit: FlexFit.loose,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: AlignmentDirectional.centerEnd,
                        child: periodPicker,
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 14),
            LayoutBuilder(
              builder: (context, c) {
                final narrow = c.maxWidth < 560;
                final tiles = <Widget>[
                  if (showFinancialMetrics)
                    _miniStat(theme, l.dashMiniRevenue, '\$${headline.toStringAsFixed(0)}', Icons.trending_up_rounded)
                  else
                    _miniStat(theme, l.dashMiniRevenue, '—', Icons.lock_outline_rounded),
                  if (showFinancialMetrics)
                    _miniStat(theme, l.dashMiniProfitMo, '\$${profit.toStringAsFixed(0)}', Icons.account_balance_wallet_rounded)
                  else
                    _miniStat(theme, l.dashMiniProfitMo, '—', Icons.lock_outline_rounded),
                  _miniStat(theme, l.dashMiniTopSku, analytics.topSelling.isEmpty ? '—' : analytics.topSelling.first.$1, Icons.star_rounded),
                ];
                if (narrow) {
                  return Column(
                    children: [
                      for (var i = 0; i < tiles.length; i++) ...[if (i > 0) const SizedBox(height: 8), tiles[i]],
                    ],
                  );
                }
                return Row(
                  children: [
                    for (var i = 0; i < tiles.length; i++) ...[
                      if (i > 0) const SizedBox(width: 10),
                      Expanded(child: tiles[i]),
                    ],
                  ],
                );
              },
            ),
            const SizedBox(height: 14),
            Text(
              switch (periodIndex) {
                0 => l.dashInsightCaptionDaily,
                1 => l.dashInsightCaptionWeekly,
                _ => l.dashInsightCaptionMonthly,
              },
              style: textTheme.labelMedium?.copyWith(color: theme.hintColor, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 160,
              child: !hasSeries
                  ? Center(
                      child: Text(
                        l.dashChartsEmptyHint,
                        textAlign: TextAlign.center,
                        style: textTheme.bodySmall?.copyWith(color: theme.hintColor),
                      ),
                    )
                  : !showFinancialMetrics
                      ? Center(
                          child: Text(
                            l.dashFinancialChartHiddenRole,
                            textAlign: TextAlign.center,
                            style: textTheme.bodySmall?.copyWith(color: theme.hintColor),
                          ),
                        )
                      : LineChart(
                      LineChartData(
                        minX: 0,
                        maxX: (safeSeries.length - 1).clamp(0, 1 << 20).toDouble(),
                        minY: 0,
                        maxY: (maxY <= 0 ? 1.0 : maxY) * 1.15,
                        gridData: FlGridData(
                          show: true,
                          drawVerticalLine: false,
                          horizontalInterval: null,
                          getDrawingHorizontalLine: (v) => FlLine(color: grid, strokeWidth: 1),
                        ),
                        borderData: FlBorderData(show: false),
                        titlesData: FlTitlesData(
                          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 36,
                              getTitlesWidget: (v, m) =>
                                  Text(v.toInt().toString(), style: textTheme.labelSmall?.copyWith(color: theme.hintColor, fontSize: 10)),
                            ),
                          ),
                          bottomTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        ),
                        lineBarsData: [
                          LineChartBarData(
                            spots: spots,
                            isCurved: true,
                            curveSmoothness: 0.35,
                            color: AppColors.primary,
                            barWidth: 3,
                            isStrokeCapRound: true,
                            dotData: FlDotData(
                              show: true,
                              getDotPainter: (s, p, b, i) => FlDotCirclePainter(
                                radius: 4,
                                color: AppColors.primary,
                                strokeWidth: 2,
                                strokeColor: theme.colorScheme.surface,
                              ),
                            ),
                            belowBarData: BarAreaData(
                              show: true,
                              color: AppColors.primary.withValues(alpha: isDark ? 0.14 : 0.1),
                            ),
                          ),
                        ],
                      ),
                      duration: Duration.zero,
                    ),
            ),
            const SizedBox(height: 14),
            LayoutBuilder(
              builder: (context, c) {
                if (c.maxWidth < 520) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _rankedList(theme, l, analytics.topSelling),
                      const SizedBox(height: 12),
                      _lowStockList(theme, l, lowStock),
                    ],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _rankedList(theme, l, analytics.topSelling)),
                    const SizedBox(width: 14),
                    Expanded(child: _lowStockList(theme, l, lowStock)),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _miniStat(ThemeData theme, String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
        border: Border.all(color: outline.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: theme.textTheme.labelSmall?.copyWith(color: theme.hintColor)),
                Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _rankedList(ThemeData theme, AppLocalizations l, List<(String, int)> rows) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l.dashTopSellersTitle, style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        ...rows.take(5).map(
              (r) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Expanded(child: Text(r.$1, style: theme.textTheme.bodySmall)),
                    Text('${r.$2}', style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
            ),
      ],
    );
  }

  Widget _lowStockList(ThemeData theme, AppLocalizations l, List<Medicine> rows) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l.dashLowStockListTitle, style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        if (rows.isEmpty)
          Text(l.dashLowStockListAllOk, style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor))
        else
          ...rows.take(5).map(
                (m) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      Expanded(child: Text(m.name, style: theme.textTheme.bodySmall)),
                      Text('${m.quantity}', style: theme.textTheme.labelMedium?.copyWith(color: Colors.orange.shade800, fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
              ),
      ],
    );
  }
}

class _ChartShell extends StatelessWidget {
  const _ChartShell({required this.outline, required this.child});

  final Color outline;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: outline),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 12),
        child: child,
      ),
    );
  }
}

class _SalesLineChart extends StatelessWidget {
  const _SalesLineChart({
    required this.spots,
    required this.isDark,
    required this.title,
    this.subtitle,
  });

  final List<FlSpot> spots;
  final bool isDark;
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l = context.l10n;
    final textTheme = theme.textTheme;
    final muted = theme.hintColor;
    final grid = theme.colorScheme.outline.withValues(alpha: isDark ? 0.22 : 0.35);
    final maxYval = spots.isEmpty ? 1.0 : spots.map((s) => s.y).reduce((a, b) => a > b ? a : b);
    final maxYaxis = (maxYval <= 0 ? 1.0 : maxYval) * 1.15;
    final maxXaxis = spots.length <= 1 ? 1.0 : (spots.length - 1).toDouble();
    final sub = subtitle ??
        (spots.length <= 7 ? l.dashChartRecentPoints('${spots.length}') : l.dashChartTrendPoints('${spots.length}'));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 2),
        Text(sub, style: textTheme.labelSmall?.copyWith(color: muted)),
        const SizedBox(height: 12),
        SizedBox(
          height: 200,
          child: LineChart(
            LineChartData(
              minX: 0,
              maxX: maxXaxis,
              minY: 0,
              maxY: maxYaxis,
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: maxYaxis > 10 ? maxYaxis / 4 : null,
                getDrawingHorizontalLine: (v) => FlLine(color: grid, strokeWidth: 1),
              ),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 32,
                    interval: maxYaxis > 10 ? maxYaxis / 4 : 1,
                    getTitlesWidget: (v, m) => Text(
                      v >= 1000 ? '${(v / 1000).toStringAsFixed(1)}k' : v.toStringAsFixed(0),
                      style: textTheme.labelSmall?.copyWith(color: muted, fontSize: 10),
                    ),
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 28,
                    getTitlesWidget: (v, m) {
                      final i = v.toInt().clamp(0, spots.length - 1);
                      if (spots.isEmpty || i < 0) return const SizedBox.shrink();
                      final label =
                          spots.length == 7 ? ['M', 'T', 'W', 'T', 'F', 'S', 'S'][i % 7] : '${i + 1}';
                      return Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(label, style: textTheme.labelSmall?.copyWith(color: muted, fontWeight: FontWeight.w600)),
                      );
                    },
                  ),
                ),
              ),
              lineTouchData: LineTouchData(
                touchTooltipData: LineTouchTooltipData(
                  getTooltipColor: (_) => theme.colorScheme.inverseSurface,
                  getTooltipItems: (spots) => spots
                      .map(
                        (s) => LineTooltipItem(
                          s.y >= 1000 ? '${(s.y / 1000).toStringAsFixed(2)}k' : s.y.toStringAsFixed(2),
                          TextStyle(color: theme.colorScheme.onInverseSurface, fontWeight: FontWeight.w700, fontSize: 12),
                        ),
                      )
                      .toList(),
                ),
              ),
              lineBarsData: [
                LineChartBarData(
                  spots: spots,
                  isCurved: true,
                  curveSmoothness: 0.28,
                  color: AppColors.primary,
                  barWidth: 3,
                  isStrokeCapRound: true,
                  dotData: FlDotData(
                    show: true,
                    getDotPainter: (s, p, b, i) => FlDotCirclePainter(
                      radius: 4,
                      color: AppColors.primary,
                      strokeWidth: 2,
                      strokeColor: theme.colorScheme.surface,
                    ),
                  ),
                  belowBarData: BarAreaData(
                    show: true,
                    color: AppColors.primary.withValues(alpha: isDark ? 0.14 : 0.1),
                  ),
                ),
              ],
            ),
            duration: Duration.zero,
          ),
        ),
      ],
    );
  }
}

class _CategoryBarChart extends StatelessWidget {
  const _CategoryBarChart({required this.groups, required this.barLabels, required this.isDark});

  final List<BarChartGroupData> groups;
  final List<String> barLabels;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l = context.l10n;
    final textTheme = theme.textTheme;
    final muted = theme.hintColor;
    final grid = theme.colorScheme.outline.withValues(alpha: isDark ? 0.22 : 0.35);
    var maxRod = 1.0;
    for (final g in groups) {
      for (final r in g.barRods) {
        if (r.toY > maxRod) maxRod = r.toY;
      }
    }
    final maxYaxis = maxRod * 1.15;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l.dashTopSellersTitle, style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 2),
        Text(l.dashUnitsSoldSession, style: textTheme.labelSmall?.copyWith(color: muted)),
        const SizedBox(height: 12),
        SizedBox(
          height: 200,
          child: BarChart(
            BarChartData(
              maxY: maxYaxis,
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: maxYaxis > 10 ? maxYaxis / 4 : null,
                getDrawingHorizontalLine: (v) => FlLine(color: grid, strokeWidth: 1),
              ),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 40,
                    interval: maxYaxis > 10 ? maxYaxis / 4 : 1,
                    getTitlesWidget: (v, m) => Text(
                      v >= 1000 ? '${(v / 1000).toStringAsFixed(1)}k' : v.toStringAsFixed(0),
                      style: textTheme.labelSmall?.copyWith(color: muted, fontSize: 10),
                    ),
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 28,
                    getTitlesWidget: (v, m) {
                      final i = v.toInt();
                      if (i < 0 || i >= barLabels.length) return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          barLabels[i],
                          style: textTheme.labelSmall?.copyWith(color: muted, fontWeight: FontWeight.w600),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    },
                  ),
                ),
              ),
              barTouchData: BarTouchData(
                touchTooltipData: BarTouchTooltipData(
                  getTooltipColor: (_) => theme.colorScheme.inverseSurface,
                  getTooltipItem: (group, groupIndex, rod, rodIndex) => BarTooltipItem(
                    rod.toY.toStringAsFixed(1),
                    TextStyle(color: theme.colorScheme.onInverseSurface, fontWeight: FontWeight.w700, fontSize: 12),
                  ),
                ),
              ),
              barGroups: groups,
            ),
            duration: Duration.zero,
          ),
        ),
      ],
    );
  }
}

class _RecentRow extends StatefulWidget {
  const _RecentRow({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accent,
    required this.outline,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color accent;
  final Color outline;
  final VoidCallback onTap;

  @override
  State<_RecentRow> createState() => _RecentRowState();
}

class _RecentRowState extends State<_RecentRow> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;

    return Material(
      color: theme.colorScheme.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: widget.outline),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: widget.onTap,
        onHighlightChanged: (v) => setState(() => _pressed = v),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutCubic,
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: widget.accent.withValues(alpha: _pressed ? 0.2 : 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: Icon(widget.icon, color: widget.accent, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.subtitle,
                      style: textTheme.bodySmall?.copyWith(color: theme.hintColor),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: theme.hintColor.withValues(alpha: 0.65)),
            ],
          ),
        ),
      ),
    );
  }
}
