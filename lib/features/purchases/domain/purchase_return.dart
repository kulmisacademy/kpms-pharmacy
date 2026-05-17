// Supplier purchase return (RMA) — mirrors sales return pattern; in-memory until Supabase.

enum PurchaseReturnReason {
  damaged,
  expired,
  wrongShipment,
  recall,
  other;

  String get label => switch (this) {
        PurchaseReturnReason.damaged => 'Damaged / unusable',
        PurchaseReturnReason.expired => 'Expired stock',
        PurchaseReturnReason.wrongShipment => 'Wrong shipment',
        PurchaseReturnReason.recall => 'Recall / batch issue',
        PurchaseReturnReason.other => 'Other',
      };
}

class PurchaseReturnLineSnapshot {
  const PurchaseReturnLineSnapshot({
    required this.medicineName,
    required this.quantity,
    required this.unitCost,
    required this.lineCredit,
  });

  final String medicineName;
  final int quantity;
  final double unitCost;
  final double lineCredit;
}

class PurchaseReturnRecord {
  const PurchaseReturnRecord({
    required this.returnInvoiceNumber,
    required this.sourcePurchaseNumber,
    required this.issuedAt,
    required this.supplierName,
    required this.reason,
    required this.notes,
    required this.lines,
    required this.totalCreditAtCost,
    required this.creditAppliedToInvoice,
    required this.supplierBalanceReduced,
  });

  final String returnInvoiceNumber;
  final String sourcePurchaseNumber;
  final DateTime issuedAt;
  final String supplierName;
  final PurchaseReturnReason reason;
  final String notes;
  final List<PurchaseReturnLineSnapshot> lines;
  final double totalCreditAtCost;
  final double creditAppliedToInvoice;
  final double supplierBalanceReduced;

  static String generateReturnNumber([DateTime? at]) {
    final now = at ?? DateTime.now();
    final seq = (now.microsecondsSinceEpoch % 1_000_000).toString().padLeft(6, '0');
    return 'PRT-${now.year}-$seq';
  }
}
