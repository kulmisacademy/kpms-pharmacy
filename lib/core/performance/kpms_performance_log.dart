import 'package:flutter/foundation.dart';

/// Performance / scalability diagnostics — search `[kpms.performance]`.
abstract final class KpmsPerformanceLog {
  static const String _p = '[kpms.performance]';

  static void _emit(String step, [String? detail]) {
    final tail = detail == null || detail.isEmpty ? '' : ' | $detail';
    debugPrint('$_p $step$tail');
  }

  static void slowQuery({required String label, required int ms, String? detail}) =>
      _emit('slow_query', '$label ${ms}ms${detail == null ? '' : ' $detail'}');

  static void rebuildSkipped({required String component, String? reason}) =>
      _emit('rebuild_skipped', '$component${reason == null ? '' : ' $reason'}');

  static void cacheHit({required String key}) => _emit('cache_hit', key);

  static void paginationLoaded({required String table, required int count, int offset = 0}) =>
      _emit('pagination_loaded', '$table count=$count offset=$offset');

  static void analyticsSnapshotUsed({required String source}) => _emit('analytics_snapshot_used', source);

  static void realtimeBatched({required String channel, required int debounceMs}) =>
      _emit('realtime_batched', '$channel debounce=${debounceMs}ms');

  static void startupCompleted({required int ms}) => _emit('startup_completed', '${ms}ms');

  static void pullCompleted({required String label, required int ms, required int rowEstimate}) =>
      _emit('pull_completed', '$label ${ms}ms rows~$rowEstimate');
}
