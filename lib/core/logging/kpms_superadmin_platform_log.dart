import 'package:flutter/foundation.dart';

/// Platform operator diagnostics — search `[kpms.superadmin]` or `[kpms.platform]`.
abstract final class KpmsSuperadminLog {
  static const String _p = '[kpms.superadmin]';
  static void _e(String m) => debugPrint('$_p $m');

  static void pharmacySuspended({required String tenantId, String? detail}) =>
      _e('pharmacy_suspended tenant=$tenantId${detail == null ? '' : ' $detail'}');
  static void subscriptionUpdated({required String tenantId, String? detail}) =>
      _e('subscription_updated tenant=$tenantId${detail == null ? '' : ' $detail'}');
  static void featureFlagChanged({required String tenantId, required String key}) =>
      _e('feature_flag_changed tenant=$tenantId key=$key');
  static void forcedLogout({required String tenantId}) => _e('forced_logout tenant=$tenantId');
  static void announcementSent({String? detail}) => _e('announcement_sent${detail == null ? '' : ' $detail'}');
  static void suspiciousActivity({required String detail}) => _e('suspicious_activity $detail');
  static void tenantDisabled({required String tenantId, String? detail}) =>
      _e('tenant_disabled tenant=$tenantId${detail == null ? '' : ' $detail'}');
}

abstract final class KpmsPlatformLog {
  static const String _p = '[kpms.platform]';
  static void _e(String m) => debugPrint('$_p $m');

  static void healthChecked({required String source}) => _e('health_checked $source');
  static void auditExported({required int rows}) => _e('audit_exported rows=$rows');
  static void directoryLoaded({required int rows, String? detail}) =>
      _e('directory_loaded rows=$rows${detail == null ? '' : ' $detail'}');
}
