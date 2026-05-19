import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../medicines/data/medicine_catalog_notifier.dart';
import '../../suppliers/application/suppliers_notifier.dart';
import '../domain/purchase_invoice.dart';
import '../domain/purchase_return.dart';

final purchaseLedgerProvider =
    StateNotifierProvider<PurchaseLedgerNotifier, PurchaseLedgerState>((ref) {
  return PurchaseLedgerNotifier(ref);
});

class PurchaseLedgerState {
  const PurchaseLedgerState({
    this.invoices = const [],
    this.returns = const [],
  });

  final List<PurchaseInvoice> invoices;
  final List<PurchaseReturnRecord> returns;

  PurchaseLedgerState copyWith({
    List<PurchaseInvoice>? invoices,
    List<PurchaseReturnRecord>? returns,
  }) {
    return PurchaseLedgerState(
      invoices: invoices ?? this.invoices,
      returns: returns ?? this.returns,
    );
  }
}

class PurchaseLedgerNotifier extends StateNotifier<PurchaseLedgerState> {
  PurchaseLedgerNotifier(this._ref) : super(const PurchaseLedgerState());

  final Ref _ref;

  void hydrate(PurchaseLedgerState next) {
    state = next;
  }

  void reconcileWorkspace(PurchaseLedgerState remote) => hydrate(remote);

  bool mergeWorkspaceEntity(PurchaseInvoice incoming) {
    final idx = state.invoices.indexWhere((i) => i.invoiceNumber == incoming.invoiceNumber);
    if (idx < 0) {
      final next = [incoming, ...state.invoices]
        ..sort((a, b) => b.issuedAt.compareTo(a.issuedAt));
      state = state.copyWith(invoices: next);
      return true;
    }
    final existing = state.invoices[idx];
    if (existing.issuedAt.isAfter(incoming.issuedAt)) return false;
    if (existing.issuedAt == incoming.issuedAt && existing.grandTotal == incoming.grandTotal) {
      return false;
    }
    final next = [...state.invoices];
    next[idx] = incoming;
    next.sort((a, b) => b.issuedAt.compareTo(a.issuedAt));
    state = state.copyWith(invoices: next);
    return true;
  }

  bool mergeWorkspaceReturn(PurchaseReturnRecord incoming) {
    final idx = state.returns.indexWhere((r) => r.returnInvoiceNumber == incoming.returnInvoiceNumber);
    if (idx < 0) {
      state = state.copyWith(returns: [incoming, ...state.returns]);
      return true;
    }
    return false;
  }

  void removeWorkspaceEntity(String invoiceNumber) {
    state = state.copyWith(
      invoices: state.invoices.where((i) => i.invoiceNumber != invoiceNumber).toList(),
    );
  }

  void removeWorkspaceReturn(String returnInvoiceNumber) {
    state = state.copyWith(
      returns: state.returns.where((r) => r.returnInvoiceNumber != returnInvoiceNumber).toList(),
    );
  }

  /// Persists invoice, updates stock & pricing, updates supplier balance for credit.
  String? completePurchase(PurchaseInvoice invoice) {
    if (invoice.lines.isEmpty) return 'Add at least one medicine.';

    final stockLines = [
      for (final l in invoice.lines)
        PurchaseReceiveLine(
          medicineId: l.medicineId,
          quantityAdded: l.quantity,
          buyingPrice: l.buyingPrice,
          sellingPrice: l.sellingPrice,
          expiryDate: l.expiryDate,
        ),
    ];

    _ref.read(medicineCatalogProvider.notifier).receivePurchase(stockLines);

    if (invoice.remainingBalance > 0.009) {
      _ref.read(suppliersProvider.notifier).addBalanceOwed(
            invoice.supplierId,
            invoice.remainingBalance,
          );
    }

    state = state.copyWith(invoices: [invoice, ...state.invoices]);
    return null;
  }

  /// Invoice-based return: stock down, supplier AP reduced, purchase credit tracked.
  String? processPurchaseReturn({
    required String purchaseInvoiceNumber,
    required Map<String, int> returnQtyByMedicineId,
    required PurchaseReturnReason reason,
    required String notes,
  }) {
    final cleaned = <String, int>{};
    for (final e in returnQtyByMedicineId.entries) {
      if (e.value > 0) cleaned[e.key] = e.value;
    }
    if (cleaned.isEmpty) return 'Select quantities to return.';

    final idx = state.invoices.indexWhere((p) => p.invoiceNumber == purchaseInvoiceNumber);
    if (idx < 0) return 'Purchase invoice not found.';
    final purchase = state.invoices[idx];

    for (final e in cleaned.entries) {
      PurchaseInvoiceLine? line;
      for (final l in purchase.lines) {
        if (l.medicineId == e.key) {
          line = l;
          break;
        }
      }
      if (line == null) return 'Line not on this purchase.';
      final maxQ = purchase.remainingReturnableQty(line);
      if (e.value > maxQ) return 'Cannot return more than received for ${line.name}.';
    }

    var totalCost = 0.0;
    final snapshots = <PurchaseReturnLineSnapshot>[];
    for (final line in purchase.lines) {
      final q = cleaned[line.medicineId];
      if (q == null || q <= 0) continue;
      final unit = line.buyingPrice;
      final credit = unit * q;
      totalCost += credit;
      snapshots.add(
        PurchaseReturnLineSnapshot(
          medicineName: line.name,
          quantity: q,
          unitCost: unit,
          lineCredit: credit,
        ),
      );
    }

    if (snapshots.isEmpty) return 'Nothing to return.';

    final effectiveRemaining = purchase.effectiveRemainingBalance;
    final creditToInvoice = totalCost.clamp(0.0, effectiveRemaining);
    final supplier = _ref.read(suppliersProvider.notifier).byId(purchase.supplierId);
    final owed = supplier?.balanceOwed ?? 0.0;
    final supplierReduction = totalCost.clamp(0.0, owed);

    if (supplierReduction > 0.009) {
      _ref.read(suppliersProvider.notifier).reduceBalanceOwed(purchase.supplierId, supplierReduction);
    }

    _ref.read(medicineCatalogProvider.notifier).applySupplierReturn(cleaned);

    final mergedQty = Map<String, int>.from(purchase.returnedQtyByMedicineId);
    for (final e in cleaned.entries) {
      mergedQty[e.key] = (mergedQty[e.key] ?? 0) + e.value;
    }

    final updated = purchase.copyWith(
      returnCreditsApplied: purchase.returnCreditsApplied + creditToInvoice,
      returnedQtyByMedicineId: mergedQty,
    );

    final nextInvoices = [...state.invoices];
    nextInvoices[idx] = updated;

    final record = PurchaseReturnRecord(
      returnInvoiceNumber: PurchaseReturnRecord.generateReturnNumber(),
      sourcePurchaseNumber: purchase.invoiceNumber,
      issuedAt: DateTime.now(),
      supplierName: purchase.supplierName,
      reason: reason,
      notes: notes.trim(),
      lines: snapshots,
      totalCreditAtCost: totalCost,
      creditAppliedToInvoice: creditToInvoice,
      supplierBalanceReduced: supplierReduction,
    );

    state = state.copyWith(
      invoices: nextInvoices,
      returns: [record, ...state.returns],
    );
    return null;
  }

  List<PurchaseInvoice> search({
    required String query,
    String? supplierId,
    PurchasePaymentFilter payment = PurchasePaymentFilter.all,
    DateTime? fromDate,
    DateTime? toDate,
  }) {
    var list = state.invoices;
    final q = query.trim().toLowerCase();
    if (q.isNotEmpty) {
      list = list.where((p) {
        if (p.invoiceNumber.toLowerCase().contains(q)) return true;
        if (p.supplierName.toLowerCase().contains(q)) return true;
        return false;
      }).toList();
    }
    if (supplierId != null && supplierId.isNotEmpty) {
      list = list.where((p) => p.supplierId == supplierId).toList();
    }
    if (payment != PurchasePaymentFilter.all) {
      list = list.where((p) {
        final s = p.paymentStatusLabel;
        return switch (payment) {
          PurchasePaymentFilter.all => true,
          PurchasePaymentFilter.paid => s == 'Paid',
          PurchasePaymentFilter.partial => s == 'Partial',
          PurchasePaymentFilter.unpaid => s == 'Unpaid',
        };
      }).toList();
    }
    if (fromDate != null) {
      list = list.where((p) => !p.issuedAt.isBefore(fromDate)).toList();
    }
    if (toDate != null) {
      final end = DateTime(toDate.year, toDate.month, toDate.day, 23, 59, 59);
      list = list.where((p) => !p.issuedAt.isAfter(end)).toList();
    }
    return list;
  }

  PurchaseInvoice? invoiceByNumber(String invoiceNumber) {
    for (final p in state.invoices) {
      if (p.invoiceNumber == invoiceNumber) return p;
    }
    return null;
  }

  PurchaseReturnRecord? purchaseReturnByNumber(String returnInvoiceNumber) {
    for (final r in state.returns) {
      if (r.returnInvoiceNumber == returnInvoiceNumber) return r;
    }
    return null;
  }
}

enum PurchasePaymentFilter {
  all,
  paid,
  partial,
  unpaid,
}

extension PurchasePaymentFilterLabel on PurchasePaymentFilter {
  String get label => switch (this) {
        PurchasePaymentFilter.all => 'All',
        PurchasePaymentFilter.paid => 'Paid',
        PurchasePaymentFilter.partial => 'Partial',
        PurchasePaymentFilter.unpaid => 'Unpaid',
      };
}
