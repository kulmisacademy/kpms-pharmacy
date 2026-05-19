import 'package:flutter/foundation.dart';

/// Supabase realtime diagnostics (search `[kpms.realtime]`).
abstract final class KpmsRealtimeLog {
  static const String _p = '[kpms.realtime]';

  static void _emit(String step, [String? detail]) {
    final tail = detail == null || detail.isEmpty ? '' : ' | $detail';
    debugPrint('$_p $step$tail');
  }

  static void subscribed({required String tenantId, required int tableCount}) =>
      _emit('subscribed', 'tenant=$tenantId tables=$tableCount');

  static void realtimeReceived({required String table, required String tenantId}) =>
      _emit('realtime_received', 'table=$table tenant=$tenantId');

  static void workspaceRefreshScheduled({required String tenantId, required String triggerTable}) =>
      _emit('workspace_refresh_scheduled', 'tenant=$tenantId table=$triggerTable');

  static void unsubscribed({required String tenantId}) => _emit('unsubscribed', 'tenant=$tenantId');

  static void activeListeners({required int count}) => _emit('active_listeners', 'count=$count');
}
