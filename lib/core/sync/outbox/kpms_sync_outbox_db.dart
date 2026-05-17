import 'package:sqflite/sqflite.dart';

import 'package:path/path.dart' as p;

/// SQLite database for durable sync outbox (device-local, tenant-scoped rows).
abstract final class KpmsSyncOutboxDb {
  KpmsSyncOutboxDb._();

  static Database? _db;

  static Future<Database> get instance async {
    if (_db != null) return _db!;
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, 'kpms_sync_outbox.db');
    _db = await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE kpms_sync_outbox (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            tenant_id TEXT NOT NULL,
            entity_type TEXT NOT NULL,
            operation_type TEXT NOT NULL,
            payload_json TEXT NOT NULL,
            created_at INTEGER NOT NULL,
            retry_count INTEGER NOT NULL DEFAULT 0,
            last_error TEXT,
            sync_status TEXT NOT NULL,
            next_retry_at INTEGER NOT NULL
          )
        ''');
        await db.execute(
          'CREATE INDEX idx_outbox_tenant_status_next ON kpms_sync_outbox(tenant_id, sync_status, next_retry_at)',
        );
      },
    );
    return _db!;
  }

  /// For tests only.
  static Future<void> closeForTest() async {
    if (_db != null) {
      await _db!.close();
      _db = null;
    }
  }
}
