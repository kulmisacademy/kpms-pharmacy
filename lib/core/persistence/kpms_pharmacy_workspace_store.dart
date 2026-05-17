import 'package:shared_preferences/shared_preferences.dart';

import '../constants/app_prefs_keys.dart';
import '../tenant/kpms_tenant_log.dart';
import '../tenant/pharmacy_workspace_isolation.dart';
import 'kpms_persistence_log.dart';
import 'kpms_tenant_session_secure_store.dart';
import 'pharmacy_local_snapshot.dart';
import '../../features/debts/domain/debt_customer.dart';
import '../../features/medicines/domain/medicine.dart';
import '../../features/purchases/application/purchase_ledger_notifier.dart';
import '../../features/sales/application/sales_ledger_notifier.dart';
import '../../features/suppliers/domain/supplier.dart';

/// Tenant-scoped local workspace persistence (catalog, ledgers, AR, suppliers).
abstract final class KpmsPharmacyWorkspaceStore {
  KpmsPharmacyWorkspaceStore._();

  static const int bundleSchemaVersion = 1;

  static String prefsKey(String tenantId) => KpmsTenantStorageKeys.workspace(tenantId);

  static bool bundleHasBusinessData({
    required List<Medicine> medicines,
    required SalesLedgerState sales,
    required PurchaseLedgerState purchases,
    required List<DebtCustomer> debtCustomers,
    required List<Supplier> suppliers,
  }) {
    return medicines.isNotEmpty ||
        sales.invoices.isNotEmpty ||
        sales.returns.isNotEmpty ||
        purchases.invoices.isNotEmpty ||
        purchases.returns.isNotEmpty ||
        debtCustomers.isNotEmpty ||
        suppliers.isNotEmpty;
  }

  /// Loads workspace for [tenantId] only. Never returns a global/legacy bundle to the wrong tenant.
  static Future<({
    List<Medicine> medicines,
    SalesLedgerState sales,
    PurchaseLedgerState purchases,
    List<DebtCustomer> debtCustomers,
    List<Supplier> suppliers,
  })?>
      load(String tenantId, {String? userId}) async {
    final prefs = await SharedPreferences.getInstance();
    final tid = tenantId.trim();
    if (tid.isEmpty) return null;

    final key = prefsKey(tid);
    KpmsTenantLog.tenantStorageKey(key);

    // One-time legacy migration: only if secure snapshot proves this user owns this tenant.
    final legacyRaw = prefs.getString(AppPrefsKeys.pharmacyLocalWorkspace);
    if (legacyRaw != null && legacyRaw.trim().isNotEmpty) {
      final snap = await KpmsTenantSessionSecureStore.read();
      if (snap != null &&
          snap.tenantId.trim() == tid &&
          (userId == null || snap.userId == userId)) {
        final legacy = PharmacyLocalSnapshot.decode(legacyRaw);
        if (legacy != null) {
          KpmsTenantLog.crossTenantProtection('legacy_migrate_once to $tid');
          await save(
            tenantId: tid,
            medicines: legacy.medicines,
            sales: legacy.sales,
            purchases: legacy.purchases,
            debtCustomers: legacy.debtCustomers,
            suppliers: legacy.suppliers,
          );
          await prefs.remove(AppPrefsKeys.pharmacyLocalWorkspace);
          KpmsPersistenceLog.workspaceLoaded(tenantId: tid, hasData: true);
          return legacy;
        }
      } else {
        KpmsTenantLog.crossTenantProtection('ignored global legacy for tenant $tid');
      }
    }

    var raw = prefs.getString(key);
    if (raw == null || raw.trim().isEmpty) {
      final legacyTenantKey = 'kpms_pharmacy_workspace_v1_$tid';
      final legacyTenantRaw = prefs.getString(legacyTenantKey);
      if (legacyTenantRaw != null && legacyTenantRaw.trim().isNotEmpty) {
        KpmsTenantLog.crossTenantProtection('migrated per-tenant legacy key → $key');
        await prefs.setString(key, legacyTenantRaw);
        await prefs.remove(legacyTenantKey);
        raw = legacyTenantRaw;
      }
    }

    final bundle = PharmacyLocalSnapshot.decode(raw);
    final hasData = bundle != null &&
        bundleHasBusinessData(
          medicines: bundle.medicines,
          sales: bundle.sales,
          purchases: bundle.purchases,
          debtCustomers: bundle.debtCustomers,
          suppliers: bundle.suppliers,
        );
    KpmsPersistenceLog.workspaceLoaded(tenantId: tid, hasData: hasData);
    if (!hasData) KpmsPersistenceLog.workspaceEmpty(tenantId: tid);
    return bundle;
  }

  static Future<void> save({
    required String tenantId,
    required List<Medicine> medicines,
    required SalesLedgerState sales,
    required PurchaseLedgerState purchases,
    required List<DebtCustomer> debtCustomers,
    required List<Supplier> suppliers,
    String? userId,
  }) async {
    final tid = tenantId.trim();
    if (tid.isEmpty) return;
    if (userId != null && !assertActiveTenantForPersistence(tid, userId: userId)) return;

    final key = prefsKey(tid);
    KpmsTenantLog.tenantStorageKey(key);

    final prefs = await SharedPreferences.getInstance();
    final incomingHasData = bundleHasBusinessData(
      medicines: medicines,
      sales: sales,
      purchases: purchases,
      debtCustomers: debtCustomers,
      suppliers: suppliers,
    );

    if (!incomingHasData) {
      final existing = PharmacyLocalSnapshot.decode(prefs.getString(key));
      if (existing != null &&
          bundleHasBusinessData(
            medicines: existing.medicines,
            sales: existing.sales,
            purchases: existing.purchases,
            debtCustomers: existing.debtCustomers,
            suppliers: existing.suppliers,
          )) {
        KpmsPersistenceLog.skippedEmptyWorkspaceOverwrite(tid);
        KpmsPersistenceLog.emptyOverwriteBlocked(tid);
        return;
      }
    }

    final json = PharmacyLocalSnapshot.encodeJson(
      medicines: medicines,
      sales: sales,
      purchases: purchases,
      debtCustomers: debtCustomers,
      suppliers: suppliers,
    );
    await prefs.setString(key, json);
    await prefs.setInt(AppPrefsKeys.localBundleSchemaVersion, bundleSchemaVersion);
    KpmsPersistenceLog.workspaceSaved(tenantId: tid);
  }
}
