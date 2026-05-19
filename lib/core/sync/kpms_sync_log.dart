import 'package:flutter/foundation.dart';

/// Cloud sync diagnostics (search `[kpms.sync]`).
abstract final class KpmsSyncLog {
  static const String _p = '[kpms.sync]';

  static void _emit(String step, [String? detail]) {
    final tail = detail == null || detail.isEmpty ? '' : ' | $detail';
    debugPrint('$_p $step$tail');
  }

  static void uploadStarted({required String tenantId}) => _emit('upload_started', tenantId);

  static void uploadSuccess({required String tenantId}) => _emit('upload_success', tenantId);

  static void uploadCompleted({
    required String tenantId,
    int rows = 0,
    int medicines = 0,
  }) =>
      _emit('upload_completed', '$tenantId rows=$rows meds=$medicines');

  static void uploadFailed(String detail) => _emit('upload_failed', detail);

  static void queueRestored(int count) => _emit('queue_restored', 'count=$count');

  static void retryScheduled({
    required int id,
    required int nextAtMs,
    required int delayMs,
    required int attempt,
  }) =>
      _emit('retry_scheduled', 'id=$id delayMs=$delayMs attempt=$attempt nextAt=$nextAtMs');

  static void reconnectDetected() => _emit('reconnect_detected');

  static void replayCompleted({required int processed}) => _emit('replay_completed', 'processed=$processed');

  static void syncRetry(String reason) => _emit('sync_retry', reason);

  static void conflictDetected(String detail) => _emit('conflict_detected', detail);

  static void cloudRestoreCompleted({required String tenantId, required bool hasData}) =>
      _emit('cloud_restore_completed', '$tenantId hasData=$hasData');

  static void pullStarted(String tenantId) => _emit('pull_started', tenantId);

  static void pullCompleted(String tenantId) => _emit('pull_completed', tenantId);

  static void cloudPullCompleted({
    required String tenantId,
    required int medicines,
    required int sales,
    required int purchases,
    required bool cloudHas,
  }) =>
      _emit(
        'cloud_pull_completed',
        'tenant=$tenantId meds=$medicines sales=$sales purchases=$purchases cloudHas=$cloudHas',
      );

  static void cloudPullSkipped({required String tenantId, required String reason}) =>
      _emit('cloud_pull_skipped', 'tenant=$tenantId reason=$reason');

  static void workspaceMerged({
    required String direction,
    required int medicineCount,
    required int localOnlyMedicines,
  }) =>
      _emit('workspace_merged', '$direction meds=$medicineCount localOnly=$localOnlyMedicines');

  static void workspaceRefreshed({
    required String tenantId,
    required int medicines,
    required String source,
  }) =>
      _emit('workspace_refreshed', 'tenant=$tenantId meds=$medicines source=$source');

  static void outboxSynced({required String tenantId, required int processed}) =>
      _emit('outbox_synced', 'tenant=$tenantId processed=$processed');

  static void bootstrapGatedPush({required bool allowed, required String reason}) =>
      _emit('bootstrap_gated_push', 'allowed=$allowed reason=$reason');

  static void realtimeEvent(String table) => _emit('realtime_event', table);

  static void syncBannerHidden() => _emit('sync_banner_hidden');

  static void syncBannerRetrying() => _emit('sync_banner_retrying');

  static void syncCompleted() => _emit('sync_completed');

  static void medicineUpdated(String medicineClientId) => _emit('medicine_updated', medicineClientId);

  static void medicineDeleted(String medicineClientId) => _emit('medicine_deleted', medicineClientId);

  static void incrementalPullStarted({required String tenantId, required String since}) =>
      _emit('incremental_pull_started', 'tenant=$tenantId since=$since');

  static void incrementalPullCompleted({required String tenantId, required int rowDelta}) =>
      _emit('incremental_pull_completed', 'tenant=$tenantId rows=$rowDelta');

  static void syncLatency({required String label, required int ms}) =>
      _emit('sync_latency', '$label ${ms}ms');

  static void workspaceRestoreSource({
    required String tenantId,
    required String source,
    String? pullIso,
  }) =>
      _emit(
        'workspace_restore_source',
        'tenant=$tenantId source=$source${pullIso != null ? ' lastPull=$pullIso' : ''}',
      );

  static void ledgerMergeDecision({
    required String tenantId,
    required String entity,
    required int cloudCount,
    required int localCount,
    required int mergedCount,
    required int localOnly,
    required int cloudOnly,
    required int updated,
  }) =>
      _emit(
        'ledger_merge',
        'tenant=$tenantId entity=$entity cloud=$cloudCount local=$localCount merged=$mergedCount localOnly=$localOnly cloudOnly=$cloudOnly updated=$updated',
      );

  static void saleInsertLocal({
    required String tenantId,
    required String invoiceNumber,
    required double total,
  }) =>
      _emit('sale_insert_local', 'tenant=$tenantId invoice=$invoiceNumber total=$total');

  static void salePushAttempt({
    required String tenantId,
    required int invoiceCount,
    required int returnCount,
  }) =>
      _emit('sale_push_attempt', 'tenant=$tenantId invoices=$invoiceCount returns=$returnCount');

  static void salePushResult({
    required String tenantId,
    required bool success,
    int rows = 0,
    String? error,
  }) =>
      _emit(
        'sale_push_result',
        'tenant=$tenantId success=$success rows=$rows${error != null ? ' error=$error' : ''}',
      );

  static void bootstrapPullMode({
    required String tenantId,
    required String mode,
    String? sinceIso,
  }) =>
      _emit(
        'bootstrap_pull_mode',
        'tenant=$tenantId mode=$mode${sinceIso != null ? ' since=$sinceIso' : ''}',
      );

  static void workspaceFlush({required String tenantId, required String reason}) =>
      _emit('workspace_flush', 'tenant=$tenantId reason=$reason');
}
