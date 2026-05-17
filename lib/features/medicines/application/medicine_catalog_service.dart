import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/audit/pharmacy_audit_hooks.dart';
import '../../../core/sync/kpms_sync_log.dart';
import '../../enterprise/application/product_barcodes_notifier.dart';
import '../../notifications/application/kpms_pharmacy_success_notifications.dart';
import '../../purchases/application/purchase_ledger_notifier.dart';
import '../../sales/application/sales_ledger_notifier.dart';
import '../data/medicine_catalog_notifier.dart';
import '../domain/medicine.dart';
import 'pending_medicine_deletions_notifier.dart';

/// Result of attempting to delete a catalog SKU.
enum MedicineDeleteResult {
  success,
  notFound,
}

abstract final class MedicineCatalogService {
  MedicineCatalogService._();

  static bool hasTransactionHistory(WidgetRef ref, String medicineId) {
    final sales = ref.read(salesLedgerProvider);
    for (final inv in sales.invoices) {
      for (final line in inv.lines) {
        if (line.medicineId == medicineId) return true;
      }
    }
    final purchases = ref.read(purchaseLedgerProvider);
    for (final inv in purchases.invoices) {
      for (final line in inv.lines) {
        if (line.medicineId == medicineId) return true;
      }
    }
    return false;
  }

  /// Non-blocking warnings shown in the delete confirmation dialog.
  static List<String> deleteWarnings(WidgetRef ref, Medicine medicine) {
    final warnings = <String>[];
    if (medicine.quantity > 0) {
      warnings.add('This medicine still has ${medicine.quantity} units in stock.');
    }
    if (hasTransactionHistory(ref, medicine.id)) {
      warnings.add('This medicine has sales or purchase history on record.');
    }
    return warnings;
  }

  static Future<MedicineDeleteResult> deleteMedicine(WidgetRef ref, String medicineId) async {
    final med = ref.read(medicineCatalogProvider.notifier).byId(medicineId);
    if (med == null) return MedicineDeleteResult.notFound;

    final snapshot = {
      'name': med.name,
      'quantity': med.quantity,
      'buying_price': med.buyingPrice,
      'selling_price': med.sellingPrice,
    };

    ref.read(medicineCatalogProvider.notifier).removeMedicine(medicineId);
    await ref.read(pendingMedicineDeletionsProvider.notifier).enqueue(medicineId);

    final barcodes = ref.read(productBarcodesProvider.notifier).forMedicine(medicineId);
    for (final b in barcodes) {
      ref.read(productBarcodesProvider.notifier).remove(b.id);
    }

    KpmsSyncLog.medicineDeleted(medicineId);
    unawaited(
      PharmacyAuditHooks.inventoryChange(
        action: 'medicine_deleted',
        medicineId: medicineId,
        previousData: snapshot,
      ),
    );
    unawaited(
      KpmsPharmacySuccessNotifications.medicineDeleted(
        ref,
        medicineName: med.name,
        medicineId: medicineId,
      ),
    );

    return MedicineDeleteResult.success;
  }

  static Future<void> recordMedicineUpdated(WidgetRef ref, Medicine medicine, {Map<String, dynamic>? previous}) async {
    KpmsSyncLog.medicineUpdated(medicine.id);
    unawaited(
      PharmacyAuditHooks.inventoryChange(
        action: 'medicine_updated',
        medicineId: medicine.id,
        previousData: previous,
        nextData: {
          'name': medicine.name,
          'quantity': medicine.quantity,
          'buying_price': medicine.buyingPrice,
          'selling_price': medicine.sellingPrice,
        },
      ),
    );
    unawaited(
      KpmsPharmacySuccessNotifications.medicineUpdated(
        ref,
        medicineName: medicine.name,
        medicineId: medicine.id,
      ),
    );
  }
}
