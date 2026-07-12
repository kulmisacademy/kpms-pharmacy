import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/permission_providers.dart';
import '../../../core/constants/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../pharmacy_cloud/application/pharmacy_cloud_providers.dart';
import '../../debts/application/debt_customers_notifier.dart';
import '../../debts/application/supplier_payments_notifier.dart';
import '../../medicines/application/medicine_catalog_insights_provider.dart';
import '../../purchases/application/purchase_ledger_notifier.dart';
import '../../sales/application/sales_ledger_notifier.dart';
import '../../suppliers/application/suppliers_notifier.dart';
import '../../analytics/application/sales_analytics_notifier.dart';

/// Recent activity row kind — UI maps to localized titles/subtitles.
enum DashboardActivityKind { sale, purchase, supplierPayment }

typedef DashboardActivityEntry = ({
  DateTime at,
  DashboardActivityKind kind,
  String refId,
  String detail,
  double? amount,
  String route,
});
/// Bootstrap gate for dashboard skeleton (matches POS/medicines pattern).
final dashboardBootstrapReadyProvider = Provider<bool>((ref) {
  return ref.watch(pharmacyWorkspaceBootstrapReadyProvider);
});

/// KPI analytics slice — rebuilds only when analytics totals change.
final dashboardAnalyticsKpiProvider = Provider<({
  double dailyTotal,
  double weeklyTotal,
  double monthlyTotal,
  double totalProfitMonth,
})>((ref) {
  final a = ref.watch(salesAnalyticsProvider);
  return (
    dailyTotal: a.dailyTotal,
    weeklyTotal: a.weeklyTotal,
    monthlyTotal: a.monthlyTotal,
    totalProfitMonth: a.totalProfitMonth,
  );
});

/// Debt totals derived from ledgers — single recompute point for dashboard + debts hub.
final dashboardDebtSummaryProvider = Provider<({
  double customerDebtTotal,
  double supplierDebtTotal,
  int customerCount,
  int supplierCount,
})>((ref) {
  ref.watch(salesLedgerProvider);
  final ledger = ref.read(salesLedgerProvider.notifier);
  final customers = ref.watch(debtCustomersProvider);
  final suppliers = ref.watch(suppliersProvider);
  var customerDebt = 0.0;
  for (final c in customers) {
    customerDebt += ledger.openDebtTotalForCustomer(c.id);
  }
  final supplierDebt = suppliers.fold(0.0, (s, x) => s + x.balanceOwed);
  return (
    customerDebtTotal: customerDebt,
    supplierDebtTotal: supplierDebt,
    customerCount: customers.length,
    supplierCount: suppliers.length,
  );
});

/// Catalog insights for dashboard KPIs (low stock, expiring) without full catalog rescans.
final dashboardCatalogInsightsProvider = Provider<({int lowStockCount, int expiringSoonCount})>((ref) {
  final insights = ref.watch(medicineCatalogInsightsProvider);
  return (lowStockCount: insights.lowStock, expiringSoonCount: insights.expiringSoon);
});

/// Financial metrics permission flag — narrow watch.
final dashboardCanViewFinancialProvider = Provider<bool>((ref) {
  return ref.watch(kpmsCanViewFinancialMetricsProvider);
});

/// Precomputed chart series — keeps [FlSpot] / bar math out of widget build.
final dashboardChartDataProvider = Provider<({
  List<FlSpot> salesSpots,
  List<FlSpot> monthlySpots,
  List<BarChartGroupData> barGroups,
  List<String> barLabels,
  bool showPerfCharts,
})>((ref) {
  final analytics = ref.watch(salesAnalyticsProvider);
  final canFin = ref.watch(dashboardCanViewFinancialProvider);

  final salesSpotsRaw = analytics.dailySeries.isNotEmpty
      ? [
          for (var i = 0; i < analytics.dailySeries.length; i++)
            FlSpot(i.toDouble(), analytics.dailySeries[i]),
        ]
      : (analytics.dailyTotal > 0.009 ? [FlSpot(0, analytics.dailyTotal)] : <FlSpot>[]);
  final salesSpots = canFin ? salesSpotsRaw : <FlSpot>[];

  final monthlySpotsRaw = analytics.monthlySeries.isNotEmpty
      ? [
          for (var i = 0; i < analytics.monthlySeries.length; i++)
            FlSpot(i.toDouble(), analytics.monthlySeries[i]),
        ]
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
      analytics.topSelling[i].$1.length > 12
          ? '${analytics.topSelling[i].$1.substring(0, 11)}…'
          : analytics.topSelling[i].$1,
  ];

  return (
    salesSpots: salesSpots,
    monthlySpots: monthlySpots,
    barGroups: barGroups,
    barLabels: barLabels,
    showPerfCharts: salesSpots.isNotEmpty || barGroups.isNotEmpty,
  );
});

/// Merged recent activity feed (sales, purchases, supplier payments) — top 12 by date.
final dashboardRecentActivityProvider = Provider<List<DashboardActivityEntry>>((ref) {
  ref.watch(salesLedgerProvider);
  ref.watch(purchaseLedgerProvider);
  ref.watch(supplierPaymentsProvider);
  final salesLedger = ref.read(salesLedgerProvider);
  final purchaseLedger = ref.read(purchaseLedgerProvider);
  final supPay = ref.read(supplierPaymentsProvider);

  final items = <DashboardActivityEntry>[];
  for (final inv in salesLedger.invoices.take(40)) {
    items.add((
      at: inv.issuedAt,
      kind: DashboardActivityKind.sale,
      refId: inv.invoiceNumber,
      detail: inv.paymentMethod,
      amount: inv.total,
      route: AppRoutes.pos,
    ));
  }
  for (final p in purchaseLedger.invoices.take(40)) {
    items.add((
      at: p.issuedAt,
      kind: DashboardActivityKind.purchase,
      refId: p.invoiceNumber,
      detail: p.supplierName,
      amount: null,
      route: AppRoutes.purchases,
    ));
  }
  for (final pay in supPay.take(30)) {
    items.add((
      at: pay.paidAt,
      kind: DashboardActivityKind.supplierPayment,
      refId: pay.supplierId,
      detail: pay.supplierId,
      amount: pay.amount,
      route: '${AppRoutes.supplierFinance}/${pay.supplierId}',
    ));
  }
  items.sort((a, b) => b.at.compareTo(a.at));
  return items.take(12).toList(growable: false);
});
