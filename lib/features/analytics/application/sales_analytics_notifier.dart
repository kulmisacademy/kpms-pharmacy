import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/analytics/kpms_analytics_log.dart';
import '../../../core/performance/kpms_performance_log.dart';
import '../../../core/tenant/pharmacy_workspace_isolation.dart';
import '../../sales/application/sales_ledger_notifier.dart';
import '../../sales/domain/completed_sale_invoice.dart';

/// Sales analytics — session totals; must stay aligned with [salesLedgerProvider] per tenant.
final salesAnalyticsProvider =
    StateNotifierProvider<SalesAnalyticsNotifier, SalesAnalyticsState>((ref) {
  return SalesAnalyticsNotifier();
});

class SalesAnalyticsState {
  const SalesAnalyticsState({
    this.dailyTotal = 0,
    this.weeklyTotal = 0,
    this.monthlyTotal = 0,
    this.dailySeries = const [],
    this.weeklySeries = const [],
    this.monthlySeries = const [],
    this.topSelling = const [],
    this.totalProfitMonth = 0,
    this.derivedForTenantId,
  });

  final double dailyTotal;
  final double weeklyTotal;
  final double monthlyTotal;
  final List<double> dailySeries;
  final List<double> weeklySeries;
  final List<double> monthlySeries;
  final List<(String, int)> topSelling;
  final double totalProfitMonth;

  /// Last tenant this state was rebuilt for (cross-tenant safety).
  final String? derivedForTenantId;

  SalesAnalyticsState copyWith({
    double? dailyTotal,
    double? weeklyTotal,
    double? monthlyTotal,
    List<double>? dailySeries,
    List<double>? weeklySeries,
    List<double>? monthlySeries,
    List<(String, int)>? topSelling,
    double? totalProfitMonth,
    String? derivedForTenantId,
    bool clearTenantTag = false,
  }) {
    return SalesAnalyticsState(
      dailyTotal: dailyTotal ?? this.dailyTotal,
      weeklyTotal: weeklyTotal ?? this.weeklyTotal,
      monthlyTotal: monthlyTotal ?? this.monthlyTotal,
      dailySeries: dailySeries ?? this.dailySeries,
      weeklySeries: weeklySeries ?? this.weeklySeries,
      monthlySeries: monthlySeries ?? this.monthlySeries,
      topSelling: topSelling ?? this.topSelling,
      totalProfitMonth: totalProfitMonth ?? this.totalProfitMonth,
      derivedForTenantId:
          clearTenantTag ? null : (derivedForTenantId ?? this.derivedForTenantId),
    );
  }
}

class SalesAnalyticsNotifier extends StateNotifier<SalesAnalyticsState> {
  SalesAnalyticsNotifier() : super(const SalesAnalyticsState());

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  static bool _inSameWeek(DateTime d, DateTime now) {
    final d0 = _dateOnly(d);
    final n0 = _dateOnly(now);
    final weekStart = n0.subtract(Duration(days: n0.weekday - DateTime.monday));
    final weekEnd = weekStart.add(const Duration(days: 7));
    return !d0.isBefore(weekStart) && d0.isBefore(weekEnd);
  }

  static bool _inSameMonth(DateTime d, DateTime now) =>
      d.year == now.year && d.month == now.month;

  /// Wipe analytics memory (logout / tenant switch before new hydration).
  void reset() {
    state = const SalesAnalyticsState();
  }

  /// Apply incremental dashboard delta after a remote sale patch (avoids full rebuild).
  void applyRealtimeSale({
    required SalesLedgerState ledger,
    required CompletedSaleInvoice invoice,
    required String tenantId,
    required bool isNew,
  }) {
    final now = DateTime.now();
    final isToday = _dateOnly(invoice.issuedAt) == _dateOnly(now);

    if (!isNew || !isToday) {
      rebuildFromLedger(ledger, tenantId: tenantId);
      return;
    }

    var topName = '';
    var topQty = 0;
    for (final line in invoice.lines) {
      if (line.quantitySold > topQty) {
        topQty = line.quantitySold;
        topName = line.name;
      }
    }
    recordCheckout(
      revenue: invoice.total,
      profit: invoice.profitAtSale,
      topSkuName: topName.isEmpty ? null : topName,
      topSkuQty: topQty,
      tenantId: tenantId,
    );
  }

  void applyRealtimeReturn({
    required SalesReturnRecord record,
    required String tenantId,
  }) {
    recordReturn(
      refundRevenue: record.refundTotal,
      profitReduction: record.profitReduction,
      tenantId: tenantId,
    );
  }

  /// Recompute all KPIs from the canonical sales ledger for the current tenant.
  void rebuildFromLedger(SalesLedgerState ledger, {required String tenantId}) {
    final tid = tenantId.trim();
    if (tid.isEmpty) {
      KpmsAnalyticsLog.crossTenantBlocked('rebuildFromLedger empty tenantId');
      reset();
      return;
    }
    KpmsAnalyticsLog.activeTenant(tid, detail: 'rebuild_from_ledger');
    KpmsAnalyticsLog.analyticsCacheKey(KpmsTenantStorageKeys.salesMetrics(tid));

    final sw = Stopwatch()..start();
    final now = DateTime.now();
    final today = _dateOnly(now);

    var daily = 0.0;
    var weekly = 0.0;
    var monthly = 0.0;
    var profitMonth = 0.0;

    for (final inv in ledger.invoices) {
      final d = inv.issuedAt;
      if (_dateOnly(d) == today) daily += inv.total;
      if (_inSameWeek(d, now)) weekly += inv.total;
      if (_inSameMonth(d, now)) {
        monthly += inv.total;
        profitMonth += inv.profitAfterReturns;
      }
    }
    for (final r in ledger.returns) {
      final d = r.issuedAt;
      if (_dateOnly(d) == today) daily -= r.refundTotal;
      if (_inSameWeek(d, now)) weekly -= r.refundTotal;
      if (_inSameMonth(d, now)) {
        monthly -= r.refundTotal;
        profitMonth -= r.profitReduction;
      }
    }

    // Last 7 calendar days (oldest → newest) for trend chart.
    final dailySeries = List<double>.generate(7, (i) {
      final day = today.subtract(Duration(days: 6 - i));
      var sum = 0.0;
      for (final inv in ledger.invoices) {
        if (_dateOnly(inv.issuedAt) == day) sum += inv.total;
      }
      for (final ret in ledger.returns) {
        if (_dateOnly(ret.issuedAt) == day) sum -= ret.refundTotal;
      }
      return sum;
    });

    final thisMonday = today.subtract(Duration(days: today.weekday - DateTime.monday));
    final weeklySeries = List<double>.generate(8, (i) {
      final weekStart = thisMonday.subtract(Duration(days: 7 * (7 - i)));
      final weekEnd = weekStart.add(const Duration(days: 7));
      var sum = 0.0;
      for (final inv in ledger.invoices) {
        final d0 = _dateOnly(inv.issuedAt);
        if (!d0.isBefore(weekStart) && d0.isBefore(weekEnd)) sum += inv.total;
      }
      for (final ret in ledger.returns) {
        final d0 = _dateOnly(ret.issuedAt);
        if (!d0.isBefore(weekStart) && d0.isBefore(weekEnd)) sum -= ret.refundTotal;
      }
      return sum;
    });

    // Last 6 months, oldest first.
    final monthlySeries = <double>[];
    for (var back = 5; back >= 0; back--) {
      final anchor = DateTime(now.year, now.month - back, 1);
      var sum = 0.0;
      for (final inv in ledger.invoices) {
        if (inv.issuedAt.year == anchor.year && inv.issuedAt.month == anchor.month) {
          sum += inv.total;
        }
      }
      for (final ret in ledger.returns) {
        if (ret.issuedAt.year == anchor.year && ret.issuedAt.month == anchor.month) {
          sum -= ret.refundTotal;
        }
      }
      monthlySeries.add(sum);
    }

    final topMap = <String, int>{};
    for (final inv in ledger.invoices) {
      if (!_inSameMonth(inv.issuedAt, now)) continue;
      for (final line in inv.lines) {
        final net = line.quantitySold - line.quantityReturned;
        if (net <= 0) continue;
        final key = line.name.trim().isEmpty ? line.medicineId : line.name.trim();
        topMap[key] = (topMap[key] ?? 0) + net;
      }
    }
    final topSorted = topMap.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final topSelling = [for (final e in topSorted.take(10)) (e.key, e.value)];

    state = SalesAnalyticsState(
      dailyTotal: daily,
      weeklyTotal: weekly,
      monthlyTotal: monthly,
      dailySeries: dailySeries,
      weeklySeries: weeklySeries,
      monthlySeries: monthlySeries,
      topSelling: topSelling,
      totalProfitMonth: profitMonth,
      derivedForTenantId: tid,
    );

    sw.stop();
    if (sw.elapsedMilliseconds >= 500) {
      KpmsPerformanceLog.slowQuery(
        label: 'rebuildFromLedger',
        ms: sw.elapsedMilliseconds,
        detail: 'invoices=${ledger.invoices.length}',
      );
    }

    KpmsAnalyticsLog.salesSummaryLoaded(
      tenantId: tid,
      daily: daily,
      monthly: monthly,
      invoiceCount: ledger.invoices.length,
    );
    KpmsAnalyticsLog.dashboardLoaded(tid);
    KpmsAnalyticsLog.tenantAnalyticsVerified(tid);
  }

  /// Called after POS checkout — updates in-memory totals until persisted via repository.
  void recordCheckout({
    required double revenue,
    required double profit,
    String? topSkuName,
    int topSkuQty = 1,
    String? tenantId,
  }) {
    final tid = tenantId?.trim();
    if (tid != null && tid.isNotEmpty && state.derivedForTenantId != null && state.derivedForTenantId != tid) {
      KpmsAnalyticsLog.crossTenantBlocked('recordCheckout tenant $tid != derived ${state.derivedForTenantId}');
      return;
    }
    final s = state;
    final nextTop = _mergeTopSelling(s.topSelling, topSkuName, topSkuQty);
    state = s.copyWith(
      dailyTotal: s.dailyTotal + revenue,
      weeklyTotal: s.weeklyTotal + revenue,
      monthlyTotal: s.monthlyTotal + revenue,
      totalProfitMonth: s.totalProfitMonth + profit,
      topSelling: nextTop,
    );
  }

  /// Reverses revenue and profit impact from a sales return.
  void recordReturn({
    required double refundRevenue,
    required double profitReduction,
    String? tenantId,
  }) {
    final tid = tenantId?.trim();
    if (tid != null && tid.isNotEmpty && state.derivedForTenantId != null && state.derivedForTenantId != tid) {
      KpmsAnalyticsLog.crossTenantBlocked('recordReturn tenant $tid != derived ${state.derivedForTenantId}');
      return;
    }
    final s = state;
    state = s.copyWith(
      dailyTotal: s.dailyTotal - refundRevenue,
      weeklyTotal: s.weeklyTotal - refundRevenue,
      monthlyTotal: s.monthlyTotal - refundRevenue,
      totalProfitMonth: s.totalProfitMonth - profitReduction,
    );
  }

  List<(String, int)> _mergeTopSelling(List<(String, int)> cur, String? name, int qty) {
    if (qty <= 0) return cur;
    if (name == null || name.trim().isEmpty) return cur;
    final key = name.trim();
    final map = <String, int>{for (final t in cur) t.$1: t.$2};
    map[key] = (map[key] ?? 0) + qty;
    final sorted = map.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return [for (final e in sorted.take(10)) (e.key, e.value)];
  }
}
