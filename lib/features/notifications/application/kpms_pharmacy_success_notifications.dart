import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/permission_providers.dart';
import '../../../core/notifications/pharmacy_notification_signal_provider.dart';
import '../../../core/tenant/kpms_active_tenant_provider.dart';
import '../../../core/tenant/pharmacy_workspace_isolation.dart';
import '../data/pharmacy_notification_repository.dart';
import '../domain/pharmacy_notification_models.dart';
import 'pharmacy_notifications_providers.dart';

/// Tenant-scoped success notifications (never writes without active tenant match).
abstract final class KpmsPharmacySuccessNotifications {
  KpmsPharmacySuccessNotifications._();

  static Future<void> record({
    required WidgetRef ref,
    required String kind,
    required String title,
    required String body,
    required String dedupeKey,
    Map<String, dynamic>? payload,
  }) async {
    final tid = ref.read(kpmsActiveTenantIdProvider).valueOrNull;
    final uid = ref.read(supabaseAuthUserIdProvider).valueOrNull;
    if (tid == null || tid.isEmpty || uid == null) return;

    final loaded = ref.read(kpmsLoadedWorkspaceTenantProvider);
    if (loaded != null && loaded != tid) return;

    await PharmacyNotificationRepository.upsertOperational(
      tenantId: tid,
      userId: uid,
      kind: kind,
      title: title,
      body: body,
      dedupeKey: dedupeKey,
      priority: 'low',
      payload: {
        ...?payload,
        'source': 'kpms_success',
      },
    );

    ref.read(pharmacyCloudNotificationSignalProvider.notifier).state++;
    ref.invalidate(pharmacyNotificationUnreadCountProvider);
    ref.invalidate(pharmacyNotificationFeedProvider);
  }

  static Future<void> saleCompleted(WidgetRef ref, {required String invoiceNumber, required double total}) =>
      record(
        ref: ref,
        kind: KpmsNotificationKind.saleCompleted,
        title: 'Sale completed',
        body: 'Invoice $invoiceNumber · ${total.toStringAsFixed(2)}',
        dedupeKey: 'sale_completed_$invoiceNumber',
        payload: {'invoice_number': invoiceNumber, 'total': total},
      );

  static Future<void> medicineAdded(WidgetRef ref, {required String medicineName, required String medicineId}) =>
      record(
        ref: ref,
        kind: KpmsNotificationKind.medicineAdded,
        title: 'Medicine added',
        body: medicineName,
        dedupeKey: 'medicine_added_$medicineId',
        payload: {'medicine_id': medicineId, 'name': medicineName},
      );

  static Future<void> expenseAdded(WidgetRef ref, {required String expenseId, required double amount}) =>
      record(
        ref: ref,
        kind: KpmsNotificationKind.expenseAdded,
        title: 'Expense recorded',
        body: amount.toStringAsFixed(2),
        dedupeKey: 'expense_added_$expenseId',
        payload: {'expense_id': expenseId, 'amount': amount},
      );

  static Future<void> syncCompleted(WidgetRef ref) => record(
        ref: ref,
        kind: KpmsNotificationKind.syncCompleted,
        title: 'Sync completed',
        body: 'Workspace is up to date with the cloud.',
        dedupeKey: 'sync_completed',
      );
}
