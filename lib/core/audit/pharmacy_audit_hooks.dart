import '../supabase/profile_tenant_gate.dart';
import '../supabase/supabase_bootstrap.dart';
import 'pharmacy_audit_service.dart';

/// Fire-and-forget audit events with tenant resolution from active profile gate.
abstract final class PharmacyAuditHooks {
  PharmacyAuditHooks._();

  static String? get _userId {
    final c = SupabaseBootstrap.clientOrNull;
    return c?.auth.currentUser?.id;
  }

  static String? get _tenantId {
    final uid = _userId;
    if (uid == null) return null;
    return ProfileTenantGate.cachedTenantId(uid);
  }

  static Future<void> _emit({
    required String action,
    required String entityType,
    String entityRef = '',
    String? entityId,
    Map<String, dynamic>? previousData,
    Map<String, dynamic>? nextData,
  }) async {
    final tid = _tenantId;
    if (tid == null || tid.isEmpty) return;
    await PharmacyAuditService.record(
      tenantId: tid,
      action: action,
      entityType: entityType,
      entityRef: entityRef,
      entityId: entityId,
      previousData: previousData,
      nextData: nextData,
      actorId: _userId,
    );
  }

  static Future<void> saleCompleted({
    required String invoiceNumber,
    required double total,
    Map<String, dynamic>? extra,
  }) =>
      _emit(
        action: 'sale.completed',
        entityType: 'sale',
        entityRef: invoiceNumber,
        entityId: invoiceNumber,
        nextData: {'total': total, ...?extra},
      );

  static Future<void> saleReturn({
    required String returnNumber,
    required String originalInvoice,
    required double refundTotal,
  }) =>
      _emit(
        action: 'sale.return',
        entityType: 'sale_return',
        entityRef: returnNumber,
        nextData: {'original': originalInvoice, 'refund': refundTotal},
      );

  static Future<void> inventoryChange({
    required String action,
    required String medicineId,
    Map<String, dynamic>? previousData,
    Map<String, dynamic>? nextData,
  }) =>
      _emit(
        action: action,
        entityType: 'inventory',
        entityRef: medicineId,
        entityId: medicineId,
        previousData: previousData,
        nextData: nextData,
      );

  static Future<void> purchaseRecorded({
    required String invoiceNumber,
    required double total,
  }) =>
      _emit(
        action: 'purchase.completed',
        entityType: 'purchase',
        entityRef: invoiceNumber,
        nextData: {'total': total},
      );

  static Future<void> settingsUpdated({
    required String tenantId,
    Map<String, dynamic>? previousData,
    Map<String, dynamic>? nextData,
  }) =>
      PharmacyAuditService.record(
        tenantId: tenantId,
        action: 'settings.updated',
        entityType: 'tenant_settings',
        entityRef: tenantId,
        previousData: previousData,
        nextData: nextData,
        actorId: _userId,
      );

  static Future<void> staffAction({
    required String action,
    required String entityRef,
    Map<String, dynamic>? nextData,
  }) =>
      _emit(
        action: action,
        entityType: 'staff',
        entityRef: entityRef,
        nextData: nextData,
      );

  static Future<void> authEvent(String action, {Map<String, dynamic>? extra}) =>
      _emit(
        action: action,
        entityType: 'auth',
        entityRef: _userId ?? '',
        nextData: extra,
      );

  static Future<void> expenseChange({
    required String action,
    required String expenseId,
    Map<String, dynamic>? previousData,
    Map<String, dynamic>? nextData,
  }) =>
      _emit(
        action: action,
        entityType: 'expense',
        entityRef: expenseId,
        entityId: expenseId,
        previousData: previousData,
        nextData: nextData,
      );
}
