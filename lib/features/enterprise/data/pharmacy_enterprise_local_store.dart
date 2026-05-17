import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/persistence/kpms_persistence_log.dart';
import '../../../core/tenant/kpms_tenant_log.dart';
import '../../../core/tenant/pharmacy_workspace_isolation.dart';
import '../domain/medicine_category.dart';
import '../domain/pharmacy_expense.dart';
import '../domain/product_barcode.dart';

/// Tenant-scoped local cache for enterprise extension entities (offline-first).
abstract final class PharmacyEnterpriseLocalStore {
  PharmacyEnterpriseLocalStore._();

  static const int schemaVersion = 1;

  static String _key(String tenantId) => KpmsTenantStorageKeys.enterpriseBundle(tenantId);

  static Future<({
    List<PharmacyExpense> expenses,
    List<MedicineCategory> categories,
    List<ProductBarcode> barcodes,
  })?> load(String tenantId) async {
    final tid = tenantId.trim();
    if (tid.isEmpty) return null;

    KpmsTenantLog.tenantStorageKey(_key(tid));
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key(tid));
    if (raw == null || raw.trim().isEmpty) return null;

    try {
      final o = jsonDecode(raw);
      if (o is! Map) return null;
      final m = Map<String, dynamic>.from(o);
      if ((m['v'] as num?)?.toInt() != schemaVersion) return null;

      final expenses = [
        for (final e in (m['expenses'] as List? ?? const []))
          if (e is Map) PharmacyExpense.fromJson(Map<String, dynamic>.from(e)),
      ];
      final categories = [
        for (final e in (m['categories'] as List? ?? const []))
          if (e is Map) MedicineCategory.fromJson(Map<String, dynamic>.from(e)),
      ];
      final barcodes = [
        for (final e in (m['barcodes'] as List? ?? const []))
          if (e is Map) ProductBarcode.fromJson(Map<String, dynamic>.from(e)),
      ];

      KpmsPersistenceLog.workspaceLoaded(tenantId: tid, hasData: expenses.isNotEmpty || categories.isNotEmpty || barcodes.isNotEmpty);
      return (expenses: expenses, categories: categories, barcodes: barcodes);
    } catch (_) {
      return null;
    }
  }

  static Future<void> save({
    required String tenantId,
    required List<PharmacyExpense> expenses,
    required List<MedicineCategory> categories,
    required List<ProductBarcode> barcodes,
    String? userId,
  }) async {
    final tid = tenantId.trim();
    if (tid.isEmpty) return;
    if (userId != null && !assertActiveTenantForPersistence(tid, userId: userId)) return;

    final prefs = await SharedPreferences.getInstance();
    final key = _key(tid);
    KpmsTenantLog.tenantStorageKey(key);

    final incomingEmpty = expenses.isEmpty && categories.isEmpty && barcodes.isEmpty;
    if (incomingEmpty) {
      final existing = await load(tid);
      if (existing != null &&
          (existing.expenses.isNotEmpty || existing.categories.isNotEmpty || existing.barcodes.isNotEmpty)) {
        KpmsPersistenceLog.skippedEmptyWorkspaceOverwrite(tid);
        KpmsPersistenceLog.emptyOverwriteBlocked(tid);
        return;
      }
    }

    final json = jsonEncode({
      'v': schemaVersion,
      'expenses': expenses.map((e) => e.toJson()).toList(),
      'categories': categories.map((e) => e.toJson()).toList(),
      'barcodes': barcodes.map((e) => e.toJson()).toList(),
    });
    await prefs.setString(key, json);
    KpmsPersistenceLog.workspaceSaved(tenantId: tid);
  }
}
