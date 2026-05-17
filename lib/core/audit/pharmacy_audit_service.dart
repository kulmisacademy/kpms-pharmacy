import 'package:supabase_flutter/supabase_flutter.dart';

import '../supabase/auth_user_helpers.dart';
import '../supabase/supabase_bootstrap.dart';
import '../tenant/pharmacy_workspace_isolation.dart';
import 'kpms_audit_log.dart';

/// Centralized tenant-scoped audit writer (`pharmacy_audit_log`).
abstract final class PharmacyAuditService {
  PharmacyAuditService._();

  static SupabaseClient? get _client => SupabaseBootstrap.clientOrNull;

  static Future<void> record({
    required String tenantId,
    required String action,
    required String entityType,
    String entityRef = '',
    String? entityId,
    Map<String, dynamic>? previousData,
    Map<String, dynamic>? nextData,
    String? actorId,
  }) async {
    final tid = tenantId.trim();
    if (tid.isEmpty) return;
    if (!assertActiveTenantForPersistence(tid, userId: actorId)) {
      KpmsAuditLog.writeFailed(action, 'tenant_mismatch');
      return;
    }

    final c = _client;
    if (c == null) {
      KpmsAuditLog.queuedOffline(action);
      return;
    }

    final uid = actorId ?? kpmsAuthUserId(c);
    KpmsAuditLog.writeStarted(action, entityType: entityType);

    final payload = <String, dynamic>{
      'entity_id': ?(entityId != null && entityId.isNotEmpty ? entityId : null),
      'previous_data': ?previousData,
      'next_data': ?nextData,
    };

    try {
      await c.from('pharmacy_audit_log').insert({
        'tenant_id': tid,
        'actor_id': uid,
        'action': action,
        'entity_type': entityType,
        'entity_ref': entityRef.isNotEmpty ? entityRef : (entityId ?? ''),
        'payload': payload,
      });
      KpmsAuditLog.writeCompleted(action, entityRef: entityRef.isNotEmpty ? entityRef : entityId);
    } catch (e) {
      KpmsAuditLog.writeFailed(action, e);
    }
  }
}
