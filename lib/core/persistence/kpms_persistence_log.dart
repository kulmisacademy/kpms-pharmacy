import 'package:flutter/foundation.dart';

/// Local persistence / outbox diagnostics — search `[kpms.persistence]`.
abstract final class KpmsPersistenceLog {
  static const String _p = '[kpms.persistence]';

  static void _emit(String step, [String? detail]) {
    final tail = detail == null || detail.isEmpty ? '' : ' | $detail';
    debugPrint('$_p $step$tail');
  }

  static void tenantRestorationStarted() => _emit('tenant_restoration_started');

  static void tenantRestorationCompleted({required String tenantId}) =>
      _emit('tenant_restoration_completed', 'tenant=$tenantId');

  static void tenantRestorationTimeout() => _emit('tenant_restoration_timeout');

  static void tenantQueryResult({required bool hasTenant, String? tenantId}) =>
      _emit('tenant_query_result', 'hasTenant=$hasTenant${tenantId == null ? '' : ' tenant=$tenantId'}');

  static void tenantSnapshotHydrated(String tenantId) =>
      _emit('tenant_snapshot_hydrated', 'tenant=$tenantId');

  static void workspaceLoaded({required String tenantId, bool? hasData, int? bytesEstimate}) {
    final parts = <String>['tenant=$tenantId'];
    if (hasData != null) parts.add('hasData=$hasData');
    if (bytesEstimate != null) parts.add('bytes~$bytesEstimate');
    _emit('workspace_loaded', parts.join(' '));
  }

  static void workspaceEmpty({required String tenantId}) => _emit('workspace_empty', 'tenant=$tenantId');

  static void workspaceSaved({required String tenantId}) => _emit('workspace_saved', 'tenant=$tenantId');

  static void workspaceRecovered({required String tenantId, required String reason}) =>
      _emit('workspace_recovered', 'tenant=$tenantId reason=$reason');

  static void skippedEmptyWorkspaceOverwrite(String tenantId) =>
      _emit('skipped_empty_workspace_overwrite', 'tenant=$tenantId');

  static void emptyOverwriteBlocked(String tenantId) => _emit('empty_overwrite_blocked', 'tenant=$tenantId');

  static void outboxSize({required String tenantId, required int pending}) =>
      _emit('outbox_size', 'tenant=$tenantId pending=$pending');

  static void tenantBoundaryEnforced({required String from, required String to}) =>
      _emit('tenant_boundary', '$from → $to');

  static void realtimePatchSaved({required String tenantId}) =>
      _emit('realtime_patch_saved', 'tenant=$tenantId');

  static void lastPullRecorded({required String tenantId, required String iso}) =>
      _emit('last_pull_at', 'tenant=$tenantId at=$iso');
}
