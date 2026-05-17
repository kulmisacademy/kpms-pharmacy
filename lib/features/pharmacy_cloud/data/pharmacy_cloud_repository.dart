import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/persistence/kpms_pharmacy_workspace_store.dart';
import '../../../core/performance/kpms_performance_log.dart';
import '../../../core/supabase/kpms_supabase_paged_fetch.dart';
import '../../../core/supabase/supabase_bootstrap.dart';
import '../../../core/sync/kpms_sync_log.dart';
import '../../../core/sync/pharmacy_cloud_mapper.dart';
import '../../debts/domain/debt_customer.dart';
import '../../medicines/domain/medicine.dart';
import '../../purchases/application/purchase_ledger_notifier.dart';
import '../../purchases/domain/purchase_invoice.dart';
import '../../sales/application/sales_ledger_notifier.dart';
import '../../sales/domain/completed_sale_invoice.dart';
import '../../suppliers/domain/supplier.dart';

/// Cloud source of truth for pharmacy operational data (`pharmacy_*` tables).
class PharmacyCloudRepository {
  const PharmacyCloudRepository();

  SupabaseClient? get _client => SupabaseBootstrap.clientOrNull;

  Future<bool> hasCloudData(String tenantId) async {
    final c = _client;
    if (c == null) return false;
    final row = await c
        .from('pharmacy_inventory')
        .select('id')
        .eq('tenant_id', tenantId)
        .limit(1)
        .maybeSingle();
    return row != null;
  }

  Future<({
    List<Medicine> medicines,
    SalesLedgerState sales,
    PurchaseLedgerState purchases,
    List<DebtCustomer> debtCustomers,
    List<Supplier> suppliers,
  })?> pullWorkspace(String tenantId) async {
    final c = _client;
    if (c == null) return null;

    KpmsSyncLog.pullStarted(tenantId);

    final sw = Stopwatch()..start();
    final medRows = await KpmsSupabasePagedFetch.fetchAllForTenant(
      table: 'pharmacy_inventory',
      tenantId: tenantId,
    );
    final custRows = await KpmsSupabasePagedFetch.fetchAllForTenant(
      table: 'pharmacy_customers',
      tenantId: tenantId,
    );
    final supRows = await KpmsSupabasePagedFetch.fetchAllForTenant(
      table: 'pharmacy_suppliers',
      tenantId: tenantId,
    );
    final saleRows = await KpmsSupabasePagedFetch.fetchAllForTenant(
      table: 'pharmacy_sales',
      tenantId: tenantId,
    );
    final saleItemRows = await KpmsSupabasePagedFetch.fetchAllForTenant(
      table: 'pharmacy_sale_items',
      tenantId: tenantId,
    );
    final saleReturnRows = await KpmsSupabasePagedFetch.fetchAllForTenant(
      table: 'pharmacy_sale_returns',
      tenantId: tenantId,
    );
    final purchaseRows = await KpmsSupabasePagedFetch.fetchAllForTenant(
      table: 'pharmacy_purchases',
      tenantId: tenantId,
    );
    final purchaseItemRows = await KpmsSupabasePagedFetch.fetchAllForTenant(
      table: 'pharmacy_purchase_items',
      tenantId: tenantId,
    );
    final purchaseReturnRows = await KpmsSupabasePagedFetch.fetchAllForTenant(
      table: 'pharmacy_purchase_returns',
      tenantId: tenantId,
    );
    sw.stop();

    final rowEstimate = medRows.length +
        custRows.length +
        supRows.length +
        saleRows.length +
        saleItemRows.length +
        saleReturnRows.length +
        purchaseRows.length +
        purchaseItemRows.length +
        purchaseReturnRows.length;
    KpmsPerformanceLog.pullCompleted(
      label: 'pharmacy_workspace',
      ms: sw.elapsedMilliseconds,
      rowEstimate: rowEstimate,
    );
    if (sw.elapsedMilliseconds >= 800) {
      KpmsPerformanceLog.slowQuery(label: 'pullWorkspace', ms: sw.elapsedMilliseconds);
    }

    final medicines = [
      for (final r in medRows)
        PharmacyCloudMapper.medicineFromRow(r),
    ];

    final itemsBySale = <String, List<Map<String, dynamic>>>{};
    for (final m in saleItemRows) {
      final sid = '${m['sale_client_id']}';
      itemsBySale.putIfAbsent(sid, () => []).add(m);
    }

    final invoices = <CompletedSaleInvoice>[];
    for (final h in saleRows) {
      final inv = PharmacyCloudMapper.saleFromRows(h, itemsBySale['${h['client_id']}'] ?? const []);
      if (inv != null) invoices.add(inv);
    }
    invoices.sort((a, b) => b.issuedAt.compareTo(a.issuedAt));

    final saleReturns = [
      for (final r in saleReturnRows)
        PharmacyCloudMapper.saleReturnFromRow(r),
    ];

    final itemsByPurchase = <String, List<Map<String, dynamic>>>{};
    for (final m in purchaseItemRows) {
      final pid = '${m['purchase_client_id']}';
      itemsByPurchase.putIfAbsent(pid, () => []).add(m);
    }

    final purchases = <PurchaseInvoice>[];
    for (final h in purchaseRows) {
      final inv = PharmacyCloudMapper.purchaseFromRows(h, itemsByPurchase['${h['client_id']}'] ?? const []);
      if (inv != null) purchases.add(inv);
    }
    purchases.sort((a, b) => b.issuedAt.compareTo(a.issuedAt));

    final purchaseReturns = [
      for (final r in purchaseReturnRows)
        PharmacyCloudMapper.purchaseReturnFromRow(r),
    ];

    final debtCustomers = [
      for (final r in custRows)
        PharmacyCloudMapper.customerFromRow(r),
    ];

    final suppliers = [
      for (final r in supRows)
        PharmacyCloudMapper.supplierFromRow(r),
    ];

    KpmsSyncLog.pullCompleted(tenantId);

    return (
      medicines: medicines,
      sales: SalesLedgerState(invoices: invoices, returns: saleReturns),
      purchases: PurchaseLedgerState(invoices: purchases, returns: purchaseReturns),
      debtCustomers: debtCustomers,
      suppliers: suppliers,
    );
  }

  Future<int> pushWorkspace({
    required String tenantId,
    required List<Medicine> medicines,
    required SalesLedgerState sales,
    required PurchaseLedgerState purchases,
    required List<DebtCustomer> debtCustomers,
    required List<Supplier> suppliers,
  }) async {
    final c = _client;
    if (c == null) return 0;

    KpmsSyncLog.uploadStarted(tenantId: tenantId);
    var rows = 0;

    if (medicines.isNotEmpty) {
      await c.from('pharmacy_inventory').upsert(
        [for (final m in medicines) PharmacyCloudMapper.medicineToRow(tenantId, m)],
        onConflict: 'tenant_id,client_id',
      );
      rows += medicines.length;
    }

    if (debtCustomers.isNotEmpty) {
      await c.from('pharmacy_customers').upsert(
        [for (final x in debtCustomers) PharmacyCloudMapper.customerToRow(tenantId, x)],
        onConflict: 'tenant_id,client_id',
      );
      rows += debtCustomers.length;
    }

    if (suppliers.isNotEmpty) {
      await c.from('pharmacy_suppliers').upsert(
        [for (final x in suppliers) PharmacyCloudMapper.supplierToRow(tenantId, x)],
        onConflict: 'tenant_id,client_id',
      );
      rows += suppliers.length;
    }

    if (sales.invoices.isNotEmpty) {
      await c.from('pharmacy_sales').upsert(
        [for (final inv in sales.invoices) PharmacyCloudMapper.saleToRow(tenantId, inv)],
        onConflict: 'tenant_id,client_id',
      );
      rows += sales.invoices.length;

      final itemRows = <Map<String, dynamic>>[];
      for (final inv in sales.invoices) {
        itemRows.addAll(PharmacyCloudMapper.saleItemsToRows(tenantId, inv));
      }
      if (itemRows.isNotEmpty) {
        await c.from('pharmacy_sale_items').upsert(
          itemRows,
          onConflict: 'tenant_id,sale_client_id,line_client_id',
        );
        rows += itemRows.length;
      }
    }

    if (sales.returns.isNotEmpty) {
      await c.from('pharmacy_sale_returns').upsert(
        [for (final r in sales.returns) PharmacyCloudMapper.saleReturnToRow(tenantId, r)],
        onConflict: 'tenant_id,client_id',
      );
      rows += sales.returns.length;
    }

    if (purchases.invoices.isNotEmpty) {
      await c.from('pharmacy_purchases').upsert(
        [for (final inv in purchases.invoices) PharmacyCloudMapper.purchaseToRow(tenantId, inv)],
        onConflict: 'tenant_id,client_id',
      );
      rows += purchases.invoices.length;

      final itemRows = <Map<String, dynamic>>[];
      for (final inv in purchases.invoices) {
        itemRows.addAll(PharmacyCloudMapper.purchaseItemsToRows(tenantId, inv));
      }
      if (itemRows.isNotEmpty) {
        await c.from('pharmacy_purchase_items').upsert(
          itemRows,
          onConflict: 'tenant_id,purchase_client_id,line_client_id',
        );
        rows += itemRows.length;
      }
    }

    if (purchases.returns.isNotEmpty) {
      await c.from('pharmacy_purchase_returns').upsert(
        [for (final r in purchases.returns) PharmacyCloudMapper.purchaseReturnToRow(tenantId, r)],
        onConflict: 'tenant_id,client_id',
      );
      rows += purchases.returns.length;
    }

    KpmsSyncLog.uploadCompleted(tenantId: tenantId, rows: rows);
    return rows;
  }

  static bool localNeedsMigration({
    required List<Medicine> medicines,
    required SalesLedgerState sales,
    required PurchaseLedgerState purchases,
    required List<DebtCustomer> debtCustomers,
    required List<Supplier> suppliers,
  }) {
    return KpmsPharmacyWorkspaceStore.bundleHasBusinessData(
      medicines: medicines,
      sales: sales,
      purchases: purchases,
      debtCustomers: debtCustomers,
      suppliers: suppliers,
    );
  }
}
