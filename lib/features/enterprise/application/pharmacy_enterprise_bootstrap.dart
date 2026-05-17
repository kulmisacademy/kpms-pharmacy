import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/permission_providers.dart';
import '../../../core/tenant/kpms_active_tenant_provider.dart';
import '../data/pharmacy_enterprise_local_store.dart';
import '../domain/medicine_category.dart';
import '../domain/pharmacy_expense.dart';
import '../domain/product_barcode.dart';
import 'medicine_categories_notifier.dart';
import 'pharmacy_enterprise_providers.dart';
import 'pharmacy_expenses_notifier.dart';
import 'product_barcodes_notifier.dart';

void _hydrateEnterprise(
  Ref ref, {
  required List<PharmacyExpense> expenses,
  required List<MedicineCategory> categories,
  required List<ProductBarcode> barcodes,
}) {
  ref.read(pharmacyExpensesProvider.notifier).replaceAll(expenses);
  ref.read(medicineCategoriesProvider.notifier).replaceAll(categories);
  ref.read(productBarcodesProvider.notifier).replaceAll(barcodes);
}

/// Loads enterprise extension data after tenant is resolved (local → cloud).
final pharmacyEnterpriseBootstrapProvider = FutureProvider<void>((ref) async {
  ref.watch(pharmacyEnterpriseSyncGenerationProvider);

  final uid = ref.watch(supabaseAuthUserIdProvider).valueOrNull;
  final tenantId = await ref.watch(kpmsActiveTenantIdProvider.future);

  if (uid == null || tenantId == null || tenantId.isEmpty) {
    _hydrateEnterprise(ref, expenses: const [], categories: const [], barcodes: const []);
    return;
  }

  final local = await PharmacyEnterpriseLocalStore.load(tenantId);
  final localExpenses = local?.expenses ?? const [];
  final localCategories = local?.categories ?? const [];
  final localBarcodes = local?.barcodes ?? const [];

  if (local != null) {
    _hydrateEnterprise(
      ref,
      expenses: localExpenses,
      categories: localCategories,
      barcodes: localBarcodes,
    );
  }

  final bundle = await ref.read(pharmacyEnterpriseSyncServiceProvider).bootstrap(
        tenantId: tenantId,
        localExpenses: localExpenses,
        localCategories: localCategories,
        localBarcodes: localBarcodes,
        userId: uid,
      );

  if (bundle != null) {
    _hydrateEnterprise(
      ref,
      expenses: bundle.expenses,
      categories: bundle.categories,
      barcodes: bundle.barcodes,
    );
  } else if (local == null) {
    _hydrateEnterprise(ref, expenses: const [], categories: const [], barcodes: const []);
  }
});
