import 'package:flutter/foundation.dart';

/// Notification / push diagnostics — search `[kpms.notifications]`.
abstract final class KpmsNotificationLog {
  static const String _p = '[kpms.notifications]';

  static void _emit(String step, [String? detail]) {
    final tail = detail == null || detail.isEmpty ? '' : ' | $detail';
    debugPrint('$_p $step$tail');
  }

  static void notificationCreated({required String kind, required String tenantId, String? dedupe}) =>
      _emit('notification_created', 'kind=$kind tenantId=$tenantId${dedupe == null ? '' : ' dedupe=$dedupe'}');

  static void notificationReceived({required String source, required String id}) =>
      _emit('notification_received', '$source id=$id');

  static void notificationRead({required String id}) => _emit('notification_read', 'id=$id');

  static void pushSent({required String tokenTail}) => _emit('push_sent', 'token…$tokenTail');

  static void pushFailed(String detail) => _emit('push_failed', detail);

  static void realtimeReceived({required String table}) => _emit('realtime_received', table);
}
