import 'package:flutter/foundation.dart';

import '../../../core/sync/kpms_sync_log.dart';
import '../data/pharmacy_enterprise_cloud_repository.dart';
import '../data/pharmacy_enterprise_local_store.dart';
import '../domain/medicine_category.dart';
import '../domain/pharmacy_expense.dart';
import '../domain/product_barcode.dart';

/// Hybrid sync for enterprise extension entities.
class PharmacyEnterpriseSyncService {
  const PharmacyEnterpriseSyncService(this._cloud);

  final PharmacyEnterpriseCloudRepository _cloud;

  Future<({
    List<PharmacyExpense> expenses,
    List<MedicineCategory> categories,
    List<ProductBarcode> barcodes,
  })?> bootstrap({
    required String tenantId,
    required List<PharmacyExpense> localExpenses,
    required List<MedicineCategory> localCategories,
    required List<ProductBarcode> localBarcodes,
    String? userId,
  }) async {
    try {
      final cloud = await _cloud.pull(tenantId);
      if (cloud != null &&
          (cloud.expenses.isNotEmpty || cloud.categories.isNotEmpty || cloud.barcodes.isNotEmpty)) {
        await PharmacyEnterpriseLocalStore.save(
          tenantId: tenantId,
          expenses: cloud.expenses,
          categories: cloud.categories,
          barcodes: cloud.barcodes,
          userId: userId,
        );
        KpmsSyncLog.cloudRestoreCompleted(tenantId: 'enterprise:$tenantId', hasData: true);
        return cloud;
      }

      final localHas = localExpenses.isNotEmpty || localCategories.isNotEmpty || localBarcodes.isNotEmpty;
      if (localHas) {
        await _cloud.push(
          tenantId: tenantId,
          expenses: localExpenses,
          categories: localCategories,
          barcodes: localBarcodes,
          createdBy: userId,
        );
        KpmsSyncLog.cloudRestoreCompleted(tenantId: 'enterprise:$tenantId', hasData: true);
        return (
          expenses: localExpenses,
          categories: localCategories,
          barcodes: localBarcodes,
        );
      }

      KpmsSyncLog.cloudRestoreCompleted(tenantId: 'enterprise:$tenantId', hasData: false);
      return cloud;
    } catch (e, st) {
      debugPrint('PharmacyEnterpriseSyncService.bootstrap failed: $e\n$st');
      KpmsSyncLog.syncRetry('enterprise bootstrap: $e');
      if (localExpenses.isNotEmpty || localCategories.isNotEmpty || localBarcodes.isNotEmpty) {
        return (
          expenses: localExpenses,
          categories: localCategories,
          barcodes: localBarcodes,
        );
      }
      return null;
    }
  }

  Future<void> pushToCloud({
    required String tenantId,
    required List<PharmacyExpense> expenses,
    required List<MedicineCategory> categories,
    required List<ProductBarcode> barcodes,
    String? userId,
  }) async {
    await _cloud.push(
      tenantId: tenantId,
      expenses: expenses,
      categories: categories,
      barcodes: barcodes,
      createdBy: userId,
    );
  }
}
