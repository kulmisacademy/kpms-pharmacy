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

  static void uploadCompleted({required String tenantId, int rows = 0}) =>
      _emit('upload_completed', '$tenantId rows=$rows');

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

  static void realtimeEvent(String table) => _emit('realtime_event', table);

  static void syncBannerHidden() => _emit('sync_banner_hidden');

  static void syncBannerRetrying() => _emit('sync_banner_retrying');

  static void syncCompleted() => _emit('sync_completed');

  static void medicineUpdated(String medicineClientId) => _emit('medicine_updated', medicineClientId);

  static void medicineDeleted(String medicineClientId) => _emit('medicine_deleted', medicineClientId);
}
