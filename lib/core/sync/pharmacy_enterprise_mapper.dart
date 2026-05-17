import '../../features/enterprise/domain/medicine_category.dart';
import '../../features/enterprise/domain/pharmacy_expense.dart';
import '../../features/enterprise/domain/product_barcode.dart';

/// Maps enterprise `pharmacy_*` extension tables ↔ domain models.
abstract final class PharmacyEnterpriseMapper {
  static Map<String, dynamic> expenseToRow(String tenantId, PharmacyExpense e, {String? createdBy}) => {
        'tenant_id': tenantId,
        'client_id': e.id,
        'category': e.category,
        'amount': e.amount,
        'note': e.note,
        'issued_at': e.issuedAt.toUtc().toIso8601String(),
        'created_by': createdBy ?? e.createdBy,
      };

  static PharmacyExpense expenseFromRow(Map<String, dynamic> r) => PharmacyExpense(
        id: '${r['client_id']}',
        category: '${r['category'] ?? 'general'}',
        amount: (r['amount'] as num?)?.toDouble() ?? 0,
        note: '${r['note'] ?? ''}',
        issuedAt: DateTime.tryParse('${r['issued_at']}') ?? DateTime.now(),
        createdBy: r['created_by'] as String?,
        createdAt: r['created_at'] != null ? DateTime.tryParse('${r['created_at']}') : null,
      );

  static Map<String, dynamic> categoryToRow(String tenantId, MedicineCategory c) => {
        'tenant_id': tenantId,
        'client_id': c.id,
        'name': c.name,
        'parent_client_id': c.parentId,
        'sort_order': c.sortOrder,
      };

  static MedicineCategory categoryFromRow(Map<String, dynamic> r) => MedicineCategory(
        id: '${r['client_id']}',
        name: '${r['name'] ?? ''}',
        parentId: r['parent_client_id'] as String?,
        sortOrder: (r['sort_order'] as num?)?.toInt() ?? 0,
      );

  static Map<String, dynamic> barcodeToRow(String tenantId, ProductBarcode b) => {
        'tenant_id': tenantId,
        'client_id': b.id,
        'barcode': ProductBarcode.normalize(b.barcode),
        'medicine_client_id': b.medicineId,
        'label': b.label,
      };

  static ProductBarcode barcodeFromRow(Map<String, dynamic> r) => ProductBarcode(
        id: '${r['client_id']}',
        barcode: ProductBarcode.normalize('${r['barcode'] ?? ''}'),
        medicineId: '${r['medicine_client_id'] ?? ''}',
        label: '${r['label'] ?? ''}',
      );
}
