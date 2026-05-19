import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/permission_providers.dart';
import '../../../core/persistence/kpms_persistence_log.dart';
import '../../../core/persistence/kpms_pharmacy_workspace_store.dart';
import '../../../core/sync/kpms_workspace_log.dart';
import '../../../core/tenant/kpms_active_tenant_provider.dart';
import '../../../core/tenant/pharmacy_workspace_isolation.dart';
import '../../../providers/pharmacy_local_workspace.dart';
import '../../debts/application/debt_customers_notifier.dart';
import '../../enterprise/application/medicine_categories_notifier.dart';
import '../../enterprise/application/pharmacy_expenses_notifier.dart';
import '../../enterprise/application/product_barcodes_notifier.dart';
import '../../enterprise/data/pharmacy_enterprise_local_store.dart';
import '../../medicines/data/medicine_catalog_notifier.dart';
import '../../purchases/application/purchase_ledger_notifier.dart';
import '../../sales/application/sales_ledger_notifier.dart';
import '../../suppliers/application/suppliers_notifier.dart';

/// Debounced disk persistence after in-memory realtime patches.
final workspaceRealtimePersistSchedulerProvider = Provider<WorkspaceRealtimePersistScheduler>((ref) {
  final scheduler = WorkspaceRealtimePersistScheduler(ref);
  ref.onDispose(scheduler.dispose);
  return scheduler;
});

class WorkspaceRealtimePersistScheduler {
  WorkspaceRealtimePersistScheduler(this._ref);

  final Ref _ref;
  Timer? _workspaceTimer;
  Timer? _enterpriseTimer;
  bool _workspaceDirty = false;
  bool _enterpriseDirty = false;

  void markWorkspaceDirty() {
    _workspaceDirty = true;
    _workspaceTimer?.cancel();
    _workspaceTimer = Timer(const Duration(milliseconds: 450), () => unawaited(_flushWorkspace()));
  }

  void markEnterpriseDirty() {
    _enterpriseDirty = true;
    _enterpriseTimer?.cancel();
    _enterpriseTimer = Timer(const Duration(milliseconds: 450), () => unawaited(_flushEnterprise()));
  }

  Future<void> _flushWorkspace() async {
    if (!_workspaceDirty) return;
    _workspaceDirty = false;
    final tid = _ref.read(kpmsActiveTenantIdProvider).valueOrNull;
    final uid = _ref.read(supabaseAuthUserIdProvider).valueOrNull;
    if (tid == null || tid.isEmpty) return;
    final loaded = _ref.read(kpmsLoadedWorkspaceTenantProvider);
    if (!assertActiveTenantForPersistence(tid, userId: uid, loadedWorkspaceTenantId: loaded)) return;
    if (loaded != null && loaded != tid) return;

    await KpmsPharmacyWorkspaceStore.save(
      tenantId: tid,
      userId: uid,
      medicines: _ref.read(medicineCatalogProvider),
      sales: _ref.read(salesLedgerProvider),
      purchases: _ref.read(purchaseLedgerProvider),
      debtCustomers: _ref.read(debtCustomersProvider),
      suppliers: _ref.read(suppliersProvider),
    );
    KpmsPersistenceLog.realtimePatchSaved(tenantId: tid);
    KpmsWorkspaceLog.patchPersisted(tenantId: tid);
  }

  Future<void> _flushEnterprise() async {
    if (!_enterpriseDirty) return;
    _enterpriseDirty = false;
    final tid = _ref.read(kpmsActiveTenantIdProvider).valueOrNull;
    final uid = _ref.read(supabaseAuthUserIdProvider).valueOrNull;
    if (tid == null || tid.isEmpty) return;

    await PharmacyEnterpriseLocalStore.save(
      tenantId: tid,
      userId: uid,
      expenses: _ref.read(pharmacyExpensesProvider),
      categories: _ref.read(medicineCategoriesProvider),
      barcodes: _ref.read(productBarcodesProvider),
    );
    KpmsPersistenceLog.realtimePatchSaved(tenantId: tid);
  }

  void dispose() {
    _workspaceTimer?.cancel();
    _enterpriseTimer?.cancel();
  }
}
