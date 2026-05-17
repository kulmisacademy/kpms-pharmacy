import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../purchases/application/purchase_ledger_notifier.dart';
import '../../sales/application/sales_ledger_notifier.dart';
import '../domain/ledger_tx_view.dart';

/// Flattened ledger rows for the transactions register — recomputes only when sales/purchase ledgers change.
final ledgerTxFlatProvider = Provider<List<LedgerTxView>>((ref) {
  final sales = ref.watch(salesLedgerProvider);
  final purch = ref.watch(purchaseLedgerProvider);
  final out = <LedgerTxView>[];
  for (final i in sales.invoices) {
    out.add(
      LedgerTxView(
        kind: LedgerTxKind.sale,
        sortAt: i.issuedAt,
        kindLabel: 'Sale',
        reference: i.invoiceNumber,
        party: i.customerName,
        amount: i.total,
        status: i.remainingBalance > 0.009 ? 'Open balance' : 'Settled',
        staffLabel: i.cashierName,
        paymentMethod: i.paymentMethod,
      ),
    );
  }
  for (final r in sales.returns) {
    out.add(
      LedgerTxView(
        kind: LedgerTxKind.saleReturn,
        sortAt: r.issuedAt,
        kindLabel: 'Sale return',
        reference: r.returnInvoiceNumber,
        party: r.originalInvoiceNumber,
        amount: -r.refundTotal,
        status: 'Posted',
        staffLabel: r.cashierName,
        paymentMethod: 'Refund',
      ),
    );
  }
  for (final i in purch.invoices) {
    out.add(
      LedgerTxView(
        kind: LedgerTxKind.purchase,
        sortAt: i.issuedAt,
        kindLabel: 'Purchase',
        reference: i.invoiceNumber,
        party: i.supplierName,
        amount: i.grandTotal,
        status: i.paymentStatusLabel,
        staffLabel: i.cashierName,
        paymentMethod: i.paymentMethod,
      ),
    );
  }
  for (final r in purch.returns) {
    out.add(
      LedgerTxView(
        kind: LedgerTxKind.purchaseReturn,
        sortAt: r.issuedAt,
        kindLabel: 'Purchase return',
        reference: r.returnInvoiceNumber,
        party: r.supplierName,
        amount: -r.totalCreditAtCost,
        status: 'Posted',
        staffLabel: '—',
        paymentMethod: 'Supplier credit',
      ),
    );
  }
  out.sort((a, b) => b.sortAt.compareTo(a.sortAt));
  return out;
});
