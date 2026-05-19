import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/permission_providers.dart';
import '../../../core/persistence/kpms_pharmacy_workspace_store.dart';
import '../../../core/sync/outbox/kpms_sync_outbox_service.dart';
import '../../../core/tenant/kpms_active_tenant_provider.dart';
import '../../../providers/pharmacy_local_workspace.dart';
import '../../sales/application/sales_ledger_notifier.dart';
import '../../purchases/application/purchase_ledger_notifier.dart';
import '../../medicines/data/medicine_catalog_notifier.dart';
import 'pharmacy_cloud_providers.dart';
import 'pharmacy_workspace_sync_service.dart';

class SyncIntegritySnapshot {
  const SyncIntegritySnapshot({
    required this.tenantId,
    required this.lastPullIso,
    required this.cloudSales,
    required this.cloudPurchases,
    required this.cloudMedicines,
    required this.localSales,
    required this.localPurchases,
    required this.localMedicines,
    required this.memorySales,
    required this.memoryPurchases,
    required this.memoryMedicines,
    required this.pendingOutbox,
    required this.failedOutbox,
    required this.bootstrapReady,
  });

  final String tenantId;
  final String? lastPullIso;
  final int cloudSales;
  final int cloudPurchases;
  final int cloudMedicines;
  final int localSales;
  final int localPurchases;
  final int localMedicines;
  final int memorySales;
  final int memoryPurchases;
  final int memoryMedicines;
  final int pendingOutbox;
  final int failedOutbox;
  final bool bootstrapReady;
}

final syncIntegrityDiagnosticsProvider = FutureProvider<SyncIntegritySnapshot?>((ref) async {
  final tenantId = await ref.watch(kpmsActiveTenantIdProvider.future);
  if (tenantId == null || tenantId.isEmpty) return null;

  final lastPull = await PharmacyWorkspaceSyncService.lastPullAt(tenantId);
  final cloud = await ref.read(pharmacyCloudRepositoryProvider).countCloudRows(tenantId);
  final uid = ref.watch(supabaseAuthUserIdProvider).valueOrNull;
  final local = await KpmsPharmacyWorkspaceStore.load(tenantId, userId: uid);

  final pending = await KpmsSyncOutboxService.pendingCountForTenant(tenantId);
  final failed = await KpmsSyncOutboxService.failedCountForTenant(tenantId);

  return SyncIntegritySnapshot(
    tenantId: tenantId,
    lastPullIso: lastPull?.toUtc().toIso8601String(),
    cloudSales: cloud.sales,
    cloudPurchases: cloud.purchases,
    cloudMedicines: cloud.medicines,
    localSales: local?.sales.invoices.length ?? 0,
    localPurchases: local?.purchases.invoices.length ?? 0,
    localMedicines: local?.medicines.length ?? 0,
    memorySales: ref.watch(salesLedgerProvider).invoices.length,
    memoryPurchases: ref.watch(purchaseLedgerProvider).invoices.length,
    memoryMedicines: ref.watch(medicineCatalogProvider).length,
    pendingOutbox: pending,
    failedOutbox: failed,
    bootstrapReady: ref.watch(pharmacyWorkspaceBootstrapReadyProvider),
  );
});
