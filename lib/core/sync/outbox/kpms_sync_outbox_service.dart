import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../kpms_sync_log.dart';
import 'kpms_sync_outbox_db.dart';
import 'kpms_sync_outbox_models.dart';

/// Durable SQLite-backed sync queue. Rows are strictly [tenant_id]-scoped.
abstract final class KpmsSyncOutboxService {
  KpmsSyncOutboxService._();

  static const int _maxAutoRetries = 25;

  static int backoffDelayMs(int retryCount) {
    const steps = [5000, 15000, 30000, 60000, 120000, 180000, 240000, 300000];
    return steps[retryCount.clamp(0, steps.length - 1)];
  }

  static Future<Database> _db() => KpmsSyncOutboxDb.instance;

  /// Coalesce: one pending row per (tenant, entity_type) for bulk sync kinds.
  static Future<void> _coalescePending(String tenantId, String entityType) async {
    final db = await _db();
    await db.delete(
      'kpms_sync_outbox',
      where: 'tenant_id = ? AND entity_type = ? AND sync_status = ?',
      whereArgs: [tenantId, entityType, KpmsSyncQueueStatus.pending],
    );
  }

  static Future<int> enqueue({
    required String tenantId,
    required String entityType,
    required String operationType,
    Map<String, dynamic>? payload,
    bool coalesce = true,
  }) async {
    final tid = tenantId.trim();
    if (tid.isEmpty) return 0;

    final db = await _db();
    if (coalesce && (entityType == KpmsSyncEntityType.workspace || entityType == KpmsSyncEntityType.enterprise)) {
      await _coalescePending(tid, entityType);
    }

    final now = DateTime.now().millisecondsSinceEpoch;
    final id = await db.insert('kpms_sync_outbox', {
      'tenant_id': tid,
      'entity_type': entityType,
      'operation_type': operationType,
      'payload_json': jsonEncode(payload ?? const <String, dynamic>{}),
      'created_at': now,
      'retry_count': 0,
      'last_error': null,
      'sync_status': KpmsSyncQueueStatus.pending,
      'next_retry_at': now,
    });
    KpmsSyncLog.syncRetry('enqueued entity=$entityType op=$operationType id=$id');
    return id;
  }

  static Future<List<KpmsSyncOutboxRow>> dueForTenant(String tenantId, {int limit = 8}) async {
    final tid = tenantId.trim();
    if (tid.isEmpty) return const [];

    final db = await _db();
    final now = DateTime.now().millisecondsSinceEpoch;
    final maps = await db.query(
      'kpms_sync_outbox',
      where: 'tenant_id = ? AND sync_status = ? AND next_retry_at <= ?',
      whereArgs: [tid, KpmsSyncQueueStatus.pending, now],
      orderBy: 'created_at ASC',
      limit: limit,
    );
    return maps.map(KpmsSyncOutboxRow.fromMap).toList(growable: false);
  }

  static Future<int> pendingCountForTenant(String tenantId) async {
    final tid = tenantId.trim();
    if (tid.isEmpty) return 0;
    final db = await _db();
    final r = await db.rawQuery(
      'SELECT COUNT(*) as c FROM kpms_sync_outbox WHERE tenant_id = ? AND sync_status = ?',
      [tid, KpmsSyncQueueStatus.pending],
    );
    return (r.first['c'] as num?)?.toInt() ?? 0;
  }

  static Future<int> failedCountForTenant(String tenantId) async {
    final tid = tenantId.trim();
    if (tid.isEmpty) return 0;
    final db = await _db();
    final r = await db.rawQuery(
      'SELECT COUNT(*) as c FROM kpms_sync_outbox WHERE tenant_id = ? AND sync_status = ?',
      [tid, KpmsSyncQueueStatus.failed],
    );
    return (r.first['c'] as num?)?.toInt() ?? 0;
  }

  static Future<void> deleteRow(int id) async {
    final db = await _db();
    await db.delete('kpms_sync_outbox', where: 'id = ?', whereArgs: [id]);
  }

  static Future<void> scheduleRetry(int id, String error) async {
    final db = await _db();
    final rows = await db.query('kpms_sync_outbox', where: 'id = ?', whereArgs: [id], limit: 1);
    if (rows.isEmpty) return;

    final cur = (rows.first['retry_count'] as num?)?.toInt() ?? 0;
    final nextCount = cur + 1;
    final delay = backoffDelayMs(cur);
    final nextAt = DateTime.now().millisecondsSinceEpoch + delay;

    if (nextCount >= _maxAutoRetries) {
      await db.update(
        'kpms_sync_outbox',
        {
          'sync_status': KpmsSyncQueueStatus.failed,
          'retry_count': nextCount,
          'last_error': error.length > 2000 ? error.substring(0, 2000) : error,
          'next_retry_at': nextAt,
        },
        where: 'id = ?',
        whereArgs: [id],
      );
      KpmsSyncLog.uploadFailed('id=$id retries_exhausted $error');
      return;
    }

    await db.update(
      'kpms_sync_outbox',
      {
        'sync_status': KpmsSyncQueueStatus.pending,
        'retry_count': nextCount,
        'last_error': error.length > 2000 ? error.substring(0, 2000) : error,
        'next_retry_at': nextAt,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
    KpmsSyncLog.retryScheduled(id: id, nextAtMs: nextAt, delayMs: delay, attempt: nextCount);
  }

  /// After successful cloud push, drop redundant pending bulk jobs for tenant.
  static Future<void> clearPendingBulkForTenant(String tenantId, {required String entityType}) async {
    final tid = tenantId.trim();
    if (tid.isEmpty) return;
    final db = await _db();
    await db.delete(
      'kpms_sync_outbox',
      where: 'tenant_id = ? AND entity_type = ? AND sync_status = ?',
      whereArgs: [tid, entityType, KpmsSyncQueueStatus.pending],
    );
  }

  /// Restore diagnostics — count all non-deleted rows for tenant (any status).
  static Future<int> totalRowsForTenant(String tenantId) async {
    final tid = tenantId.trim();
    if (tid.isEmpty) return 0;
    final db = await _db();
    final r = await db.rawQuery(
      'SELECT COUNT(*) as c FROM kpms_sync_outbox WHERE tenant_id = ?',
      [tid],
    );
    return (r.first['c'] as num?)?.toInt() ?? 0;
  }

  static Future<bool> hasPendingRetriesForTenant(String tenantId) async {
    final tid = tenantId.trim();
    if (tid.isEmpty) return false;
    final db = await _db();
    final r = await db.rawQuery(
      'SELECT COUNT(*) as c FROM kpms_sync_outbox WHERE tenant_id = ? AND sync_status = ? AND retry_count > 0',
      [tid, KpmsSyncQueueStatus.pending],
    );
    return ((r.first['c'] as num?)?.toInt() ?? 0) > 0;
  }

  /// Optional: drop failed rows for tenant (e.g. after support fix). Not exposed in UI yet.
  static Future<void> resetFailedForTenant(String tenantId) async {
    final tid = tenantId.trim();
    if (tid.isEmpty) return;
    final db = await _db();
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.update(
      'kpms_sync_outbox',
      {
        'sync_status': KpmsSyncQueueStatus.pending,
        'retry_count': 0,
        'next_retry_at': now,
        'last_error': null,
      },
      where: 'tenant_id = ? AND sync_status = ?',
      whereArgs: [tid, KpmsSyncQueueStatus.failed],
    );
  }
}
