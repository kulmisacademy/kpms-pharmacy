/// Immutable POS sale snapshot for on-screen / print-ready invoice.
class SaleInvoiceLine {
  const SaleInvoiceLine({
    required this.itemName,
    required this.quantity,
    required this.amount,
  });

  final String itemName;
  final int quantity;
  final double amount;
}

class SaleInvoice {
  const SaleInvoice({
    required this.pharmacyName,
    required this.addressLine,
    required this.phoneLine,
    required this.invoiceNumber,
    required this.issuedAt,
    required this.cashierLabel,
    required this.customerName,
    required this.customerPhone,
    required this.paymentMethod,
    required this.lines,
    required this.subtotal,
    required this.taxRate,
    required this.taxAmount,
    required this.discountAmount,
    required this.discountLabel,
    required this.total,
    this.paidTowardBill,
    this.balanceDueAfterSale,
    this.creditStatusLabel,
    this.receiptFooter,
    this.showReceiptQr = true,
    this.logoUrl,
  });

  final String pharmacyName;
  final String addressLine;
  final String phoneLine;
  final String invoiceNumber;
  final DateTime issuedAt;
  final String cashierLabel;
  final String customerName;
  final String customerPhone;
  final String paymentMethod;
  final List<SaleInvoiceLine> lines;
  final double subtotal;
  final double taxRate;
  final double taxAmount;
  final double discountAmount;
  final String discountLabel;
  final double total;

  /// Amount collected at checkout toward this bill (null = legacy full cash receipt).
  final double? paidTowardBill;

  /// Remaining customer debt for this sale (null = none).
  final double? balanceDueAfterSale;

  /// Short label, e.g. "Paid in full" / "Partial credit" / "On account".
  final String? creditStatusLabel;

  /// Optional footer lines from pharmacy invoice settings (shown above thank-you).
  final String? receiptFooter;

  /// Whether to render the decorative barcode block on the receipt.
  final bool showReceiptQr;

  /// Public URL for pharmacy logo on receipt / PDF (optional).
  final String? logoUrl;

  static String generateInvoiceNumber([DateTime? at]) {
    final now = at ?? DateTime.now();
    final seq = (now.millisecondsSinceEpoch % 1_000_000).toString().padLeft(6, '0');
    return 'INV-${now.year}-$seq';
  }

  static String formatReceiptDate(DateTime d) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[d.month - 1]} ${d.day}, ${d.year}';
  }

  static String formatReceiptTime(DateTime d) {
    final h = d.hour.toString().padLeft(2, '0');
    final m = d.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}
