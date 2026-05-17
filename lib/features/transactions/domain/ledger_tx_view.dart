/// Row kind for the transactions register / exports.
enum LedgerTxKind {
  sale,
  saleReturn,
  purchase,
  purchaseReturn,
}

/// Flattened row for transactions register (from local ledgers until server sync).
class LedgerTxView {
  const LedgerTxView({
    required this.kind,
    required this.sortAt,
    required this.kindLabel,
    required this.reference,
    required this.party,
    required this.amount,
    required this.status,
    required this.staffLabel,
    required this.paymentMethod,
  });

  final LedgerTxKind kind;
  final DateTime sortAt;
  final String kindLabel;
  final String reference;
  final String party;
  final double amount;
  final String status;
  final String staffLabel;
  final String paymentMethod;

  String get whenLabel {
    final l = sortAt.toLocal();
    return '${l.year}-${l.month.toString().padLeft(2, '0')}-${l.day.toString().padLeft(2, '0')} '
        '${l.hour.toString().padLeft(2, '0')}:${l.minute.toString().padLeft(2, '0')}';
  }
}
