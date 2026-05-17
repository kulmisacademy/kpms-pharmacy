import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../features/debts/application/debt_customers_notifier.dart';
import '../../../features/enterprise/application/medicine_categories_notifier.dart';
import '../../../features/enterprise/application/pharmacy_enterprise_providers.dart';
import '../../../features/enterprise/application/pharmacy_expenses_notifier.dart';
import '../../../features/enterprise/application/product_barcodes_notifier.dart';
import '../../../features/medicines/data/medicine_catalog_notifier.dart';
import '../../../features/pharmacy_cloud/application/pharmacy_cloud_providers.dart';
import '../../../features/purchases/application/purchase_ledger_notifier.dart';
import '../../../features/sales/application/sales_ledger_notifier.dart';
import '../../../features/suppliers/application/suppliers_notifier.dart';
import '../../auth/permission_providers.dart';
import '../kpms_sync_log.dart';
import '../../tenant/kpms_active_tenant_provider.dart';
import '../../tenant/pharmacy_workspace_isolation.dart';
import 'kpms_sync_outbox_models.dart';
import 'kpms_sync_outbox_service.dart';

/// Replays durable outbox rows using idempotent cloud upserts (tenant-safe snapshots).
abstract final class KpmsSyncOutboxProcessor {
  KpmsSyncOutboxProcessor._();

  static bool _busy = false;

  static bool _isWorkspaceFamily(String entityType) {
    return entityType == KpmsSyncEntityType.workspace ||
        entityType == KpmsSyncEntityType.sales ||
        entityType == KpmsSyncEntityType.purchases ||
        entityType == KpmsSyncEntityType.inventory ||
        entityType == KpmsSyncEntityType.customers ||
        entityType == KpmsSyncEntityType.suppliers ||
        entityType == KpmsSyncEntityType.returns;
  }

  static bool _isEnterpriseFamily(String entityType) {
    return entityType == KpmsSyncEntityType.enterprise ||
        entityType == KpmsSyncEntityType.expenses ||
        entityType == KpmsSyncEntityType.settings;
  }

  static Future<void> processDue(WidgetRef ref) async {
    if (_busy) return;
    _busy = true;
    try {
      final uid = ref.read(supabaseAuthUserIdProvider).valueOrNull;
      final tid = ref.read(kpmsActiveTenantIdProvider).valueOrNull;
      if (uid == null || tid == null || tid.isEmpty) return;
      if (!assertActiveTenantForPersistence(tid, userId: uid)) return;

      final loaded = ref.read(kpmsLoadedWorkspaceTenantProvider);
      if (loaded != null && loaded != tid) return;

      final rows = await KpmsSyncOutboxService.dueForTenant(tid);
      if (rows.isEmpty) {
        KpmsSyncLog.replayCompleted(processed: 0);
        return;
      }

      var processed = 0;

      for (final row in rows) {
        if (row.tenantId != tid) continue;

        try {
          if (_isWorkspaceFamily(row.entityType)) {
            KpmsSyncLog.uploadStarted(tenantId: '${tid}_outbox');
            await ref.read(pharmacyWorkspaceSyncServiceProvider).pushToCloud(
                  tenantId: tid,
                  medicines: ref.read(medicineCatalogProvider),
                  sales: ref.read(salesLedgerProvider),
                  purchases: ref.read(purchaseLedgerProvider),
                  debtCustomers: ref.read(debtCustomersProvider),
                  suppliers: ref.read(suppliersProvider),
                );
            await KpmsSyncOutboxService.clearPendingBulkForTenant(tid, entityType: KpmsSyncEntityType.workspace);
            await KpmsSyncOutboxService.deleteRow(row.id);
            KpmsSyncLog.uploadSuccess(tenantId: tid);
            processed++;
            continue;
          }

          if (_isEnterpriseFamily(row.entityType)) {
            KpmsSyncLog.uploadStarted(tenantId: '${tid}_outbox_enterprise');
            await ref.read(pharmacyEnterpriseSyncServiceProvider).pushToCloud(
                  tenantId: tid,
                  expenses: ref.read(pharmacyExpensesProvider),
                  categories: ref.read(medicineCategoriesProvider),
                  barcodes: ref.read(productBarcodesProvider),
                  userId: uid,
                );
            await KpmsSyncOutboxService.clearPendingBulkForTenant(tid, entityType: KpmsSyncEntityType.enterprise);
            await KpmsSyncOutboxService.deleteRow(row.id);
            KpmsSyncLog.uploadSuccess(tenantId: tid);
            processed++;
            continue;
          }

          await KpmsSyncOutboxService.scheduleRetry(row.id, 'unknown_entity:${row.entityType}');
        } catch (e) {
          KpmsSyncLog.uploadFailed('outbox id=${row.id} $e');
          await KpmsSyncOutboxService.scheduleRetry(row.id, e.toString());
        }
      }

      KpmsSyncLog.replayCompleted(processed: processed);
    } finally {
      _busy = false;
    }
  }
}
