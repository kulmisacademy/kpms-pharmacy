import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/audit/pharmacy_audit_hooks.dart';
import '../../../core/sync/kpms_sync_log.dart';
import '../../../core/tenant/kpms_active_tenant_provider.dart';
import '../../analytics/application/sales_analytics_notifier.dart';
import '../../medicines/data/medicine_catalog_notifier.dart';
import '../domain/completed_sale_invoice.dart';
import '../domain/sale_settlement.dart';

final salesLedgerProvider =
    StateNotifierProvider<SalesLedgerNotifier, SalesLedgerState>((ref) {
  return SalesLedgerNotifier(ref);
});

class SalesLedgerState {
  const SalesLedgerState({
    this.invoices = const [],
    this.returns = const [],
  });

  final List<CompletedSaleInvoice> invoices;
  final List<SalesReturnRecord> returns;

  SalesLedgerState copyWith({
    List<CompletedSaleInvoice>? invoices,
    List<SalesReturnRecord>? returns,
  }) {
    return SalesLedgerState(
      invoices: invoices ?? this.invoices,
      returns: returns ?? this.returns,
    );
  }
}

class SalesLedgerNotifier extends StateNotifier<SalesLedgerState> {
  SalesLedgerNotifier(this._ref) : super(const SalesLedgerState());

  final Ref _ref;

  void hydrate(SalesLedgerState next) {
    state = next;
  }

  /// Full ledger replace (bootstrap only — not for realtime).
  void reconcileWorkspace(SalesLedgerState remote) {
    hydrate(remote);
  }

  /// Upsert by invoice number; returns true when memory changed.
  bool mergeWorkspaceEntity(CompletedSaleInvoice incoming) {
    final idx = state.invoices.indexWhere((i) => i.invoiceNumber == incoming.invoiceNumber);
    if (idx < 0) {
      final next = [incoming, ...state.invoices]
        ..sort((a, b) => b.issuedAt.compareTo(a.issuedAt));
      state = state.copyWith(invoices: next);
      return true;
    }
    final existing = state.invoices[idx];
    if (existing.issuedAt.isAfter(incoming.issuedAt)) return false;
    if (existing.issuedAt == incoming.issuedAt &&
        existing.total == incoming.total &&
        existing.paidTowardInvoice == incoming.paidTowardInvoice &&
        existing.lines.length == incoming.lines.length) {
      return false;
    }
    final next = [...state.invoices];
    next[idx] = incoming;
    next.sort((a, b) => b.issuedAt.compareTo(a.issuedAt));
    state = state.copyWith(invoices: next);
    return true;
  }

  bool mergeWorkspaceReturn(SalesReturnRecord incoming) {
    final idx = state.returns.indexWhere((r) => r.returnInvoiceNumber == incoming.returnInvoiceNumber);
    if (idx < 0) {
      state = state.copyWith(returns: [incoming, ...state.returns]);
      return true;
    }
    final existing = state.returns[idx];
    if (!existing.issuedAt.isBefore(incoming.issuedAt)) return false;
    final next = [...state.returns];
    next[idx] = incoming;
    state = state.copyWith(returns: next);
    return true;
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

  void addInvoice(CompletedSaleInvoice invoice) {
    state = state.copyWith(invoices: [invoice, ...state.invoices]);
    final tenantId = _ref.read(kpmsActiveTenantIdProvider).valueOrNull;
    if (tenantId != null && tenantId.isNotEmpty) {
      KpmsSyncLog.saleInsertLocal(
        tenantId: tenantId,
        invoiceNumber: invoice.invoiceNumber,
        total: invoice.total,
      );
    }
  }

  CompletedSaleInvoice? invoiceByNumber(String invoiceNumber) {
    for (final i in state.invoices) {
      if (i.invoiceNumber == invoiceNumber) return i;
    }
    return null;
  }

  SalesReturnRecord? returnByNumber(String returnInvoiceNumber) {
    for (final r in state.returns) {
      if (r.returnInvoiceNumber == returnInvoiceNumber) return r;
    }
    return null;
  }

  List<CompletedSaleInvoice> invoicesForDebtCustomer(String debtCustomerId) {
    final list =
        state.invoices.where((i) => i.debtCustomerId == debtCustomerId).toList();
    list.sort((a, b) => b.issuedAt.compareTo(a.issuedAt));
    return list;
  }

  double openDebtTotalForCustomer(String debtCustomerId) {
    return state.invoices
        .where((i) => i.debtCustomerId == debtCustomerId && i.remainingBalance > 0.009)
        .fold(0.0, (s, i) => s + i.remainingBalance);
  }

  double lifetimePaidForCustomer(String debtCustomerId) {
    return state.invoices
        .where((i) => i.debtCustomerId == debtCustomerId)
        .fold(0.0, (s, i) => s + i.paidTowardInvoice);
  }

  /// Applies a payment across open invoices (oldest balance first). Returns `null` on success.
  String? applyCustomerDebtPayment({
    required String debtCustomerId,
    required double amount,
    String note = '',
  }) {
    if (amount <= 0.009) return 'Enter a positive amount.';
    final open = state.invoices
        .where((i) =>
            i.debtCustomerId == debtCustomerId && i.remainingBalance > 0.009)
        .toList()
      ..sort((a, b) => a.issuedAt.compareTo(b.issuedAt));

    final totalOpen =
        open.fold(0.0, (s, i) => s + i.remainingBalance);
    if (totalOpen <= 0.009) return 'No open balance for this customer.';
    if (amount > totalOpen + 0.02) {
      return 'Amount exceeds open balance (\$${totalOpen.toStringAsFixed(2)}).';
    }

    var remaining = amount;
    final now = DateTime.now();
    final label = note.trim().isEmpty ? 'Debt payment' : note.trim();
    final byNumber = <String, CompletedSaleInvoice>{
      for (final inv in state.invoices) inv.invoiceNumber: inv,
    };

    for (final inv in open) {
      if (remaining <= 0.009) break;
      final pay = inv.remainingBalance < remaining ? inv.remainingBalance : remaining;
      remaining -= pay;
      final entry = SaleDebtLedgerEntry(
        recordedAt: now,
        amount: pay,
        label: label,
      );
      final cur = byNumber[inv.invoiceNumber]!;
      byNumber[inv.invoiceNumber] = cur.copyWith(
        paidTowardInvoice: cur.paidTowardInvoice + pay,
        remainingBalance: (cur.remainingBalance - pay).clamp(0.0, double.infinity),
        debtLedger: [...cur.debtLedger, entry],
      );
    }

    state = state.copyWith(
      invoices: [
        for (final inv in state.invoices) byNumber[inv.invoiceNumber] ?? inv,
      ],
    );
    return null;
  }

  List<CompletedSaleInvoice> searchInvoices(String raw) {
    final q = raw.trim().toLowerCase();
    if (q.isEmpty) {
      return state.invoices.take(25).toList(growable: false);
    }
    final digitsOnly = q.replaceAll(RegExp(r'\D'), '');
    return state.invoices.where((inv) {
      if (inv.invoiceNumber.toLowerCase().contains(q)) return true;
      if (inv.customerName.toLowerCase().contains(q)) return true;
      final phoneNorm = inv.customerPhone.replaceAll(RegExp(r'\D'), '');
      if (digitsOnly.isNotEmpty && phoneNorm.contains(digitsOnly)) return true;
      return false;
    }).take(50).toList(growable: false);
  }

  /// Returns `null` on success, or an error message.
  String? processReturn({
    required String invoiceNumber,
    required Map<String, int> returnQtyByLineId,
    required ReturnReason reason,
    required String notes,
    required String cashierName,
  }) {
    final invIndex =
        state.invoices.indexWhere((i) => i.invoiceNumber == invoiceNumber);
    if (invIndex < 0) return 'Invoice not found.';

    final inv = state.invoices[invIndex];
    if (inv.returnStatus == InvoiceReturnStatus.fullyReturned) {
      return 'This invoice is already fully returned.';
    }

    var hasAny = false;
    for (final e in returnQtyByLineId.entries) {
      if (e.value <= 0) continue;
      hasAny = true;
      SoldLineItem? line;
      for (final l in inv.lines) {
        if (l.lineId == e.key) {
          line = l;
          break;
        }
      }
      if (line == null) return 'Unknown line.';
      if (e.value > line.quantityRemaining) {
        return 'Return quantity exceeds remaining for ${line.name}.';
      }
    }
    if (!hasAny) return 'Select at least one item to return.';

    final stockDelta = <String, int>{};
    final snapshotLines = <SalesReturnLineSnapshot>[];
    var refundTotal = 0.0;
    var profitReduction = 0.0;

    final newLines = <SoldLineItem>[];
    for (final line in inv.lines) {
      final rq = returnQtyByLineId[line.lineId] ?? 0;
      if (rq > 0) {
        stockDelta[line.medicineId] = (stockDelta[line.medicineId] ?? 0) + rq;
        refundTotal += line.refundForReturnQty(rq);
        profitReduction += line.profitReductionForReturnQty(rq);
        snapshotLines.add(SalesReturnLineSnapshot(
          name: line.name,
          quantity: rq,
          unitSell: line.unitSell,
          lineRefund: line.refundForReturnQty(rq),
        ));
        newLines.add(line.copyWith(quantityReturned: line.quantityReturned + rq));
      } else {
        newLines.add(line);
      }
    }

    final updatedInv = inv.copyWith(lines: newLines);
    final nextInvoices = [...state.invoices];
    nextInvoices[invIndex] = updatedInv;

    final record = SalesReturnRecord(
      returnInvoiceNumber: SalesReturnRecord.generateReturnNumber(),
      originalInvoiceNumber: inv.invoiceNumber,
      issuedAt: DateTime.now(),
      cashierName: cashierName,
      reason: reason,
      notes: notes.trim(),
      lines: snapshotLines,
      refundTotal: refundTotal,
      profitReduction: profitReduction,
    );

    _ref.read(medicineCatalogProvider.notifier).applyReturnStock(stockDelta);
    final tenantId = _ref.read(kpmsActiveTenantIdProvider).valueOrNull;
    _ref.read(salesAnalyticsProvider.notifier).recordReturn(
          refundRevenue: refundTotal,
          profitReduction: profitReduction,
          tenantId: tenantId,
        );

    state = state.copyWith(
      invoices: nextInvoices,
      returns: [record, ...state.returns],
    );
    unawaited(PharmacyAuditHooks.saleReturn(
      returnNumber: record.returnInvoiceNumber,
      originalInvoice: inv.invoiceNumber,
      refundTotal: refundTotal,
    ));
    return null;
  }
}
