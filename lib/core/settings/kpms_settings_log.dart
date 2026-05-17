import 'package:flutter/foundation.dart';

/// Diagnostics for pharmacy settings / tenant resolution (search `[kpms.settings]`).
abstract final class KpmsSettingsLog {
  static const String _p = '[kpms.settings]';

  static void _emit(String step, [String? detail]) {
    final tail = detail == null || detail.isEmpty ? '' : ' | $detail';
    debugPrint('$_p $step$tail');
  }

  static void settingsOpened() => _emit('settings_opened');

  static void tenantContextLoaded() => _emit('tenant_context_loaded');

  static void profileQueryStarted() => _emit('profile_query_started');

  static void profileQueryResult({
    required bool hasTenant,
    String? tenantId,
    bool tenantRow = true,
  }) =>
      _emit(
        'profile_query_result',
        'hasTenant=$hasTenant tenantId=${tenantId ?? "—"} tenantRow=$tenantRow',
      );

  static void tenantRestored() => _emit('tenant_restored');

  static void missingTenantUiShown() => _emit('missing_tenant_ui_shown');
}
