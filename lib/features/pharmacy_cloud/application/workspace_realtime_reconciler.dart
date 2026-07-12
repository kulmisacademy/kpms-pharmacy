import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/sync/kpms_realtime_log.dart';
import '../../../core/sync/kpms_workspace_log.dart';
import '../../../core/sync/pharmacy_cloud_mapper.dart';
import '../../../core/sync/pharmacy_enterprise_mapper.dart';
import '../../../core/tenant/kpms_active_tenant_provider.dart';
import '../../../core/tenant/pharmacy_workspace_isolation.dart';
import '../../../providers/pharmacy_local_workspace.dart';
import '../../analytics/application/sales_analytics_notifier.dart';
import '../../debts/application/debt_customers_notifier.dart';
import '../../enterprise/application/medicine_categories_notifier.dart';
import '../../enterprise/application/pharmacy_expenses_notifier.dart';
import '../../enterprise/application/product_barcodes_notifier.dart';
import '../../medicines/data/medicine_catalog_notifier.dart';
import '../../purchases/application/purchase_ledger_notifier.dart';
import '../../sales/application/sales_ledger_notifier.dart';
import '../../sales/domain/completed_sale_invoice.dart';
import '../../suppliers/application/suppliers_notifier.dart';
import '../data/pharmacy_cloud_repository.dart';
import 'pharmacy_cloud_providers.dart';
import 'workspace_realtime_persist_scheduler.dart';

final workspaceRealtimeReconcilerProvider = Provider<WorkspaceRealtimeReconciler>((ref) {
  final reconciler = WorkspaceRealtimeReconciler(ref);
  ref.onDispose(reconciler.dispose);
  return reconciler;
});

/// Delta reconciliation for Supabase realtime → active Riverpod workspace (no bootstrap reload).
class WorkspaceRealtimeReconciler {
  WorkspaceRealtimeReconciler(this._ref);

  final Ref _ref;
  final Map<String, Timer> _saleRefetchTimers = {};
  final Map<String, Timer> _purchaseRefetchTimers = {};

  /// Serial FIFO chain so realtime events apply strictly in arrival
  /// (commit) order. Without this, each event was dispatched via
  /// `unawaited(...)` and async handlers (with awaited refetches) could
  /// interleave, letting a stale snapshot overwrite a newer one.
  Future<void> _queue = Future<void>.value();
  bool _disposed = false;

  WorkspaceRealtimePersistScheduler get _persist =>
      _ref.read(workspaceRealtimePersistSchedulerProvider);

  PharmacyCloudRepository get _cloud => _ref.read(pharmacyCloudRepositoryProvider);

  void dispose() {
    _disposed = true;
    for (final t in _saleRefetchTimers.values) {
      t.cancel();
    }
    for (final t in _purchaseRefetchTimers.values) {
      t.cancel();
    }
    _saleRefetchTimers.clear();
    _purchaseRefetchTimers.clear();
  }

  bool get _canPatch {
    if (!_ref.read(pharmacyWorkspaceBootstrapReadyProvider)) {
      KpmsRealtimeLog.patchDeferred(reason: 'bootstrap_not_ready');
      return false;
    }
    final tid = _ref.read(kpmsActiveTenantIdProvider).valueOrNull;
    final loaded = _ref.read(kpmsLoadedWorkspaceTenantProvider);
    if (tid == null || tid.isEmpty) return false;
    if (loaded != null && loaded != tid) {
      KpmsWorkspaceLog.patchSkipped(reason: 'tenant_mismatch', detail: 'loaded=$loaded active=$tid');
      return false;
    }
    return true;
  }

  String? _activeTenantId() => _ref.read(kpmsActiveTenantIdProvider).valueOrNull;

  static String? _tenantFromRow(Map<String, dynamic> row) {
    final t = row['tenant_id'];
    return t == null ? null : '$t'.trim();
  }

  static String? _clientIdFromRow(Map<String, dynamic> row) {
    final id = row['client_id'];
    return id == null ? null : '$id'.trim();
  }

  static String _opLabel(PostgresChangeEvent event) => switch (event) {
        PostgresChangeEvent.insert => 'INSERT',
        PostgresChangeEvent.update => 'UPDATE',
        PostgresChangeEvent.delete => 'DELETE',
        _ => 'ALL',
      };

  /// Entry point from [PharmacyWorkspaceRealtimeHost].
  ///
  /// Events are chained on a single serial queue so they apply in the exact
  /// order they were received (the realtime channel delivers them in commit
  /// order). This prevents out-of-order patches where a slower handler for an
  /// earlier event would otherwise finish after a later one.
  Future<void> onPostgresChange({
    required String table,
    required String tenantId,
    required PostgresChangePayload payload,
  }) {
    if (_disposed) return Future<void>.value();
    final next = _queue.then((_) {
      if (_disposed) return Future<void>.value();
      return _processChange(table: table, tenantId: tenantId, payload: payload);
    });
    // Keep the chain alive even if one handler throws.
    _queue = next.catchError((Object e, StackTrace s) {
      KpmsWorkspaceLog.patchSkipped(reason: 'reconcile_error', detail: '$table: $e');
    });
    return next;
  }

  /// Chain arbitrary realtime-driven work onto the serial queue so it never
  /// interleaves with [onPostgresChange] handlers (used by debounced refetches).
  void _enqueue(Future<void> Function() work) {
    if (_disposed) return;
    _queue = _queue.then((_) {
      if (_disposed) return Future<void>.value();
      return work();
    }).catchError((Object e, StackTrace s) {
      KpmsWorkspaceLog.patchSkipped(reason: 'reconcile_error', detail: 'refetch: $e');
    });
  }

  Future<void> _processChange({
    required String table,
    required String tenantId,
    required PostgresChangePayload payload,
  }) async {
    if (!_canPatch) return;
    if (tenantId != _activeTenantId()) {
      KpmsWorkspaceLog.patchSkipped(reason: 'tenant_leak_blocked', detail: table);
      return;
    }

    final op = payload.eventType;
    final opLabel = _opLabel(op);
    final row = op == PostgresChangeEvent.delete
        ? Map<String, dynamic>.from(payload.oldRecord)
        : Map<String, dynamic>.from(payload.newRecord);

    final rowTenant = _tenantFromRow(row);
    if (rowTenant != null && rowTenant != tenantId) {
      KpmsWorkspaceLog.patchSkipped(reason: 'row_tenant_mismatch', detail: rowTenant);
      return;
    }

    final clientId = _clientIdFromRow(row);
    KpmsRealtimeLog.eventReceived(
      table: table,
      tenantId: tenantId,
      op: opLabel,
      clientId: clientId,
    );
    KpmsWorkspaceLog.patchStarted(tenantId: tenantId, table: table, op: opLabel);

    switch (table) {
      case 'pharmacy_inventory':
        await _patchMedicine(tenantId, op, row);
      case 'pharmacy_sales':
        await _patchSaleHeader(tenantId, op, row);
      case 'pharmacy_sale_items':
        _scheduleSaleRefetch(tenantId, '${row['sale_client_id'] ?? ''}');
      case 'pharmacy_sale_returns':
        await _patchSaleReturn(tenantId, op, row);
      case 'pharmacy_purchases':
        await _patchPurchaseHeader(tenantId, op, row);
      case 'pharmacy_purchase_items':
        _schedulePurchaseRefetch(tenantId, '${row['purchase_client_id'] ?? ''}');
      case 'pharmacy_purchase_returns':
        await _patchPurchaseReturn(tenantId, op, row);
      case 'pharmacy_customers':
        await _patchCustomer(tenantId, op, row);
      case 'pharmacy_suppliers':
        await _patchSupplier(tenantId, op, row);
      case 'pharmacy_expenses':
        await _patchExpense(tenantId, op, row);
      case 'pharmacy_medicine_categories':
        await _patchCategory(tenantId, op, row);
      case 'pharmacy_product_barcodes':
        await _patchBarcode(tenantId, op, row);
      default:
        KpmsWorkspaceLog.patchSkipped(reason: 'unhandled_table', detail: table);
    }
  }

  void scheduleSaleRefetch(String tenantId, String saleClientId) =>
      _scheduleSaleRefetch(tenantId, saleClientId);

  void _scheduleSaleRefetch(String tenantId, String saleClientId) {
    if (saleClientId.isEmpty) return;
    KpmsRealtimeLog.saleRefetchScheduled(tenantId: tenantId, saleClientId: saleClientId);
    _saleRefetchTimers[saleClientId]?.cancel();
    _saleRefetchTimers[saleClientId] = Timer(const Duration(milliseconds: 350), () {
      _saleRefetchTimers.remove(saleClientId);
      _enqueue(() => _fetchAndPatchSale(tenantId, saleClientId));
    });
  }

  void _schedulePurchaseRefetch(String tenantId, String purchaseClientId) {
    if (purchaseClientId.isEmpty) return;
    _purchaseRefetchTimers[purchaseClientId]?.cancel();
    _purchaseRefetchTimers[purchaseClientId] = Timer(const Duration(milliseconds: 350), () {
      _purchaseRefetchTimers.remove(purchaseClientId);
      _enqueue(() => _fetchAndPatchPurchase(tenantId, purchaseClientId));
    });
  }

  Future<void> _fetchAndPatchSale(String tenantId, String clientId) async {
    if (!_canPatch) return;
    final inv = await _cloud.fetchSaleByClientId(tenantId, clientId);
    if (inv == null) {
      _ref.read(salesLedgerProvider.notifier).removeWorkspaceEntity(clientId);
      _rebuildAnalytics(tenantId);
      _persist.markWorkspaceDirty();
      return;
    }
    await _applySaleInvoice(tenantId, inv, op: PostgresChangeEvent.update);
  }

  Future<void> _fetchAndPatchPurchase(String tenantId, String clientId) async {
    if (!_canPatch) return;
    final inv = await _cloud.fetchPurchaseByClientId(tenantId, clientId);
    if (inv == null) {
      _ref.read(purchaseLedgerProvider.notifier).removeWorkspaceEntity(clientId);
      _persist.markWorkspaceDirty();
      return;
    }
    final applied = _ref.read(purchaseLedgerProvider.notifier).mergeWorkspaceEntity(inv);
    if (applied) {
      KpmsRealtimeLog.patchApplied(
        table: 'pharmacy_purchases',
        tenantId: tenantId,
        clientId: clientId,
        op: 'MERGE',
      );
      _persist.markWorkspaceDirty();
    }
  }

  Future<void> _patchMedicine(
    String tenantId,
    PostgresChangeEvent op,
    Map<String, dynamic> row,
  ) async {
    final clientId = _clientIdFromRow(row);
    if (clientId == null || clientId.isEmpty) return;

    if (op == PostgresChangeEvent.delete) {
      _ref.read(medicineCatalogProvider.notifier).removeWorkspaceEntity(clientId);
      KpmsRealtimeLog.patchApplied(
        table: 'pharmacy_inventory',
        tenantId: tenantId,
        clientId: clientId,
        op: 'DELETE',
      );
      _persist.markWorkspaceDirty();
      return;
    }

    final med = PharmacyCloudMapper.medicineFromRow(row);
    final applied = _ref.read(medicineCatalogProvider.notifier).mergeWorkspaceEntity(med);
    if (!applied) {
      KpmsRealtimeLog.duplicateIgnored(table: 'pharmacy_inventory', clientId: clientId);
      return;
    }
    KpmsRealtimeLog.inventoryReconciled(
      tenantId: tenantId,
      medicineId: med.id,
      qty: med.quantity,
    );
    KpmsRealtimeLog.patchApplied(
      table: 'pharmacy_inventory',
      tenantId: tenantId,
      clientId: clientId,
      op: _opLabel(op),
    );
    KpmsWorkspaceLog.providerUpdated(provider: 'medicineCatalogProvider', detail: med.id);
    _persist.markWorkspaceDirty();
  }

  Future<void> _patchSaleHeader(
    String tenantId,
    PostgresChangeEvent op,
    Map<String, dynamic> row,
  ) async {
    final clientId = _clientIdFromRow(row);
    if (clientId == null || clientId.isEmpty) return;

    if (op == PostgresChangeEvent.delete) {
      _ref.read(salesLedgerProvider.notifier).removeWorkspaceEntity(clientId);
      _rebuildAnalytics(tenantId);
      KpmsRealtimeLog.patchApplied(
        table: 'pharmacy_sales',
        tenantId: tenantId,
        clientId: clientId,
        op: 'DELETE',
      );
      _persist.markWorkspaceDirty();
      return;
    }

    final inv = PharmacyCloudMapper.saleFromRows(row, const []);
    if (inv == null || inv.lines.isEmpty) {
      final existing = _ref.read(salesLedgerProvider.notifier).invoiceByNumber(clientId);
      if (existing != null && existing.lines.isNotEmpty) {
        KpmsRealtimeLog.duplicateIgnored(
          table: 'pharmacy_sales',
          clientId: clientId,
          reason: 'header_without_items_existing_complete',
        );
        return;
      }
      _scheduleSaleRefetch(tenantId, clientId);
      return;
    }
    await _applySaleInvoice(tenantId, inv, op: op);
  }

  Future<void> _applySaleInvoice(
    String tenantId,
    CompletedSaleInvoice inv, {
    required PostgresChangeEvent op,
  }) async {
    final ledger = _ref.read(salesLedgerProvider.notifier);
    final existed = ledger.invoiceByNumber(inv.invoiceNumber) != null;
    final applied = ledger.mergeWorkspaceEntity(inv);
    if (!applied) {
      KpmsRealtimeLog.duplicateIgnored(
        table: 'pharmacy_sales',
        clientId: inv.invoiceNumber,
        reason: 'stale_or_equal',
      );
      return;
    }

    KpmsRealtimeLog.patchApplied(
      table: 'pharmacy_sales',
      tenantId: tenantId,
      clientId: inv.invoiceNumber,
      op: _opLabel(op),
    );
    KpmsWorkspaceLog.providerUpdated(
      provider: 'salesLedgerProvider',
      detail: inv.invoiceNumber,
    );

    _ref.read(salesAnalyticsProvider.notifier).applyRealtimeSale(
          ledger: _ref.read(salesLedgerProvider),
          invoice: inv,
          tenantId: tenantId,
          isNew: !existed,
        );
    KpmsRealtimeLog.providerUpdated(provider: 'salesAnalyticsProvider');

    _persist.markWorkspaceDirty();
  }

  Future<void> _patchSaleReturn(
    String tenantId,
    PostgresChangeEvent op,
    Map<String, dynamic> row,
  ) async {
    final clientId = _clientIdFromRow(row);
    if (clientId == null || clientId.isEmpty) return;

    if (op == PostgresChangeEvent.delete) {
      _ref.read(salesLedgerProvider.notifier).removeWorkspaceReturn(clientId);
      _rebuildAnalytics(tenantId);
      _persist.markWorkspaceDirty();
      return;
    }

    var record = PharmacyCloudMapper.saleReturnFromRow(row);
    if (record.lines.isEmpty) {
      final fetched = await _cloud.fetchSaleReturnByClientId(tenantId, clientId);
      if (fetched == null) return;
      record = fetched;
    }

    final applied = _ref.read(salesLedgerProvider.notifier).mergeWorkspaceReturn(record);
    if (!applied) {
      KpmsRealtimeLog.duplicateIgnored(table: 'pharmacy_sale_returns', clientId: clientId);
      return;
    }
    _ref.read(salesAnalyticsProvider.notifier).applyRealtimeReturn(
          record: record,
          tenantId: tenantId,
        );
    KpmsRealtimeLog.patchApplied(
      table: 'pharmacy_sale_returns',
      tenantId: tenantId,
      clientId: clientId,
      op: _opLabel(op),
    );
    _persist.markWorkspaceDirty();
  }

  Future<void> _patchPurchaseHeader(
    String tenantId,
    PostgresChangeEvent op,
    Map<String, dynamic> row,
  ) async {
    final clientId = _clientIdFromRow(row);
    if (clientId == null || clientId.isEmpty) return;

    if (op == PostgresChangeEvent.delete) {
      _ref.read(purchaseLedgerProvider.notifier).removeWorkspaceEntity(clientId);
      _persist.markWorkspaceDirty();
      return;
    }

    final inv = PharmacyCloudMapper.purchaseFromRows(row, const []);
    if (inv == null || inv.lines.isEmpty) {
      final existing = _ref.read(purchaseLedgerProvider.notifier).invoiceByNumber(clientId);
      if (existing != null && existing.lines.isNotEmpty) {
        KpmsRealtimeLog.duplicateIgnored(
          table: 'pharmacy_purchases',
          clientId: clientId,
          reason: 'header_without_items_existing_complete',
        );
        return;
      }
      _schedulePurchaseRefetch(tenantId, clientId);
      return;
    }

    final applied = _ref.read(purchaseLedgerProvider.notifier).mergeWorkspaceEntity(inv);
    if (!applied) {
      KpmsRealtimeLog.duplicateIgnored(table: 'pharmacy_purchases', clientId: clientId);
      return;
    }
    KpmsRealtimeLog.patchApplied(
      table: 'pharmacy_purchases',
      tenantId: tenantId,
      clientId: clientId,
      op: _opLabel(op),
    );
    _persist.markWorkspaceDirty();
  }

  Future<void> _patchPurchaseReturn(
    String tenantId,
    PostgresChangeEvent op,
    Map<String, dynamic> row,
  ) async {
    final clientId = _clientIdFromRow(row);
    if (clientId == null || clientId.isEmpty) return;

    if (op == PostgresChangeEvent.delete) {
      _ref.read(purchaseLedgerProvider.notifier).removeWorkspaceReturn(clientId);
      _persist.markWorkspaceDirty();
      return;
    }

    var record = PharmacyCloudMapper.purchaseReturnFromRow(row);
    if (record.lines.isEmpty) {
      final fetched = await _cloud.fetchPurchaseReturnByClientId(tenantId, clientId);
      if (fetched == null) return;
      record = fetched;
    }

    final applied = _ref.read(purchaseLedgerProvider.notifier).mergeWorkspaceReturn(record);
    if (!applied) {
      KpmsRealtimeLog.duplicateIgnored(table: 'pharmacy_purchase_returns', clientId: clientId);
      return;
    }
    KpmsRealtimeLog.patchApplied(
      table: 'pharmacy_purchase_returns',
      tenantId: tenantId,
      clientId: clientId,
      op: _opLabel(op),
    );
    _persist.markWorkspaceDirty();
  }

  Future<void> _patchCustomer(
    String tenantId,
    PostgresChangeEvent op,
    Map<String, dynamic> row,
  ) async {
    final clientId = _clientIdFromRow(row);
    if (clientId == null || clientId.isEmpty) return;

    if (op == PostgresChangeEvent.delete) {
      _ref.read(debtCustomersProvider.notifier).removeWorkspaceEntity(clientId);
      _persist.markWorkspaceDirty();
      return;
    }

    final c = PharmacyCloudMapper.customerFromRow(row);
    final applied = _ref.read(debtCustomersProvider.notifier).mergeWorkspaceEntity(c);
    if (!applied) {
      KpmsRealtimeLog.duplicateIgnored(table: 'pharmacy_customers', clientId: clientId);
      return;
    }
    KpmsRealtimeLog.patchApplied(
      table: 'pharmacy_customers',
      tenantId: tenantId,
      clientId: clientId,
      op: _opLabel(op),
    );
    _persist.markWorkspaceDirty();
  }

  Future<void> _patchSupplier(
    String tenantId,
    PostgresChangeEvent op,
    Map<String, dynamic> row,
  ) async {
    final clientId = _clientIdFromRow(row);
    if (clientId == null || clientId.isEmpty) return;

    if (op == PostgresChangeEvent.delete) {
      _ref.read(suppliersProvider.notifier).removeWorkspaceEntity(clientId);
      _persist.markWorkspaceDirty();
      return;
    }

    final s = PharmacyCloudMapper.supplierFromRow(row);
    final applied = _ref.read(suppliersProvider.notifier).mergeWorkspaceEntity(s);
    if (!applied) {
      KpmsRealtimeLog.duplicateIgnored(table: 'pharmacy_suppliers', clientId: clientId);
      return;
    }
    KpmsRealtimeLog.patchApplied(
      table: 'pharmacy_suppliers',
      tenantId: tenantId,
      clientId: clientId,
      op: _opLabel(op),
    );
    _persist.markWorkspaceDirty();
  }

  Future<void> _patchExpense(
    String tenantId,
    PostgresChangeEvent op,
    Map<String, dynamic> row,
  ) async {
    final clientId = _clientIdFromRow(row);
    if (clientId == null || clientId.isEmpty) return;

    if (op == PostgresChangeEvent.delete) {
      _ref.read(pharmacyExpensesProvider.notifier).removeWorkspaceEntity(clientId);
      _persist.markEnterpriseDirty();
      return;
    }

    final e = PharmacyEnterpriseMapper.expenseFromRow(row);
    _ref.read(pharmacyExpensesProvider.notifier).mergeWorkspaceEntity(e);
    KpmsRealtimeLog.patchApplied(
      table: 'pharmacy_expenses',
      tenantId: tenantId,
      clientId: clientId,
      op: _opLabel(op),
    );
    _persist.markEnterpriseDirty();
  }

  Future<void> _patchCategory(
    String tenantId,
    PostgresChangeEvent op,
    Map<String, dynamic> row,
  ) async {
    final clientId = _clientIdFromRow(row);
    if (clientId == null || clientId.isEmpty) return;

    if (op == PostgresChangeEvent.delete) {
      _ref.read(medicineCategoriesProvider.notifier).removeWorkspaceEntity(clientId);
      _persist.markEnterpriseDirty();
      return;
    }

    final c = PharmacyEnterpriseMapper.categoryFromRow(row);
    _ref.read(medicineCategoriesProvider.notifier).mergeWorkspaceEntity(c);
    KpmsRealtimeLog.patchApplied(
      table: 'pharmacy_medicine_categories',
      tenantId: tenantId,
      clientId: clientId,
      op: _opLabel(op),
    );
    _persist.markEnterpriseDirty();
  }

  Future<void> _patchBarcode(
    String tenantId,
    PostgresChangeEvent op,
    Map<String, dynamic> row,
  ) async {
    final clientId = _clientIdFromRow(row);
    if (clientId == null || clientId.isEmpty) return;

    if (op == PostgresChangeEvent.delete) {
      _ref.read(productBarcodesProvider.notifier).removeWorkspaceEntity(clientId);
      _persist.markEnterpriseDirty();
      return;
    }

    final b = PharmacyEnterpriseMapper.barcodeFromRow(row);
    _ref.read(productBarcodesProvider.notifier).mergeWorkspaceEntity(b);
    KpmsRealtimeLog.patchApplied(
      table: 'pharmacy_product_barcodes',
      tenantId: tenantId,
      clientId: clientId,
      op: _opLabel(op),
    );
    _persist.markEnterpriseDirty();
  }

  void _rebuildAnalytics(String tenantId) {
    _ref.read(salesAnalyticsProvider.notifier).rebuildFromLedger(
          _ref.read(salesLedgerProvider),
          tenantId: tenantId,
        );
  }
}
