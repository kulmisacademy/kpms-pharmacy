import 'package:flutter/foundation.dart';

/// Dashboard / sales analytics diagnostics — search `[kpms.analytics]`.
abstract final class KpmsAnalyticsLog {
  static const String _p = '[kpms.analytics]';

  static void _emit(String step, [String? detail]) {
    final tail = detail == null || detail.isEmpty ? '' : ' | $detail';
    debugPrint('$_p $step$tail');
  }

  static void activeTenant(String tenantId, {String? detail}) =>
      _emit('active_tenant', 'tenantId=$tenantId${detail == null ? "" : " $detail"}');

  static void dashboardLoaded(String tenantId) => _emit('dashboard_loaded', tenantId);

  static void analyticsCacheKey(String key) => _emit('analytics_cache_key', key);

  static void salesSummaryLoaded({
    required String tenantId,
    required double daily,
    required double monthly,
    int invoiceCount = 0,
  }) =>
      _emit(
        'sales_summary_loaded',
        'tenantId=$tenantId invoices=$invoiceCount daily=${daily.toStringAsFixed(2)} monthly=${monthly.toStringAsFixed(2)}',
      );

  static void tenantAnalyticsVerified(String tenantId) => _emit('tenant_analytics_verified', tenantId);

  static void crossTenantBlocked(String detail) => _emit('cross_tenant_blocked', detail);

  /// Report dataset successfully materialized for UI / export (tenant-scoped aggregates).
  static void analyticsLoaded({required String tenantId, required String reportSlug}) =>
      _emit('analytics_loaded', 'tenantId=$tenantId slug=$reportSlug');

  /// Reporting path validated active workspace tenant against analytics cache tag.
  static void tenantReportVerified(String tenantId) => _emit('tenant_report_verified', tenantId);
}

