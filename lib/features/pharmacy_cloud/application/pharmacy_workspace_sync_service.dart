import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/constants/app_prefs_keys.dart';
import '../../../core/persistence/kpms_persistence_log.dart';
import '../../../core/persistence/kpms_pharmacy_workspace_store.dart';
import '../../../core/sync/kpms_sync_log.dart';
import '../../debts/domain/debt_customer.dart';
import '../../medicines/domain/medicine.dart';
import '../../purchases/application/purchase_ledger_notifier.dart';
import '../../sales/application/sales_ledger_notifier.dart';
import '../../suppliers/domain/supplier.dart';
import '../data/pharmacy_cloud_repository.dart';

typedef PharmacyWorkspaceBundle = ({
  List<Medicine> medicines,
  SalesLedgerState sales,
  PurchaseLedgerState purchases,
  List<DebtCustomer> debtCustomers,
  List<Supplier> suppliers,
});

/// Hybrid cloud + local cache orchestration.
class PharmacyWorkspaceSyncService {
  const PharmacyWorkspaceSyncService(this._cloud);

  final PharmacyCloudRepository _cloud;

  static String _migratedKey(String tenantId) => 'kpms_cloud_workspace_migrated_v1_$tenantId';

  static String _lastPullKey(String tenantId) => '${AppPrefsKeys.workspaceLastPullAt}_$tenantId';

  static Future<DateTime?> lastPullAt(String tenantId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_lastPullKey(tenantId));
    return raw == null ? null : DateTime.tryParse(raw);
  }

  static Future<void> _recordLastPull(String tenantId) async {
    final now = DateTime.now().toUtc();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastPullKey(tenantId), now.toIso8601String());
    KpmsPersistenceLog.lastPullRecorded(tenantId: tenantId, iso: now.toIso8601String());
  }

  static Future<void> markMigrated(String tenantId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_migratedKey(tenantId), true);
  }

  static bool _bundleHasBusinessData(PharmacyWorkspaceBundle bundle) {
    return PharmacyCloudRepository.localNeedsMigration(
      medicines: bundle.medicines,
      sales: bundle.sales,
      purchases: bundle.purchases,
      debtCustomers: bundle.debtCustomers,
      suppliers: bundle.suppliers,
    );
  }

  /// Cloud rows win on id collision; local-only SKUs are preserved for push.
  static List<Medicine> mergeMedicines(List<Medicine> cloud, List<Medicine> local) {
    final merged = <String, Medicine>{for (final m in cloud) m.id: m};
    var localOnly = 0;
    for (final m in local) {
      if (!merged.containsKey(m.id)) {
        merged[m.id] = m;
        localOnly++;
      }
    }
    if (localOnly > 0) {
      KpmsSyncLog.workspaceMerged(
        direction: 'cloud+local',
        medicineCount: merged.length,
        localOnlyMedicines: localOnly,
      );
    }
    return merged.values.toList();
  }

  static PharmacyWorkspaceBundle mergeCloudWithLocal({
    required PharmacyWorkspaceBundle cloud,
    required PharmacyWorkspaceBundle local,
  }) {
    final cloudHasLedger = cloud.sales.invoices.isNotEmpty ||
        cloud.sales.returns.isNotEmpty ||
        cloud.purchases.invoices.isNotEmpty ||
        cloud.purchases.returns.isNotEmpty;

    return (
      medicines: mergeMedicines(cloud.medicines, local.medicines),
      sales: cloudHasLedger ? cloud.sales : local.sales,
      purchases: cloudHasLedger ? cloud.purchases : local.purchases,
      debtCustomers: cloud.debtCustomers.isNotEmpty ? cloud.debtCustomers : local.debtCustomers,
      suppliers: cloud.suppliers.isNotEmpty ? cloud.suppliers : local.suppliers,
    );
  }

  /// Cloud-first restore; preserves unsynced local-only catalog rows when online.
  Future<PharmacyWorkspaceBundle?> bootstrapWorkspace({
    required String tenantId,
    required List<Medicine> localMedicines,
    required SalesLedgerState localSales,
    required PurchaseLedgerState localPurchases,
    required List<DebtCustomer> localDebtCustomers,
    required List<Supplier> localSuppliers,
  }) async {
    final localBundle = (
      medicines: localMedicines,
      sales: localSales,
      purchases: localPurchases,
      debtCustomers: localDebtCustomers,
      suppliers: localSuppliers,
    );
    final localHas = _bundleHasBusinessData(localBundle);

    try {
      final lastPull = await lastPullAt(tenantId);
      final since = lastPull != null && DateTime.now().difference(lastPull) < const Duration(hours: 12)
          ? lastPull
          : null;
      final cloudBundle = await _cloud.pullWorkspace(tenantId, changesSince: since);
      if (cloudBundle == null) {
        KpmsSyncLog.cloudPullSkipped(tenantId: tenantId, reason: 'no_supabase_client');
        return localHas ? localBundle : null;
      }

      final cloudHas = await _cloud.hasCloudData(tenantId);
      final cloudHasBusiness = _bundleHasBusinessData(cloudBundle);

      KpmsSyncLog.cloudPullCompleted(
        tenantId: tenantId,
        medicines: cloudBundle.medicines.length,
        sales: cloudBundle.sales.invoices.length,
        purchases: cloudBundle.purchases.invoices.length,
        cloudHas: cloudHas,
      );

      if (cloudHasBusiness) {
        final merged = since != null
            ? mergeCloudWithLocal(
                cloud: (
                  medicines: mergeMedicines(cloudBundle.medicines, localBundle.medicines),
                  sales: cloudBundle.sales,
                  purchases: cloudBundle.purchases,
                  debtCustomers: cloudBundle.debtCustomers,
                  suppliers: cloudBundle.suppliers,
                ),
                local: localBundle,
              )
            : mergeCloudWithLocal(cloud: cloudBundle, local: localBundle);
        await markMigrated(tenantId);
        await _writeLocalCache(tenantId, merged);
        await _recordLastPull(tenantId);
        KpmsSyncLog.cloudRestoreCompleted(tenantId: tenantId, hasData: true);

        if (_hasLocalOnlyMedicines(cloudBundle.medicines, localMedicines)) {
          KpmsSyncLog.uploadStarted(tenantId: tenantId);
          await _cloud.pushWorkspace(
            tenantId: tenantId,
            medicines: merged.medicines,
            sales: merged.sales,
            purchases: merged.purchases,
            debtCustomers: merged.debtCustomers,
            suppliers: merged.suppliers,
          );
          KpmsSyncLog.uploadSuccess(tenantId: tenantId);
        }

        return merged;
      }

      if (cloudHas) {
        await markMigrated(tenantId);
        await _writeLocalCache(tenantId, cloudBundle);
        await _recordLastPull(tenantId);
        KpmsSyncLog.cloudRestoreCompleted(tenantId: tenantId, hasData: false);
        return cloudBundle;
      }

      if (localHas) {
        KpmsSyncLog.uploadStarted(tenantId: tenantId);
        await _cloud.pushWorkspace(
          tenantId: tenantId,
          medicines: localMedicines,
          sales: localSales,
          purchases: localPurchases,
          debtCustomers: localDebtCustomers,
          suppliers: localSuppliers,
        );
        await markMigrated(tenantId);
        KpmsSyncLog.cloudRestoreCompleted(tenantId: tenantId, hasData: true);
        return localBundle;
      }

      KpmsSyncLog.cloudRestoreCompleted(tenantId: tenantId, hasData: false);
      return cloudBundle;
    } catch (e, st) {
      debugPrint('PharmacyWorkspaceSyncService.bootstrap failed: $e\n$st');
      KpmsSyncLog.syncRetry('bootstrap: $e');
      if (localHas) return localBundle;
      return null;
    }
  }

  static bool _hasLocalOnlyMedicines(List<Medicine> cloud, List<Medicine> local) {
    final cloudIds = cloud.map((m) => m.id).toSet();
    return local.any((m) => !cloudIds.contains(m.id));
  }

  Future<void> pushToCloud({
    required String tenantId,
    required List<Medicine> medicines,
    required SalesLedgerState sales,
    required PurchaseLedgerState purchases,
    required List<DebtCustomer> debtCustomers,
    required List<Supplier> suppliers,
    List<String> deletedMedicineClientIds = const [],
  }) async {
    try {
      KpmsSyncLog.uploadStarted(tenantId: tenantId);
      final rows = await _cloud.pushWorkspace(
        tenantId: tenantId,
        medicines: medicines,
        sales: sales,
        purchases: purchases,
        debtCustomers: debtCustomers,
        suppliers: suppliers,
      );
      if (deletedMedicineClientIds.isNotEmpty) {
        await _cloud.deleteMedicines(tenantId, deletedMedicineClientIds);
      }
      await markMigrated(tenantId);
      KpmsSyncLog.uploadCompleted(
        tenantId: tenantId,
        rows: rows,
        medicines: medicines.length,
      );
    } catch (e, st) {
      debugPrint('PharmacyWorkspaceSyncService.push failed: $e\n$st');
      KpmsSyncLog.uploadFailed('$e');
      KpmsSyncLog.syncRetry('push: $e');
      rethrow;
    }
  }

  Future<void> _writeLocalCache(String tenantId, PharmacyWorkspaceBundle bundle) async {
    await KpmsPharmacyWorkspaceStore.save(
      tenantId: tenantId,
      medicines: bundle.medicines,
      sales: bundle.sales,
      purchases: bundle.purchases,
      debtCustomers: bundle.debtCustomers,
      suppliers: bundle.suppliers,
    );
  }
}
