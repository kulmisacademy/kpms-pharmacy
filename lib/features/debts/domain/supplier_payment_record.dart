/// Supplier payment toward outstanding purchase credit balance.
class SupplierPaymentRecord {
  const SupplierPaymentRecord({
    required this.id,
    required this.supplierId,
    required this.amount,
    required this.paidAt,
    this.note = '',
  });

  final String id;
  final String supplierId;
  final double amount;
  final DateTime paidAt;
  final String note;
}
