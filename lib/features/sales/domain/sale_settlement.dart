/// How a POS sale was settled at checkout (cash vs customer credit).
enum SaleSettlementMode {
  paidInFull,
  partialDebt,
  fullDebt,
}

extension SaleSettlementModeLabel on SaleSettlementMode {
  String get shortLabel => switch (this) {
        SaleSettlementMode.paidInFull => 'Paid in full',
        SaleSettlementMode.partialDebt => 'Partial payment',
        SaleSettlementMode.fullDebt => 'Credit',
      };
}

/// One line on a sale invoice’s debt ledger (checkout payment or later debt payment).
class SaleDebtLedgerEntry {
  const SaleDebtLedgerEntry({
    required this.recordedAt,
    required this.amount,
    required this.label,
  });

  final DateTime recordedAt;
  final double amount;
  final String label;
}
