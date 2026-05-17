import 'package:flutter/foundation.dart';

/// Multi-tenant isolation diagnostics (search `[kpms.tenant]`).
abstract final class KpmsTenantLog {
  static const String _p = '[kpms.tenant]';

  static void _emit(String step, [String? detail]) {
    final tail = detail == null || detail.isEmpty ? '' : ' | $detail';
    debugPrint('$_p $step$tail');
  }

  static void activeTenant(String tenantId, {String? userId}) =>
      _emit('active_tenant', 'tenantId=$tenantId userId=${userId ?? "—"}');

  static void workspaceLoaded(String tenantId) => _emit('workspace_loaded', tenantId);

  static void workspaceCleared({String? reason}) => _emit('workspace_cleared', reason);

  static void tenantStorageKey(String key) => _emit('tenant_storage_key', key);

  static void tenantCacheReset({String? from, String? to}) =>
      _emit('tenant_cache_reset', 'from=${from ?? "—"} to=${to ?? "—"}');

  static void crossTenantProtection(String detail) => _emit('cross_tenant_protection', detail);
}
