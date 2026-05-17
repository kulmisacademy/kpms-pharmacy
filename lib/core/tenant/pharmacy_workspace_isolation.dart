import 'package:flutter_riverpod/flutter_riverpod.dart';



import 'kpms_active_tenant_provider.dart';

import '../../features/analytics/application/sales_analytics_notifier.dart';
import '../../features/debts/application/debt_customers_notifier.dart';
import '../../features/enterprise/application/medicine_categories_notifier.dart';
import '../../features/enterprise/application/pharmacy_expenses_notifier.dart';
import '../../features/enterprise/application/product_barcodes_notifier.dart';

import '../../features/medicines/data/medicine_catalog_notifier.dart';

import '../../features/purchases/application/purchase_ledger_notifier.dart';

import '../../features/sales/application/sales_ledger_notifier.dart';

import '../../features/settings/application/pharmacy_settings_providers.dart';

import '../../features/suppliers/application/suppliers_notifier.dart';

import '../auth/permission_providers.dart';
import '../sync/outbox/kpms_sync_ui_provider.dart';
import '../supabase/profile_tenant_gate.dart';

import 'kpms_tenant_log.dart';



/// Last tenant whose workspace was hydrated into memory (detect cross-tenant leakage).

final kpmsLoadedWorkspaceTenantProvider = StateProvider<String?>((ref) => null);



/// Last auth user id that owned the in-memory workspace.

final kpmsLoadedWorkspaceUserProvider = StateProvider<String?>((ref) => null);



/// Tenant-scoped SharedPreferences key roots (never use global keys for business data).

abstract final class KpmsTenantStorageKeys {

  static String workspace(String tenantId) => 'kpms_workspace_$tenantId';

  static String sales(String tenantId) => 'kpms_sales_$tenantId';

  static String inventory(String tenantId) => 'kpms_inventory_$tenantId';

  static String purchases(String tenantId) => 'kpms_purchases_$tenantId';

  static String transactions(String tenantId) => 'kpms_transactions_$tenantId';

  static String staff(String tenantId) => 'kpms_staff_$tenantId';

  static String dashboard(String tenantId) => 'kpms_dashboard_$tenantId';

  static String salesMetrics(String tenantId) => 'kpms_sales_metrics_$tenantId';

  static String chartState(String tenantId) => 'kpms_chart_state_$tenantId';

  static String enterpriseBundle(String tenantId) => 'kpms_enterprise_v1_$tenantId';
}



// Riverpod 2.6: Ref (providers) and WidgetRef (widgets) are distinct types with the same API.

T _isoRead<T>(Object ref, ProviderListenable<T> provider) {

  if (ref is Ref) return ref.read(provider);

  return (ref as WidgetRef).read(provider);

}



void _isoInvalidate(Object ref, ProviderOrFamily provider) {

  if (ref is Ref) {

    ref.invalidate(provider);

  } else {

    (ref as WidgetRef).invalidate(provider);

  }

}



/// Clears in-memory operational state — required on logout and before another tenant loads.

void clearOperationalWorkspace(Object ref, {String? reason}) {

  KpmsTenantLog.workspaceCleared(reason: reason);

  _isoRead(ref, medicineCatalogProvider.notifier).replaceAll([]);

  _isoRead(ref, salesLedgerProvider.notifier).hydrate(const SalesLedgerState());

  _isoRead(ref, purchaseLedgerProvider.notifier).hydrate(const PurchaseLedgerState());

  _isoRead(ref, debtCustomersProvider.notifier).replaceAll([]);

  _isoRead(ref, suppliersProvider.notifier).replaceAll([]);

  _isoRead(ref, salesAnalyticsProvider.notifier).reset();
  _isoRead(ref, pharmacyExpensesProvider.notifier).replaceAll([]);
  _isoRead(ref, medicineCategoriesProvider.notifier).replaceAll([]);
  _isoRead(ref, productBarcodesProvider.notifier).replaceAll([]);

  _isoRead(ref, kpmsLoadedWorkspaceTenantProvider.notifier).state = null;

  _isoRead(ref, kpmsLoadedWorkspaceUserProvider.notifier).state = null;

  _isoRead(ref, kpmsSyncUiProvider.notifier).reset();

  _isoInvalidate(ref, pharmacySessionProvider);

}



/// Resets gates + workspace when auth session changes (login/logout/switch user).

void resetTenantSessionCaches(Object ref, {required String reason}) {

  KpmsTenantLog.tenantCacheReset(from: reason, to: 'cleared');

  ProfileTenantGate.invalidate();

  clearOperationalWorkspace(ref, reason: reason);

  _isoInvalidate(ref, kpmsActiveTenantIdProvider);

  _isoInvalidate(ref, kpmsPermissionContextProvider);

}



/// Ensures we never hydrate tenant B while tenant A data is still in memory.

void ensureWorkspaceTenantBoundary(

  Object ref, {

  required String? userId,

  required String tenantId,

}) {

  final prevTenant = _isoRead(ref, kpmsLoadedWorkspaceTenantProvider);

  final prevUser = _isoRead(ref, kpmsLoadedWorkspaceUserProvider);



  if (prevTenant != null && prevTenant != tenantId) {

    KpmsTenantLog.crossTenantProtection('tenant switch $prevTenant → $tenantId');

    clearOperationalWorkspace(ref, reason: 'tenant_switch');

  }

  if (prevUser != null && userId != null && prevUser != userId) {

    KpmsTenantLog.crossTenantProtection('user switch $prevUser → $userId');

    clearOperationalWorkspace(ref, reason: 'user_switch');

  }



  _isoRead(ref, kpmsLoadedWorkspaceTenantProvider.notifier).state = tenantId;

  _isoRead(ref, kpmsLoadedWorkspaceUserProvider.notifier).state = userId;

  KpmsTenantLog.activeTenant(tenantId, userId: userId);

}



/// Validates save/push targets the active tenant (blocks cross-tenant writes).

bool assertActiveTenantForPersistence(String tenantId, {String? userId}) {

  final tid = tenantId.trim();

  if (tid.isEmpty) {

    KpmsTenantLog.crossTenantProtection('blocked save: empty tenantId');

    return false;

  }

  final cached = userId != null ? ProfileTenantGate.cachedTenantId(userId) : null;

  if (cached != null && cached != tid) {

    KpmsTenantLog.crossTenantProtection('blocked save: tenantId $tid != cached $cached');

    return false;

  }

  return true;

}


