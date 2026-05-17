import 'package:flutter/foundation.dart';

/// Diagnostics for tenant + local workspace persistence (search `[kpms.persistence]`).
abstract final class KpmsPersistenceLog {
  static const String _p = '[kpms.persistence]';

  static void _emit(String step, [String? detail]) {
    final tail = detail == null || detail.isEmpty ? '' : ' | $detail';
    debugPrint('$_p $step$tail');
  }

  static void tenantRestorationStarted() => _emit('tenant_restoration_started');

  static void tenantRestorationCompleted({String? tenantId}) =>
      _emit('tenant_restoration_completed', 'tenantId=${tenantId ?? "—"}');

  static void tenantRestorationTimeout() => _emit('tenant_restoration_timeout');

  static void settingsRestoreRetry(int attempt) => _emit('settings_restore_retry', 'attempt=$attempt');

  static void tenantQueryResult({required bool hasTenant, String? tenantId}) =>
      _emit('tenant_query_result', 'hasTenant=$hasTenant tenantId=${tenantId ?? "—"}');

  static void workspaceLoaded({required String tenantId, required bool hasData}) =>
      _emit('workspace_loaded', 'tenantId=$tenantId hasData=$hasData');

  static void workspaceEmpty({String? tenantId}) => _emit('workspace_empty', 'tenantId=${tenantId ?? "—"}');

  static void tenantContextInvalidated(String reason) => _emit('tenant_context_invalidated', reason);

  static void tenantSnapshotHydrated(String tenantId) => _emit('tenant_snapshot_hydrated', tenantId);

  static void skippedEmptyWorkspaceOverwrite(String tenantId) =>
      _emit('skipped_empty_workspace_overwrite', tenantId);

  static void emptyOverwriteBlocked(String tenantId) => _emit('empty_overwrite_blocked', tenantId);

  static void workspaceSaved({required String tenantId}) => _emit('workspace_saved', tenantId);

  static void workspaceRestored({required String tenantId, required bool hasData}) =>
      _emit('workspace_restored', 'tenantId=$tenantId hasData=$hasData');

  static void workspaceRecovered({required String tenantId, required String reason}) =>
      _emit('workspace_recovered', 'tenantId=$tenantId reason=$reason');
}
