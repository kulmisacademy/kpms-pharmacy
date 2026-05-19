import 'package:flutter/foundation.dart';

/// Local persistence / outbox diagnostics — search `[kpms.persistence]`.
abstract final class KpmsPersistenceLog {
  static const String _p = '[kpms.persistence]';

  static void _emit(String step, [String? detail]) {
    final tail = detail == null || detail.isEmpty ? '' : ' | $detail';
    debugPrint('$_p $step$tail');
  }

  static void workspaceLoaded({required String tenantId, required int bytesEstimate}) =>
      _emit('workspace_loaded', 'tenant=$tenantId bytes~$bytesEstimate');

  static void workspaceSaved({required String tenantId}) => _emit('workspace_saved', 'tenant=$tenantId');

  static void outboxSize({required String tenantId, required int pending}) =>
      _emit('outbox_size', 'tenant=$tenantId pending=$pending');

  static void tenantBoundaryEnforced({required String from, required String to}) =>
      _emit('tenant_boundary', '$from → $to');

  static void lastPullRecorded({required String tenantId, required String iso}) =>
      _emit('last_pull_at', 'tenant=$tenantId at=$iso');
}
