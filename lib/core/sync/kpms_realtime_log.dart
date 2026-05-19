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

  static void eventReceived({
    required String table,
    required String tenantId,
    required String op,
    String? clientId,
  }) =>
      _emit(
        'event_received',
        'table=$table tenant=$tenantId op=$op${clientId != null ? ' id=$clientId' : ''}',
      );

  static void patchApplied({
    required String table,
    required String tenantId,
    required String clientId,
    required String op,
  }) =>
      _emit('patch_applied', 'table=$table tenant=$tenantId op=$op id=$clientId');

  static void duplicateIgnored({required String table, required String clientId, String? reason}) =>
      _emit('duplicate_ignored', 'table=$table id=$clientId${reason != null ? ' $reason' : ''}');

  static void inventoryReconciled({required String tenantId, required String medicineId, required int qty}) =>
      _emit('inventory_reconciled', 'tenant=$tenantId med=$medicineId qty=$qty');

  static void patchDeferred({required String reason}) => _emit('patch_deferred', reason);

  static void saleRefetchScheduled({required String tenantId, required String saleClientId}) =>
      _emit('sale_refetch_scheduled', 'tenant=$tenantId sale=$saleClientId');

  static void providerUpdated({required String provider}) => _emit('provider_updated', provider);
}
