import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/sync/kpms_sync_log.dart';
import '../core/utils/kpms_feedback.dart';
import '../features/notifications/application/kpms_pharmacy_success_notifications.dart';
import '../core/sync/outbox/kpms_sync_outbox_db.dart';
import '../core/sync/outbox/kpms_sync_outbox_models.dart';
import '../core/sync/outbox/kpms_sync_outbox_processor.dart';
import '../core/sync/outbox/kpms_sync_outbox_service.dart';
import '../core/sync/outbox/kpms_sync_ui_provider.dart';

export '../core/tenant/kpms_active_tenant_provider.dart' show kpmsActiveTenantIdProvider;

import '../core/auth/permission_providers.dart';
import '../core/persistence/kpms_persistence_log.dart';
import '../core/persistence/kpms_pharmacy_workspace_store.dart';
import '../core/tenant/kpms_active_tenant_provider.dart';
import '../core/tenant/kpms_tenant_log.dart';
import '../core/tenant/pharmacy_workspace_isolation.dart';
import '../features/debts/application/debt_customers_notifier.dart';
import '../features/debts/domain/debt_customer.dart';
import '../features/medicines/application/pending_medicine_deletions_notifier.dart';
import '../features/medicines/data/medicine_catalog_notifier.dart';
import '../features/medicines/domain/medicine.dart';
import '../features/enterprise/application/medicine_categories_notifier.dart';
import '../features/enterprise/application/pharmacy_enterprise_providers.dart';
import '../features/enterprise/application/pharmacy_expenses_notifier.dart';
import '../features/enterprise/application/product_barcodes_notifier.dart';
import '../features/enterprise/data/pharmacy_enterprise_local_store.dart';
import '../features/pharmacy_cloud/application/pharmacy_cloud_providers.dart';
import '../features/purchases/application/purchase_ledger_notifier.dart';
import '../features/analytics/application/sales_analytics_notifier.dart';
import '../features/sales/application/sales_ledger_notifier.dart';
import '../features/suppliers/application/suppliers_notifier.dart';
import '../features/suppliers/domain/supplier.dart';

/// Current bundle schema for local workspace JSON. Bump only with a migration path.
const int kpmsLocalBundleSchemaCurrent = 1;

/// Immediate local save + optional cloud push (e.g. before sign-out).
Future<void> flushPharmacyWorkspacePersistence(
  WidgetRef ref, {
  String reason = 'manual_flush',
  bool pushCloud = true,
}) async {
  final tid = ref.read(kpmsActiveTenantIdProvider).valueOrNull;
  final uid = ref.read(supabaseAuthUserIdProvider).valueOrNull;
  if (tid == null || tid.isEmpty) return;

  KpmsSyncLog.workspaceFlush(tenantId: tid, reason: reason);
  final loaded = ref.read(kpmsLoadedWorkspaceTenantProvider);
  if (!assertActiveTenantForPersistence(tid, userId: uid, loadedWorkspaceTenantId: loaded)) return;
  if (loaded != null && loaded != tid) return;

  final sales = ref.read(salesLedgerProvider);
  final purchases = ref.read(purchaseLedgerProvider);
  if (sales.invoices.isNotEmpty) {
    KpmsSyncLog.salePushAttempt(
      tenantId: tid,
      invoiceCount: sales.invoices.length,
      returnCount: sales.returns.length,
    );
  }

  await KpmsPharmacyWorkspaceStore.save(
    tenantId: tid,
    userId: uid,
    medicines: ref.read(medicineCatalogProvider),
    sales: sales,
    purchases: purchases,
    debtCustomers: ref.read(debtCustomersProvider),
    suppliers: ref.read(suppliersProvider),
  );

  if (!pushCloud) return;
  final bootstrapReady = ref.read(pharmacyWorkspaceBootstrapReadyProvider);
  if (!bootstrapReady) {
    KpmsSyncLog.bootstrapGatedPush(allowed: false, reason: 'flush_before_bootstrap');
    return;
  }

  try {
    final pendingDeletes = List<String>.from(ref.read(pendingMedicineDeletionsProvider));
    await ref.read(pharmacyWorkspaceSyncServiceProvider).pushToCloud(
          tenantId: tid,
          medicines: ref.read(medicineCatalogProvider),
          sales: sales,
          purchases: purchases,
          debtCustomers: ref.read(debtCustomersProvider),
          suppliers: ref.read(suppliersProvider),
          deletedMedicineClientIds: pendingDeletes,
        );
    if (pendingDeletes.isNotEmpty) {
      await ref.read(pendingMedicineDeletionsProvider.notifier).clearIds(pendingDeletes);
    }
  } catch (e) {
    await KpmsSyncOutboxService.enqueue(
      tenantId: tid,
      entityType: KpmsSyncEntityType.workspace,
      operationType: KpmsSyncOperationType.upsert,
      payload: {'reason': 'flush_failed', 'error': e.toString()},
    );
  }
}

void _hydrateWorkspace(
  Ref ref, {
  required String tenantId,
  required String? userId,
  required List<Medicine> medicines,
  required SalesLedgerState sales,
  required PurchaseLedgerState purchases,
  required List<DebtCustomer> debtCustomers,
  required List<Supplier> suppliers,
}) {
  ensureWorkspaceTenantBoundary(ref, userId: userId, tenantId: tenantId);
  ref.read(medicineCatalogProvider.notifier).replaceAll(medicines);
  ref.read(salesLedgerProvider.notifier).hydrate(sales);
  ref.read(purchaseLedgerProvider.notifier).hydrate(purchases);
  ref.read(debtCustomersProvider.notifier).replaceAll(debtCustomers);
  ref.read(suppliersProvider.notifier).replaceAll(suppliers);
  ref.read(salesAnalyticsProvider.notifier).rebuildFromLedger(sales, tenantId: tenantId);
  KpmsTenantLog.workspaceLoaded(tenantId);
}

/// Hybrid bootstrap: cloud pull + merge → single hydrate (avoids stale pre-cloud auto-push).
final pharmacyWorkspaceBootstrapProvider = FutureProvider<void>((ref) async {
  ref.watch(pharmacyCloudSyncGenerationProvider);
  ref.read(pharmacyWorkspaceBootstrapReadyProvider.notifier).state = false;

  final uid = ref.watch(supabaseAuthUserIdProvider).valueOrNull;
  final tenantId = await ref.watch(kpmsActiveTenantIdProvider.future);

  if (uid == null || tenantId == null || tenantId.isEmpty) {
    clearOperationalWorkspace(ref, reason: 'no_tenant');
    ref.read(pharmacyWorkspaceBootstrapReadyProvider.notifier).state = false;
    return;
  }

  ensureWorkspaceTenantBoundary(ref, userId: uid, tenantId: tenantId);
  await ref.read(pendingMedicineDeletionsProvider.notifier).reloadForTenant(tenantId);

  final local = await KpmsPharmacyWorkspaceStore.load(tenantId, userId: uid);
  final localMeds = local?.medicines ?? const [];
  final localSales = local?.sales ?? const SalesLedgerState();
  final localPurchases = local?.purchases ?? const PurchaseLedgerState();
  final localDebts = local?.debtCustomers ?? const [];
  final localSuppliers = local?.suppliers ?? const [];

  var hydrated = false;
  try {
    final sync = ref.read(pharmacyWorkspaceSyncServiceProvider);
    final bundle = await sync.bootstrapWorkspace(
      tenantId: tenantId,
      localMedicines: localMeds,
      localSales: localSales,
      localPurchases: localPurchases,
      localDebtCustomers: localDebts,
      localSuppliers: localSuppliers,
    );

    if (bundle != null) {
      _hydrateWorkspace(
        ref,
        tenantId: tenantId,
        userId: uid,
        medicines: bundle.medicines,
        sales: bundle.sales,
        purchases: bundle.purchases,
        debtCustomers: bundle.debtCustomers,
        suppliers: bundle.suppliers,
      );
      hydrated = true;
      KpmsPersistenceLog.workspaceLoaded(
        tenantId: tenantId,
        hasData: KpmsPharmacyWorkspaceStore.bundleHasBusinessData(
          medicines: bundle.medicines,
          sales: bundle.sales,
          purchases: bundle.purchases,
          debtCustomers: bundle.debtCustomers,
          suppliers: bundle.suppliers,
        ),
      );
      KpmsSyncLog.workspaceRefreshed(
        tenantId: tenantId,
        medicines: bundle.medicines.length,
        source: 'bootstrap',
      );
    } else if (local != null) {
      _hydrateWorkspace(
        ref,
        tenantId: tenantId,
        userId: uid,
        medicines: localMeds,
        sales: localSales,
        purchases: localPurchases,
        debtCustomers: localDebts,
        suppliers: localSuppliers,
      );
      hydrated = true;
      KpmsPersistenceLog.workspaceRecovered(tenantId: tenantId, reason: 'cloud_unavailable_used_local');
    } else {
      clearOperationalWorkspace(ref, reason: 'empty_tenant_workspace');
      ensureWorkspaceTenantBoundary(ref, userId: uid, tenantId: tenantId);
    }
  } catch (e, st) {
    // ignore: avoid_print
    print('pharmacyWorkspaceBootstrap failed: $e\n$st');
    if (!hydrated && local != null) {
      _hydrateWorkspace(
        ref,
        tenantId: tenantId,
        userId: uid,
        medicines: localMeds,
        sales: localSales,
        purchases: localPurchases,
        debtCustomers: localDebts,
        suppliers: localSuppliers,
      );
      hydrated = true;
      KpmsPersistenceLog.workspaceRecovered(tenantId: tenantId, reason: 'bootstrap_error_used_local');
    }
    rethrow;
  } finally {
    ref.read(pharmacyWorkspaceBootstrapReadyProvider.notifier).state = hydrated;
  }
});

/// Back-compat alias.
final pharmacyLocalBootstrapProvider = pharmacyWorkspaceBootstrapProvider;

/// Debounced local cache + cloud push (tenant-scoped only).
class PharmacyWorkspaceAutoSaveHost extends ConsumerStatefulWidget {
  const PharmacyWorkspaceAutoSaveHost({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<PharmacyWorkspaceAutoSaveHost> createState() => _PharmacyWorkspaceAutoSaveHostState();
}

class _PharmacyWorkspaceAutoSaveHostState extends ConsumerState<PharmacyWorkspaceAutoSaveHost> {
  Timer? _localTimer;
  Timer? _cloudTimer;
  String? _activeTenantId;
  String? _activeUserId;
  bool _workspacePushInFlight = false;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  bool _connectivityOffline = false;
  Timer? _outboxDebounce;
  Timer? _outboxPeriodic;
  bool _outboxReplaying = false;
  KpmsSyncVisualState? _priorSyncVisual;
  bool _bannerVisible = false;
  double _bannerOpacity = 0;
  Timer? _bannerShowDebounce;
  Timer? _bannerHideDebounce;
  bool _bootstrapReady = false;

  Future<void> _refreshSyncUi() async {
    if (!mounted) return;
    final tid = _activeTenantId ?? ref.read(kpmsActiveTenantIdProvider).valueOrNull;
    if (tid == null || tid.isEmpty) {
      ref.read(kpmsSyncUiProvider.notifier).reset();
      return;
    }
    final pending = await KpmsSyncOutboxService.pendingCountForTenant(tid);
    final failed = await KpmsSyncOutboxService.failedCountForTenant(tid);
    final retrying = await KpmsSyncOutboxService.hasPendingRetriesForTenant(tid);
    ref.read(kpmsSyncUiProvider.notifier).applyCounts(
          pending: pending,
          failed: failed,
          offline: _connectivityOffline,
          syncing: _workspacePushInFlight || _outboxReplaying,
          retrying: retrying && !_connectivityOffline && !_workspacePushInFlight && !_outboxReplaying,
        );
    _onSyncUiChanged(ref.read(kpmsSyncUiProvider));
  }

  bool _isSyncSuccessTransition(KpmsSyncVisualState? from, KpmsSyncVisualState to) {
    if (to != KpmsSyncVisualState.idle || from == null) return false;
    return from == KpmsSyncVisualState.syncing ||
        from == KpmsSyncVisualState.pending ||
        from == KpmsSyncVisualState.retrying;
  }

  void _onSyncUiChanged(KpmsSyncUiState sync) {
    if (!mounted) return;
    final from = _priorSyncVisual;
    final to = sync.visual;

    if (to == KpmsSyncVisualState.retrying) {
      KpmsSyncLog.syncBannerRetrying();
    }

    if (_isSyncSuccessTransition(from, to)) {
      KpmsSyncLog.syncCompleted();
      final messenger = ScaffoldMessenger.maybeOf(context);
      if (messenger != null) {
        messenger.hideCurrentMaterialBanner();
        kpmsSnackSuccess(context, 'Synced to cloud');
      }
      unawaited(KpmsPharmacySuccessNotifications.syncCompleted(ref));
    }

    _priorSyncVisual = to;
    final shouldShow = _syncBannerLabel(sync).isNotEmpty;

    if (shouldShow) {
      _bannerHideDebounce?.cancel();
      _bannerShowDebounce?.cancel();
      _bannerShowDebounce = Timer(const Duration(milliseconds: 400), () {
        if (!mounted) return;
        if (_syncBannerLabel(ref.read(kpmsSyncUiProvider)).isEmpty) return;
        setState(() {
          _bannerVisible = true;
          _bannerOpacity = 1;
        });
      });
      return;
    }

    _bannerShowDebounce?.cancel();
    if (!_bannerVisible) {
      KpmsSyncLog.syncBannerHidden();
      return;
    }
    setState(() => _bannerOpacity = 0);
    _bannerHideDebounce?.cancel();
    _bannerHideDebounce = Timer(const Duration(milliseconds: 220), () {
      if (!mounted) return;
      setState(() => _bannerVisible = false);
      KpmsSyncLog.syncBannerHidden();
    });
  }

  void _scheduleOutboxReplay() {
    _outboxDebounce?.cancel();
    _outboxDebounce = Timer(const Duration(seconds: 2), () {
      if (mounted) unawaited(_runOutbox());
    });
  }

  Future<void> _runOutbox() async {
    if (!mounted || _outboxReplaying) return;
    _outboxReplaying = true;
    await _refreshSyncUi();
    try {
      await KpmsSyncOutboxProcessor.processDue(ref);
    } finally {
      _outboxReplaying = false;
      if (mounted) await _refreshSyncUi();
    }
  }

  String _syncBannerLabel(KpmsSyncUiState s) {
    switch (s.visual) {
      case KpmsSyncVisualState.idle:
        return '';
      case KpmsSyncVisualState.offline:
        return 'Offline — changes saved; will sync when online';
      case KpmsSyncVisualState.pending:
        return s.pendingCount > 0 ? 'Cloud sync pending (${s.pendingCount})' : 'Cloud sync pending';
      case KpmsSyncVisualState.syncing:
        return 'Syncing to cloud…';
      case KpmsSyncVisualState.failed:
        return s.failedCount > 0 ? 'Sync needs attention (${s.failedCount})' : 'Sync needs attention';
      case KpmsSyncVisualState.retrying:
        return 'Retrying sync…';
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        await KpmsSyncOutboxDb.instance;
        if (mounted) {
          final tid = ref.read(kpmsActiveTenantIdProvider).valueOrNull;
          if (tid != null && tid.isNotEmpty) {
            final p = await KpmsSyncOutboxService.pendingCountForTenant(tid);
            final f = await KpmsSyncOutboxService.failedCountForTenant(tid);
            KpmsSyncLog.queueRestored(p + f);
          } else {
            KpmsSyncLog.queueRestored(0);
          }
        }
      } catch (_) {}
      if (mounted) {
        unawaited(_refreshSyncUi());
        _scheduleOutboxReplay();
      }
    });
    _outboxPeriodic = Timer.periodic(const Duration(seconds: 45), (_) {
      if (mounted) unawaited(_runOutbox());
    });
    Connectivity().checkConnectivity().then((results) {
      if (!mounted) return;
      final offline = results.isEmpty || results.every((r) => r == ConnectivityResult.none);
      _connectivityOffline = offline;
      unawaited(_refreshSyncUi());
    });
    _connectivitySub = Connectivity().onConnectivityChanged.listen((results) {
      final offline = results.isEmpty || results.every((r) => r == ConnectivityResult.none);
      if (offline) {
        _connectivityOffline = true;
        unawaited(_refreshSyncUi());
        return;
      }
      if (_connectivityOffline) {
        _connectivityOffline = false;
        KpmsSyncLog.reconnectDetected();
        KpmsSyncLog.syncRetry('connectivity_restored: pull cloud then flush outbox');
        unawaited(_refreshSyncUi());
        ref.read(pharmacyWorkspaceBootstrapReadyProvider.notifier).state = false;
        ref.invalidate(pharmacyWorkspaceBootstrapProvider);
        _scheduleOutboxReplay();
      }
    });
  }

  void _schedulePersist() {
    if (!_bootstrapReady) {
      KpmsSyncLog.bootstrapGatedPush(allowed: false, reason: 'bootstrap_in_progress');
      return;
    }
    _localTimer?.cancel();
    _cloudTimer?.cancel();
    _localTimer = Timer(const Duration(milliseconds: 500), () => _saveLocal());
    _cloudTimer = Timer(const Duration(seconds: 2), () {
      unawaited(_runPushesSequential());
    });
  }

  Future<void> _saveLocal() async {
    if (!mounted) return;
    final tid = _activeTenantId ?? ref.read(kpmsActiveTenantIdProvider).valueOrNull;
    final uid = _activeUserId ?? ref.read(supabaseAuthUserIdProvider).valueOrNull;
    if (tid == null || tid.isEmpty) return;
    final loaded = ref.read(kpmsLoadedWorkspaceTenantProvider);
    if (!assertActiveTenantForPersistence(tid, userId: uid, loadedWorkspaceTenantId: loaded)) return;

    if (loaded != null && loaded != tid) {
      KpmsTenantLog.crossTenantProtection('blocked local save: loaded=$loaded active=$tid');
      return;
    }

    await KpmsPharmacyWorkspaceStore.save(
      tenantId: tid,
      userId: uid,
      medicines: ref.read(medicineCatalogProvider),
      sales: ref.read(salesLedgerProvider),
      purchases: ref.read(purchaseLedgerProvider),
      debtCustomers: ref.read(debtCustomersProvider),
      suppliers: ref.read(suppliersProvider),
    );

    await PharmacyEnterpriseLocalStore.save(
      tenantId: tid,
      userId: uid,
      expenses: ref.read(pharmacyExpensesProvider),
      categories: ref.read(medicineCategoriesProvider),
      barcodes: ref.read(productBarcodesProvider),
    );
  }

  Future<void> _runPushesSequential() async {
    if (!mounted) return;
    await _pushCloud();
    if (mounted) await _pushEnterpriseCloud();
  }

  Future<void> _pushEnterpriseCloud() async {
    if (!mounted) return;
    final tid = _activeTenantId ?? ref.read(kpmsActiveTenantIdProvider).valueOrNull;
    final uid = _activeUserId ?? ref.read(supabaseAuthUserIdProvider).valueOrNull;
    if (tid == null || tid.isEmpty) return;
    final loaded = ref.read(kpmsLoadedWorkspaceTenantProvider);
    if (!assertActiveTenantForPersistence(tid, userId: uid, loadedWorkspaceTenantId: loaded)) return;

    if (loaded != null && loaded != tid) return;

    if (_connectivityOffline) {
      await KpmsSyncOutboxService.enqueue(
        tenantId: tid,
        entityType: KpmsSyncEntityType.enterprise,
        operationType: KpmsSyncOperationType.upsert,
        payload: const {'reason': 'offline'},
      );
      await _refreshSyncUi();
      _scheduleOutboxReplay();
      return;
    }

    try {
      await ref.read(pharmacyEnterpriseSyncServiceProvider).pushToCloud(
            tenantId: tid,
            expenses: ref.read(pharmacyExpensesProvider),
            categories: ref.read(medicineCategoriesProvider),
            barcodes: ref.read(productBarcodesProvider),
            userId: uid,
          );
      await KpmsSyncOutboxService.clearPendingBulkForTenant(tid, entityType: KpmsSyncEntityType.enterprise);
      await _refreshSyncUi();
    } catch (e) {
      await KpmsSyncOutboxService.enqueue(
        tenantId: tid,
        entityType: KpmsSyncEntityType.enterprise,
        operationType: KpmsSyncOperationType.upsert,
        payload: {'reason': 'push_failed', 'error': e.toString()},
      );
      await _refreshSyncUi();
      _scheduleOutboxReplay();
    }
  }

  Future<void> _pushCloud() async {
    if (!mounted || _workspacePushInFlight || !_bootstrapReady) return;
    final tid = _activeTenantId ?? ref.read(kpmsActiveTenantIdProvider).valueOrNull;
    final uid = _activeUserId ?? ref.read(supabaseAuthUserIdProvider).valueOrNull;
    if (tid == null || tid.isEmpty) return;
    final loaded = ref.read(kpmsLoadedWorkspaceTenantProvider);
    if (!assertActiveTenantForPersistence(tid, userId: uid, loadedWorkspaceTenantId: loaded)) return;

    if (loaded != null && loaded != tid) {
      KpmsTenantLog.crossTenantProtection('blocked cloud push: loaded=$loaded active=$tid');
      return;
    }

    if (_connectivityOffline) {
      await KpmsSyncOutboxService.enqueue(
        tenantId: tid,
        entityType: KpmsSyncEntityType.workspace,
        operationType: KpmsSyncOperationType.upsert,
        payload: const {'reason': 'offline'},
      );
      await _refreshSyncUi();
      _scheduleOutboxReplay();
      return;
    }

    _workspacePushInFlight = true;
    await _refreshSyncUi();
    try {
      final pendingDeletes = List<String>.from(ref.read(pendingMedicineDeletionsProvider));
      await ref.read(pharmacyWorkspaceSyncServiceProvider).pushToCloud(
            tenantId: tid,
            medicines: ref.read(medicineCatalogProvider),
            sales: ref.read(salesLedgerProvider),
            purchases: ref.read(purchaseLedgerProvider),
            debtCustomers: ref.read(debtCustomersProvider),
            suppliers: ref.read(suppliersProvider),
            deletedMedicineClientIds: pendingDeletes,
          );
      if (pendingDeletes.isNotEmpty) {
        await ref.read(pendingMedicineDeletionsProvider.notifier).clearIds(pendingDeletes);
      }
      await KpmsSyncOutboxService.clearPendingBulkForTenant(tid, entityType: KpmsSyncEntityType.workspace);
      await _refreshSyncUi();
    } catch (e) {
      await KpmsSyncOutboxService.enqueue(
        tenantId: tid,
        entityType: KpmsSyncEntityType.workspace,
        operationType: KpmsSyncOperationType.upsert,
        payload: {'reason': 'push_failed', 'error': e.toString()},
      );
      await _refreshSyncUi();
      _scheduleOutboxReplay();
    } finally {
      _workspacePushInFlight = false;
      if (mounted) await _refreshSyncUi();
    }
  }

  @override
  void dispose() {
    _localTimer?.cancel();
    _cloudTimer?.cancel();
    _connectivitySub?.cancel();
    _outboxDebounce?.cancel();
    _outboxPeriodic?.cancel();
    _bannerShowDebounce?.cancel();
    _bannerHideDebounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final uid = ref.watch(supabaseAuthUserIdProvider).valueOrNull;
    final tid = ref.watch(kpmsActiveTenantIdProvider).valueOrNull;
    if (tid != null && tid.isNotEmpty) _activeTenantId = tid;
    if (uid != null) _activeUserId = uid;

    final bootstrap = ref.watch(pharmacyWorkspaceBootstrapProvider);
    bootstrap.when(
      data: (_) => _bootstrapReady = ref.read(pharmacyWorkspaceBootstrapReadyProvider),
      loading: () => _bootstrapReady = false,
      error: (_, _) => _bootstrapReady = ref.read(pharmacyWorkspaceBootstrapReadyProvider),
    );

    ref.listen(pharmacyWorkspaceBootstrapReadyProvider, (prev, next) {
      if (next && prev == false && mounted) {
        KpmsSyncLog.bootstrapGatedPush(allowed: true, reason: 'bootstrap_complete');
        _scheduleOutboxReplay();
      }
    });

    ref.listen(medicineCatalogProvider, (_, _) => _schedulePersist());
    ref.listen(salesLedgerProvider, (_, _) => _schedulePersist());
    ref.listen(purchaseLedgerProvider, (_, _) => _schedulePersist());
    ref.listen(debtCustomersProvider, (_, _) => _schedulePersist());
    ref.listen(suppliersProvider, (_, _) => _schedulePersist());
    ref.listen(pharmacyExpensesProvider, (_, _) => _schedulePersist());
    ref.listen(medicineCategoriesProvider, (_, _) => _schedulePersist());
    ref.listen(productBarcodesProvider, (_, _) => _schedulePersist());

    ref.listen(kpmsSyncUiProvider, (prev, next) => _onSyncUiChanged(next));

    final sync = ref.watch(kpmsSyncUiProvider);
    final banner = _bannerVisible ? _syncBannerLabel(sync) : '';
    final topInset = MediaQuery.paddingOf(context).top + kToolbarHeight;

    return Stack(
      fit: StackFit.passthrough,
      clipBehavior: Clip.none,
      children: [
        widget.child,
        if (banner.isNotEmpty)
          Positioned(
            top: topInset,
            left: 0,
            right: 0,
            child: IgnorePointer(
              ignoring: _bannerOpacity < 0.05,
              child: AnimatedOpacity(
                opacity: _bannerOpacity,
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOut,
                child: Material(
                  elevation: 1,
                  color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.95),
                  child: SafeArea(
                    top: false,
                    bottom: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 4, 12, 6),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 18,
                            height: 18,
                            child: sync.visual == KpmsSyncVisualState.syncing
                                ? CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Theme.of(context).colorScheme.primary,
                                  )
                                : Icon(
                                    sync.visual == KpmsSyncVisualState.offline
                                        ? Icons.cloud_off_outlined
                                        : sync.visual == KpmsSyncVisualState.failed
                                            ? Icons.error_outline_rounded
                                            : Icons.cloud_queue_rounded,
                                    size: 18,
                                    color: Theme.of(context).colorScheme.primary,
                                  ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              banner,
                              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    height: 1.2,
                                  ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
