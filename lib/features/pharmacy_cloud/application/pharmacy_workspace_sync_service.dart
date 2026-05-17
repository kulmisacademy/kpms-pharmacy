import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/persistence/kpms_pharmacy_workspace_store.dart';
import '../../../core/sync/kpms_sync_log.dart';
import '../../debts/domain/debt_customer.dart';
import '../../medicines/domain/medicine.dart';
import '../../purchases/application/purchase_ledger_notifier.dart';
import '../../sales/application/sales_ledger_notifier.dart';
import '../../suppliers/domain/supplier.dart';
import '../data/pharmacy_cloud_repository.dart';

/// Hybrid cloud + local cache orchestration.
class PharmacyWorkspaceSyncService {
  const PharmacyWorkspaceSyncService(this._cloud);

  final PharmacyCloudRepository _cloud;

  static String _migratedKey(String tenantId) => 'kpms_cloud_workspace_migrated_v1_$tenantId';

  static Future<bool> isMigrated(String tenantId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_migratedKey(tenantId)) ?? false;
  }

  static Future<void> markMigrated(String tenantId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_migratedKey(tenantId), true);
  }

  /// Cloud-first restore with safe local→cloud migration.
  Future<({
    List<Medicine> medicines,
    SalesLedgerState sales,
    PurchaseLedgerState purchases,
    List<DebtCustomer> debtCustomers,
    List<Supplier> suppliers,
  })?> bootstrapWorkspace({
    required String tenantId,
    required List<Medicine> localMedicines,
    required SalesLedgerState localSales,
    required PurchaseLedgerState localPurchases,
    required List<DebtCustomer> localDebtCustomers,
    required List<Supplier> localSuppliers,
  }) async {
    try {
      final cloudHas = await _cloud.hasCloudData(tenantId);
      final cloudBundle = await _cloud.pullWorkspace(tenantId);

      if (cloudBundle != null &&
          PharmacyCloudRepository.localNeedsMigration(
            medicines: cloudBundle.medicines,
            sales: cloudBundle.sales,
            purchases: cloudBundle.purchases,
            debtCustomers: cloudBundle.debtCustomers,
            suppliers: cloudBundle.suppliers,
          )) {
        KpmsSyncLog.cloudRestoreCompleted(tenantId: tenantId, hasData: true);
        await markMigrated(tenantId);
        await _writeLocalCache(tenantId, cloudBundle);
        return cloudBundle;
      }

      final localHas = PharmacyCloudRepository.localNeedsMigration(
        medicines: localMedicines,
        sales: localSales,
        purchases: localPurchases,
        debtCustomers: localDebtCustomers,
        suppliers: localSuppliers,
      );

      if (!cloudHas && localHas) {
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
        return (
          medicines: localMedicines,
          sales: localSales,
          purchases: localPurchases,
          debtCustomers: localDebtCustomers,
          suppliers: localSuppliers,
        );
      }

      if (localHas) {
        KpmsSyncLog.cloudRestoreCompleted(tenantId: tenantId, hasData: true);
        return (
          medicines: localMedicines,
          sales: localSales,
          purchases: localPurchases,
          debtCustomers: localDebtCustomers,
          suppliers: localSuppliers,
        );
      }

      KpmsSyncLog.cloudRestoreCompleted(tenantId: tenantId, hasData: false);
      return cloudBundle;
    } catch (e, st) {
      debugPrint('PharmacyWorkspaceSyncService.bootstrap failed: $e\n$st');
      KpmsSyncLog.syncRetry('bootstrap: $e');
      if (PharmacyCloudRepository.localNeedsMigration(
        medicines: localMedicines,
        sales: localSales,
        purchases: localPurchases,
        debtCustomers: localDebtCustomers,
        suppliers: localSuppliers,
      )) {
        return (
          medicines: localMedicines,
          sales: localSales,
          purchases: localPurchases,
          debtCustomers: localDebtCustomers,
          suppliers: localSuppliers,
        );
      }
      return null;
    }
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
      await _cloud.pushWorkspace(
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
    } catch (e, st) {
      debugPrint('PharmacyWorkspaceSyncService.push failed: $e\n$st');
      KpmsSyncLog.syncRetry('push: $e');
      rethrow;
    }
  }

  Future<void> _writeLocalCache(
    String tenantId,
    ({
      List<Medicine> medicines,
      SalesLedgerState sales,
      PurchaseLedgerState purchases,
      List<DebtCustomer> debtCustomers,
      List<Supplier> suppliers,
    }) bundle,
  ) async {
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
