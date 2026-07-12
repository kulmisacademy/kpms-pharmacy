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
import '../../purchases/domain/purchase_invoice.dart';
import '../../purchases/domain/purchase_return.dart';
import '../../sales/application/sales_ledger_notifier.dart';
import '../../sales/domain/completed_sale_invoice.dart';
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

  static CompletedSaleInvoice _pickSaleInvoice(CompletedSaleInvoice a, CompletedSaleInvoice b) {
    if (a.issuedAt.isAfter(b.issuedAt)) return a;
    if (b.issuedAt.isAfter(a.issuedAt)) return b;
    return a.paidTowardInvoice >= b.paidTowardInvoice ? a : b;
  }

  static SalesLedgerState mergeSalesLedgers({
    required SalesLedgerState cloud,
    required SalesLedgerState local,
    required String tenantId,
  }) {
    final invoices = <String, CompletedSaleInvoice>{};
    var localOnly = 0;
    var cloudOnly = 0;
    var updated = 0;

    for (final inv in cloud.invoices) {
      invoices[inv.invoiceNumber] = inv;
    }
    final localInvoiceIds = local.invoices.map((i) => i.invoiceNumber).toSet();
    for (final inv in local.invoices) {
      final existing = invoices[inv.invoiceNumber];
      if (existing == null) {
        invoices[inv.invoiceNumber] = inv;
        localOnly++;
      } else {
        final picked = _pickSaleInvoice(existing, inv);
        if (!identical(picked, existing)) updated++;
        invoices[inv.invoiceNumber] = picked;
      }
    }
    cloudOnly = cloud.invoices.where((i) => !localInvoiceIds.contains(i.invoiceNumber)).length;

    final returns = <String, SalesReturnRecord>{};
    var localReturns = 0;
    for (final r in cloud.returns) {
      returns[r.returnInvoiceNumber] = r;
    }
    for (final r in local.returns) {
      if (!returns.containsKey(r.returnInvoiceNumber)) {
        returns[r.returnInvoiceNumber] = r;
        localReturns++;
      }
    }

    final merged = SalesLedgerState(
      invoices: invoices.values.toList()
        ..sort((a, b) => b.issuedAt.compareTo(a.issuedAt)),
      returns: returns.values.toList(),
    );

    KpmsSyncLog.ledgerMergeDecision(
      tenantId: tenantId,
      entity: 'sales',
      cloudCount: cloud.invoices.length,
      localCount: local.invoices.length,
      mergedCount: merged.invoices.length,
      localOnly: localOnly,
      cloudOnly: cloudOnly,
      updated: updated,
    );
    if (localReturns > 0) {
      KpmsSyncLog.ledgerMergeDecision(
        tenantId: tenantId,
        entity: 'sale_returns',
        cloudCount: cloud.returns.length,
        localCount: local.returns.length,
        mergedCount: merged.returns.length,
        localOnly: localReturns,
        cloudOnly: 0,
        updated: 0,
      );
    }
    return merged;
  }

  static PurchaseLedgerState mergePurchaseLedgers({
    required PurchaseLedgerState cloud,
    required PurchaseLedgerState local,
    required String tenantId,
  }) {
    final invoices = <String, PurchaseInvoice>{};
    var localOnly = 0;
    var updated = 0;

    for (final inv in cloud.invoices) {
      invoices[inv.invoiceNumber] = inv;
    }
    for (final inv in local.invoices) {
      final existing = invoices[inv.invoiceNumber];
      if (existing == null) {
        invoices[inv.invoiceNumber] = inv;
        localOnly++;
      } else {
        final picked = inv.issuedAt.isAfter(existing.issuedAt) ? inv : existing;
        if (!identical(picked, existing)) updated++;
        invoices[inv.invoiceNumber] = picked;
      }
    }

    final returns = <String, PurchaseReturnRecord>{};
    var localReturns = 0;
    for (final r in cloud.returns) {
      returns[r.returnInvoiceNumber] = r;
    }
    for (final r in local.returns) {
      if (!returns.containsKey(r.returnInvoiceNumber)) {
        returns[r.returnInvoiceNumber] = r;
        localReturns++;
      }
    }

    final merged = PurchaseLedgerState(
      invoices: invoices.values.toList()
        ..sort((a, b) => b.issuedAt.compareTo(a.issuedAt)),
      returns: returns.values.toList(),
    );

    KpmsSyncLog.ledgerMergeDecision(
      tenantId: tenantId,
      entity: 'purchases',
      cloudCount: cloud.invoices.length,
      localCount: local.invoices.length,
      mergedCount: merged.invoices.length,
      localOnly: localOnly,
      cloudOnly: 0,
      updated: updated,
    );
    if (localReturns > 0) {
      KpmsSyncLog.ledgerMergeDecision(
        tenantId: tenantId,
        entity: 'purchase_returns',
        cloudCount: cloud.returns.length,
        localCount: local.returns.length,
        mergedCount: merged.returns.length,
        localOnly: localReturns,
        cloudOnly: 0,
        updated: 0,
      );
    }
    return merged;
  }

  static List<DebtCustomer> mergeDebtCustomers(List<DebtCustomer> cloud, List<DebtCustomer> local) {
    final merged = <String, DebtCustomer>{for (final c in cloud) c.id: c};
    for (final c in local) {
      merged.putIfAbsent(c.id, () => c);
    }
    return merged.values.toList();
  }

  static List<Supplier> mergeSuppliers(List<Supplier> cloud, List<Supplier> local) {
    final merged = <String, Supplier>{for (final s in cloud) s.id: s};
    for (final s in local) {
      merged.putIfAbsent(s.id, () => s);
    }
    return merged.values.toList();
  }

  static PharmacyWorkspaceBundle mergeCloudWithLocal({
    required PharmacyWorkspaceBundle cloud,
    required PharmacyWorkspaceBundle local,
    required String tenantId,
  }) {
    return (
      medicines: mergeMedicines(cloud.medicines, local.medicines),
      sales: mergeSalesLedgers(cloud: cloud.sales, local: local.sales, tenantId: tenantId),
      purchases: mergePurchaseLedgers(
        cloud: cloud.purchases,
        local: local.purchases,
        tenantId: tenantId,
      ),
      debtCustomers: mergeDebtCustomers(cloud.debtCustomers, local.debtCustomers),
      suppliers: mergeSuppliers(cloud.suppliers, local.suppliers),
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
      final since = lastPull != null &&
              localHas &&
              DateTime.now().difference(lastPull) < const Duration(hours: 12)
          ? lastPull
          : null;

      if (since != null) {
        KpmsSyncLog.bootstrapPullMode(
          tenantId: tenantId,
          mode: 'incremental',
          sinceIso: since.toUtc().toIso8601String(),
        );
        KpmsSyncLog.workspaceRestoreSource(tenantId: tenantId, source: 'incremental_bootstrap');
        final delta = await _cloud.pullWorkspace(tenantId, changesSince: since);
        if (delta != null) {
          final merged = mergeCloudWithLocal(
            cloud: delta,
            local: localBundle,
            tenantId: tenantId,
          );
          await markMigrated(tenantId);
          await _writeLocalCache(tenantId, merged);
          await _recordLastPull(tenantId);
          KpmsSyncLog.cloudRestoreCompleted(tenantId: tenantId, hasData: _bundleHasBusinessData(merged));
          if (_needsPushAfterMerge(delta, localBundle, merged)) {
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
      }

      KpmsSyncLog.bootstrapPullMode(tenantId: tenantId, mode: 'full');
      KpmsSyncLog.workspaceRestoreSource(tenantId: tenantId, source: 'cloud_first_full_pull');
      final cloudBundle = await _cloud.pullWorkspace(tenantId);
      if (cloudBundle == null) {
        KpmsSyncLog.cloudPullSkipped(tenantId: tenantId, reason: 'no_supabase_client');
        if (localHas) {
          KpmsSyncLog.workspaceRestoreSource(tenantId: tenantId, source: 'local_only_offline');
        }
        return localHas ? localBundle : null;
      }

      final cloudHasBusiness = _bundleHasBusinessData(cloudBundle);
      final cloudHas = cloudHasBusiness ||
          cloudBundle.medicines.isNotEmpty ||
          cloudBundle.sales.invoices.isNotEmpty ||
          cloudBundle.purchases.invoices.isNotEmpty;

      KpmsSyncLog.cloudPullCompleted(
        tenantId: tenantId,
        medicines: cloudBundle.medicines.length,
        sales: cloudBundle.sales.invoices.length,
        purchases: cloudBundle.purchases.invoices.length,
        cloudHas: cloudHas,
      );

      final merged = mergeCloudWithLocal(
        cloud: cloudBundle,
        local: localBundle,
        tenantId: tenantId,
      );
      final mergedHasBusiness = _bundleHasBusinessData(merged);

      if (cloudHasBusiness || localHas || mergedHasBusiness) {
        await markMigrated(tenantId);
        await _writeLocalCache(tenantId, merged);
        await _recordLastPull(tenantId);
        KpmsSyncLog.workspaceRestoreSource(
          tenantId: tenantId,
          source: cloudHasBusiness ? 'cloud_merged_with_local' : 'local_hydrated_to_cloud',
          pullIso: lastPull?.toUtc().toIso8601String(),
        );
        KpmsSyncLog.cloudRestoreCompleted(tenantId: tenantId, hasData: mergedHasBusiness);

        if (_needsPushAfterMerge(cloudBundle, localBundle, merged)) {
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
        final fallback = localHas
            ? mergeCloudWithLocal(cloud: cloudBundle, local: localBundle, tenantId: tenantId)
            : cloudBundle;
        await markMigrated(tenantId);
        await _writeLocalCache(tenantId, fallback);
        await _recordLastPull(tenantId);
        KpmsSyncLog.workspaceRestoreSource(
          tenantId: tenantId,
          source: localHas ? 'cloud_metadata_local_ledger' : 'cloud_metadata_only',
        );
        KpmsSyncLog.cloudRestoreCompleted(tenantId: tenantId, hasData: _bundleHasBusinessData(fallback));
        return fallback;
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

  static bool _hasLocalOnlySales(SalesLedgerState cloud, SalesLedgerState merged) {
    final cloudIds = cloud.invoices.map((i) => i.invoiceNumber).toSet();
    return merged.invoices.any((i) => !cloudIds.contains(i.invoiceNumber));
  }

  static bool _hasLocalOnlyPurchases(PurchaseLedgerState cloud, PurchaseLedgerState merged) {
    final cloudIds = cloud.invoices.map((i) => i.invoiceNumber).toSet();
    return merged.invoices.any((i) => !cloudIds.contains(i.invoiceNumber));
  }

  static bool _needsPushAfterMerge(
    PharmacyWorkspaceBundle cloud,
    PharmacyWorkspaceBundle local,
    PharmacyWorkspaceBundle merged,
  ) {
    return _hasLocalOnlyMedicines(cloud.medicines, merged.medicines) ||
        _hasLocalOnlySales(cloud.sales, merged.sales) ||
        _hasLocalOnlyPurchases(cloud.purchases, merged.purchases);
  }

  /// Lightweight reconnect path — merges cloud deltas into current local bundle.
  Future<PharmacyWorkspaceBundle?> incrementalRefreshWorkspace({
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
    final lastPull = await lastPullAt(tenantId);
    if (lastPull == null) return null;
    if (DateTime.now().difference(lastPull) > const Duration(hours: 12)) return null;

    try {
      KpmsSyncLog.bootstrapPullMode(
        tenantId: tenantId,
        mode: 'incremental',
        sinceIso: lastPull.toUtc().toIso8601String(),
      );
      final delta = await _cloud.pullWorkspace(tenantId, changesSince: lastPull);
      if (delta == null) return null;

      final merged = mergeCloudWithLocal(
        cloud: delta,
        local: localBundle,
        tenantId: tenantId,
      );
      await _writeLocalCache(tenantId, merged);
      await _recordLastPull(tenantId);
      KpmsSyncLog.workspaceRestoreSource(tenantId: tenantId, source: 'incremental_reconnect');
      return merged;
    } catch (e, st) {
      debugPrint('PharmacyWorkspaceSyncService.incrementalRefresh failed: $e\n$st');
      KpmsSyncLog.syncRetry('incremental_refresh: $e');
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
      KpmsSyncLog.uploadStarted(tenantId: tenantId);
      KpmsSyncLog.salePushAttempt(
        tenantId: tenantId,
        invoiceCount: sales.invoices.length,
        returnCount: sales.returns.length,
      );
      final rows = await _cloud.pushWorkspace(
        tenantId: tenantId,
        medicines: medicines,
        sales: sales,
        purchases: purchases,
        debtCustomers: debtCustomers,
        suppliers: suppliers,
      );
      KpmsSyncLog.salePushResult(tenantId: tenantId, success: true, rows: rows);
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
      KpmsSyncLog.salePushResult(tenantId: tenantId, success: false, error: '$e');
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
