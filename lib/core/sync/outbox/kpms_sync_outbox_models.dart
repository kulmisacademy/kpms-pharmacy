/// Row in `kpms_sync_outbox`.
class KpmsSyncOutboxRow {
  const KpmsSyncOutboxRow({
    required this.id,
    required this.tenantId,
    required this.entityType,
    required this.operationType,
    required this.payloadJson,
    required this.createdAt,
    required this.retryCount,
    this.lastError,
    required this.syncStatus,
    required this.nextRetryAt,
  });

  final int id;
  final String tenantId;
  final String entityType;
  final String operationType;
  final String payloadJson;
  final int createdAt;
  final int retryCount;
  final String? lastError;
  final String syncStatus;
  final int nextRetryAt;

  factory KpmsSyncOutboxRow.fromMap(Map<String, Object?> m) {
    return KpmsSyncOutboxRow(
      id: (m['id'] as num).toInt(),
      tenantId: '${m['tenant_id']}',
      entityType: '${m['entity_type']}',
      operationType: '${m['operation_type']}',
      payloadJson: '${m['payload_json']}',
      createdAt: (m['created_at'] as num).toInt(),
      retryCount: (m['retry_count'] as num?)?.toInt() ?? 0,
      lastError: m['last_error'] as String?,
      syncStatus: '${m['sync_status']}',
      nextRetryAt: (m['next_retry_at'] as num).toInt(),
    );
  }
}

/// `entity_type` — maps to cloud replay strategy (idempotent upserts).
abstract final class KpmsSyncEntityType {
  static const workspace = 'workspace';
  static const enterprise = 'enterprise';
  static const sales = 'sales';
  static const purchases = 'purchases';
  static const inventory = 'inventory';
  static const expenses = 'expenses';
  static const customers = 'customers';
  static const suppliers = 'suppliers';
  static const returns = 'returns';
  static const settings = 'settings';

  /// Bulk workspace bundle (inventory + ledgers + AR/AP) — preferred for Phase B.
  static const Set<String> all = {
    workspace,
    enterprise,
    sales,
    purchases,
    inventory,
    expenses,
    customers,
    suppliers,
    returns,
    settings,
  };
}

abstract final class KpmsSyncOperationType {
  static const insert = 'insert';
  static const update = 'update';
  static const delete = 'delete';
  static const upsert = 'upsert';
}

abstract final class KpmsSyncQueueStatus {
  static const pending = 'pending';
  static const syncing = 'syncing';
  static const failed = 'failed';
}
