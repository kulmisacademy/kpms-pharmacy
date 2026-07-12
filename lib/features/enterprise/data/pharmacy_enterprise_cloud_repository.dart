import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/performance/kpms_performance_log.dart';
import '../../../core/supabase/kpms_supabase_chunked_upsert.dart';
import '../../../core/supabase/kpms_supabase_paged_fetch.dart';
import '../../../core/supabase/supabase_bootstrap.dart';
import '../../../core/sync/kpms_sync_log.dart';
import '../../../core/sync/pharmacy_enterprise_mapper.dart';
import '../domain/medicine_category.dart';
import '../domain/pharmacy_expense.dart';
import '../domain/product_barcode.dart';

/// Cloud CRUD for enterprise extension tables (tenant-filtered).
class PharmacyEnterpriseCloudRepository {
  const PharmacyEnterpriseCloudRepository();

  SupabaseClient? get _client => SupabaseBootstrap.clientOrNull;

  Future<({
    List<PharmacyExpense> expenses,
    List<MedicineCategory> categories,
    List<ProductBarcode> barcodes,
  })?> pull(String tenantId) async {
    final c = _client;
    if (c == null) return null;

    KpmsSyncLog.pullStarted('enterprise:$tenantId');

    final sw = Stopwatch()..start();
    final results = await Future.wait([
      KpmsSupabasePagedFetch.fetchAllForTenant(
        table: 'pharmacy_expenses',
        tenantId: tenantId,
      ),
      KpmsSupabasePagedFetch.fetchAllForTenant(
        table: 'pharmacy_medicine_categories',
        tenantId: tenantId,
      ),
      KpmsSupabasePagedFetch.fetchAllForTenant(
        table: 'pharmacy_product_barcodes',
        tenantId: tenantId,
      ),
    ]);
    final expenseRows = results[0];
    final categoryRows = results[1];
    final barcodeRows = results[2];
    sw.stop();
    final rowEstimate = expenseRows.length + categoryRows.length + barcodeRows.length;
    KpmsPerformanceLog.pullCompleted(
      label: 'enterprise_workspace',
      ms: sw.elapsedMilliseconds,
      rowEstimate: rowEstimate,
    );
    if (sw.elapsedMilliseconds >= 800) {
      KpmsPerformanceLog.slowQuery(label: 'enterprise.pull', ms: sw.elapsedMilliseconds);
    }

    final expenses = [
      for (final r in expenseRows) PharmacyEnterpriseMapper.expenseFromRow(r),
    ]..sort((a, b) => b.issuedAt.compareTo(a.issuedAt));

    final categories = [
      for (final r in categoryRows) PharmacyEnterpriseMapper.categoryFromRow(r),
    ]..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

    final barcodes = [
      for (final r in barcodeRows) PharmacyEnterpriseMapper.barcodeFromRow(r),
    ];

    KpmsSyncLog.pullCompleted('enterprise:$tenantId');

    return (expenses: expenses, categories: categories, barcodes: barcodes);
  }

  Future<int> push({
    required String tenantId,
    required List<PharmacyExpense> expenses,
    required List<MedicineCategory> categories,
    required List<ProductBarcode> barcodes,
    String? createdBy,
  }) async {
    final c = _client;
    if (c == null) return 0;

    KpmsSyncLog.uploadStarted(tenantId: 'enterprise:$tenantId');
    var rows = 0;

    if (expenses.isNotEmpty) {
      rows += await KpmsSupabaseChunkedUpsert.upsertAll(
        client: c,
        table: 'pharmacy_expenses',
        rows: [for (final e in expenses) PharmacyEnterpriseMapper.expenseToRow(tenantId, e, createdBy: createdBy)],
        onConflict: 'tenant_id,client_id',
      );
    }

    if (categories.isNotEmpty) {
      rows += await KpmsSupabaseChunkedUpsert.upsertAll(
        client: c,
        table: 'pharmacy_medicine_categories',
        rows: [for (final x in categories) PharmacyEnterpriseMapper.categoryToRow(tenantId, x)],
        onConflict: 'tenant_id,client_id',
      );
    }

    if (barcodes.isNotEmpty) {
      rows += await KpmsSupabaseChunkedUpsert.upsertAll(
        client: c,
        table: 'pharmacy_product_barcodes',
        rows: [for (final b in barcodes) PharmacyEnterpriseMapper.barcodeToRow(tenantId, b)],
        onConflict: 'tenant_id,client_id',
      );
    }

    KpmsSyncLog.uploadCompleted(tenantId: 'enterprise:$tenantId', rows: rows);
    return rows;
  }

  Future<void> deleteExpense(String tenantId, String clientId) async {
    final c = _client;
    if (c == null) return;
    await c.from('pharmacy_expenses').delete().eq('tenant_id', tenantId).eq('client_id', clientId);
  }

  Future<void> deleteCategory(String tenantId, String clientId) async {
    final c = _client;
    if (c == null) return;
    await c.from('pharmacy_medicine_categories').delete().eq('tenant_id', tenantId).eq('client_id', clientId);
  }

  Future<void> deleteBarcode(String tenantId, String clientId) async {
    final c = _client;
    if (c == null) return;
    await c.from('pharmacy_product_barcodes').delete().eq('tenant_id', tenantId).eq('client_id', clientId);
  }
}
