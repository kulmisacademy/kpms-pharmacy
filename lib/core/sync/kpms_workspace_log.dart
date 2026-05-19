import 'package:flutter/foundation.dart';

/// In-memory workspace patch diagnostics (search `[kpms.workspace]`).
abstract final class KpmsWorkspaceLog {
  static const String _p = '[kpms.workspace]';

  static void _emit(String step, [String? detail]) {
    final tail = detail == null || detail.isEmpty ? '' : ' | $detail';
    debugPrint('$_p $step$tail');
  }

  static void patchStarted({required String tenantId, required String table, required String op}) =>
      _emit('patch_started', 'tenant=$tenantId table=$table op=$op');

  static void patchApplied({required String tenantId, required String entity, required String clientId}) =>
      _emit('patch_applied', 'tenant=$tenantId entity=$entity id=$clientId');

  static void patchPersisted({required String tenantId}) => _emit('patch_persisted', 'tenant=$tenantId');

  static void providerUpdated({required String provider, required String detail}) =>
      _emit('provider_updated', '$provider $detail');

  static void reconcileCompleted({required String tenantId, required int patches}) =>
      _emit('reconcile_completed', 'tenant=$tenantId patches=$patches');

  static void patchSkipped({required String reason, String? detail}) =>
      _emit('patch_skipped', '$reason${detail == null ? '' : ' $detail'}');
}
