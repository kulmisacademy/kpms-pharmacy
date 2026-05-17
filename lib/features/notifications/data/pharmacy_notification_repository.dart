import '../../../core/notifications/kpms_notification_log.dart';
import '../../../core/performance/kpms_performance_log.dart';
import '../../../core/supabase/supabase_bootstrap.dart';
import '../domain/pharmacy_notification_models.dart';

/// Supabase-backed notification feed (RLS + tenant_id on every call path).
/// Maps to existing `pharmacy_notifications` (client_id = dedupe key, severity ~ priority).
abstract final class PharmacyNotificationRepository {
  PharmacyNotificationRepository._();

  static const _table = 'pharmacy_notifications';
  static const _reads = 'pharmacy_notification_reads';
  static const _tokens = 'pharmacy_push_tokens';

  static String _toSeverity(String priority) => switch (priority) {
        'critical' => 'critical',
        'high' => 'warning',
        'low' => 'info',
        _ => 'info',
      };

  static String _toPriority(String severity) => switch (severity) {
        'critical' || 'error' => 'critical',
        'warning' => 'high',
        'info' => 'normal',
        _ => 'normal',
      };

  static Future<List<PharmacyNotificationItem>> fetchWithReadState({
    required String tenantId,
    required String userId,
    int limit = 100,
    int offset = 0,
  }) async {
    final c = SupabaseBootstrap.clientOrNull;
    if (c == null) return const [];

    final from = offset.clamp(0, 1 << 30);
    final to = from + limit - 1;
    final rows = await c
        .from(_table)
        .select()
        .eq('tenant_id', tenantId)
        .order('created_at', ascending: false)
        .range(from, to);

    final list = (rows as List<dynamic>).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    KpmsPerformanceLog.paginationLoaded(table: _table, count: list.length, offset: from);
    if (list.isEmpty) return const [];

    final ids = [for (final row in list) '${row['id']}'];
    final readRows =
        await c.from(_reads).select().eq('user_id', userId).inFilter('notification_id', ids);
    final readMap = <String, DateTime>{};
    for (final r in readRows as List<dynamic>) {
      final m = Map<String, dynamic>.from(r as Map);
      final nid = '${m['notification_id']}';
      final ra = DateTime.tryParse('${m['read_at']}');
      if (ra != null) readMap[nid] = ra;
    }

    return [
      for (final row in list)
        PharmacyNotificationItem.fromRow(
          row,
          readAt: readMap['${row['id']}'],
          priorityFromSeverity: _toPriority('${row['severity'] ?? 'info'}'),
        ),
    ];
  }

  /// Total unread for current tenant + auth user (RLS + `kpms_my_tenant_id`). Requires migration `phase_f_notification_feed_rpcs`.
  static Future<int> unreadCount() async {
    final c = SupabaseBootstrap.clientOrNull;
    if (c == null) return 0;
    try {
      final raw = await c.rpc('kpms_notification_unread_count');
      if (raw == null) return 0;
      return (raw as num).toInt();
    } catch (e) {
      KpmsNotificationLog.pushFailed('unreadCount $e');
      return 0;
    }
  }

  static Future<int> markAllReadForTenant() async {
    final c = SupabaseBootstrap.clientOrNull;
    if (c == null) return 0;
    try {
      final raw = await c.rpc('kpms_notification_mark_all_read');
      if (raw == null) return 0;
      return (raw as num).toInt();
    } catch (e) {
      KpmsNotificationLog.pushFailed('markAllReadForTenant $e');
      rethrow;
    }
  }

  static Future<void> upsertOperational({
    required String tenantId,
    required String userId,
    required String kind,
    required String title,
    required String body,
    required String dedupeKey,
    required String priority,
    Map<String, dynamic>? payload,
  }) async {
    final c = SupabaseBootstrap.clientOrNull;
    if (c == null) return;

    final meta = <String, dynamic>{
      ...?payload,
      'kpms_kind': kind,
      'source': 'kpms_operational_engine',
      'source_user_id': userId,
    };

    try {
      await c.from(_table).upsert(
        {
          'tenant_id': tenantId,
          'client_id': dedupeKey,
          'title': title,
          'body': body,
          'severity': _toSeverity(priority),
          'kind': kind,
          'metadata': meta,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        },
        onConflict: 'tenant_id,client_id',
      );
      KpmsNotificationLog.notificationCreated(kind: kind, tenantId: tenantId, dedupe: dedupeKey);
    } catch (e) {
      KpmsNotificationLog.pushFailed('upsertOperational $e');
    }
  }

  static Future<void> markRead({
    required String notificationId,
    required String userId,
  }) async {
    final c = SupabaseBootstrap.clientOrNull;
    if (c == null) return;
    try {
      await c.from(_reads).upsert(
        {
          'notification_id': notificationId,
          'user_id': userId,
          'read_at': DateTime.now().toUtc().toIso8601String(),
        },
        onConflict: 'notification_id,user_id',
      );
      KpmsNotificationLog.notificationRead(id: notificationId);
    } catch (e) {
      KpmsNotificationLog.pushFailed('markRead $e');
    }
  }

  static Future<void> registerPushToken({
    required String tenantId,
    required String userId,
    required String token,
    String platform = 'android',
  }) async {
    final c = SupabaseBootstrap.clientOrNull;
    if (c == null) return;
    try {
      await c.from(_tokens).upsert(
        {
          'tenant_id': tenantId,
          'user_id': userId,
          'token': token,
          'platform': platform,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        },
        onConflict: 'user_id,token',
      );
      final tail = token.length > 8 ? token.substring(token.length - 8) : token;
      KpmsNotificationLog.pushSent(tokenTail: tail);
    } catch (e) {
      KpmsNotificationLog.pushFailed('registerPushToken $e');
    }
  }
}
