import '../../medicines/domain/medicine_form_type.dart';

/// How the purchase was settled at save time.
enum PurchaseSettlementMode {
  paidInFull,
  partialPayment,
  onAccount,
}

extension PurchaseSettlementModeLabel on PurchaseSettlementMode {
  String get label => switch (this) {
        PurchaseSettlementMode.paidInFull => 'Paid in full',
        PurchaseSettlementMode.partialPayment => 'Partial payment',
        PurchaseSettlementMode.onAccount => 'On account (credit)',
      };
}

/// Saved line on a purchase invoice.
class PurchaseInvoiceLine {
  const PurchaseInvoiceLine({
    required this.medicineId,
    required this.name,
    required this.formType,
    this.customFormLabel,
    this.expiryDate,
    required this.quantity,
    required this.buyingPrice,
    required this.sellingPrice,
    required this.lineTotal,
  });

  final String medicineId;
  final String name;
  final MedicineFormType formType;
  final String? customFormLabel;
  final DateTime? expiryDate;
  final int quantity;
  final double buyingPrice;
  final double sellingPrice;
  final double lineTotal;

  String get typeLabel {
    if (formType == MedicineFormType.other && (customFormLabel?.trim().isNotEmpty ?? false)) {
      return customFormLabel!.trim();
    }
    return formType.label;
  }
}

class PurchaseInvoice {
  const PurchaseInvoice({
    required this.invoiceNumber,
    required this.issuedAt,
    required this.supplierId,
    required this.supplierName,
    required this.supplierPhone,
    required this.supplierAddress,
    required this.cashierName,
    required this.notes,
    required this.lines,
    required this.subtotal,
    required this.discount,
    required this.taxRate,
    required this.taxAmount,
    required this.grandTotal,
    required this.paidAmount,
    required this.remainingBalance,
    required this.settlementMode,
    required this.paymentMethod,
    this.returnCreditsApplied = 0,
    Map<String, int>? returnedQtyByMedicineId,
  }) : returnedQtyByMedicineId = returnedQtyByMedicineId ?? const {};

  final String invoiceNumber;
  final DateTime issuedAt;
  final String supplierId;
  final String supplierName;
  final String supplierPhone;
  final String supplierAddress;
  final String cashierName;
  final String notes;
  final List<PurchaseInvoiceLine> lines;
  final double subtotal;
  final double discount;
  final double taxRate;
  final double taxAmount;
  final double grandTotal;
  final double paidAmount;
  final double remainingBalance;
  final PurchaseSettlementMode settlementMode;
  final String paymentMethod;

  /// Cumulative supplier-credit applied against this invoice’s on-account balance.
  final double returnCreditsApplied;

  /// Cumulative units returned to supplier per catalog medicine id.
  final Map<String, int> returnedQtyByMedicineId;

  double get effectiveRemainingBalance =>
      (remainingBalance - returnCreditsApplied).clamp(0.0, double.infinity);

  int returnedQtyFor(String medicineId) => returnedQtyByMedicineId[medicineId] ?? 0;

  int remainingReturnableQty(PurchaseInvoiceLine line) =>
      (line.quantity - returnedQtyFor(line.medicineId)).clamp(0, line.quantity);

  String get paymentStatusLabel {
    if (grandTotal <= 0) return 'Paid';
    if (remainingBalance <= 0.009) return 'Paid';
    if (paidAmount <= 0.009) return 'Unpaid';
    return 'Partial';
  }

  /// Channel / settlement — for premium invoice header (aligned with POS methods).
  String get paymentTypeLabel {
    switch (settlementMode) {
      case PurchaseSettlementMode.onAccount:
        return 'Supplier credit';
      case PurchaseSettlementMode.partialPayment:
        if (paymentMethod.startsWith('Partial · ')) {
          return paymentMethod;
        }
        return paymentMethod.isEmpty ? 'Partial payment' : paymentMethod;
      case PurchaseSettlementMode.paidInFull:
        return paymentMethod;
    }
  }

  static String generateInvoiceNumber([DateTime? at]) {
    final now = at ?? DateTime.now();
    final seq = (now.microsecondsSinceEpoch % 1_000_000).toString().padLeft(6, '0');
    return 'PIN-${now.year}-$seq';
  }

  PurchaseInvoice copyWith({
    double? returnCreditsApplied,
    Map<String, int>? returnedQtyByMedicineId,
  }) {
    return PurchaseInvoice(
      invoiceNumber: invoiceNumber,
      issuedAt: issuedAt,
      supplierId: supplierId,
      supplierName: supplierName,
      supplierPhone: supplierPhone,
      supplierAddress: supplierAddress,
      cashierName: cashierName,
      notes: notes,
      lines: lines,
      subtotal: subtotal,
      discount: discount,
      taxRate: taxRate,
      taxAmount: taxAmount,
      grandTotal: grandTotal,
      paidAmount: paidAmount,
      remainingBalance: remainingBalance,
      settlementMode: settlementMode,
      paymentMethod: paymentMethod,
      returnCreditsApplied: returnCreditsApplied ?? this.returnCreditsApplied,
      returnedQtyByMedicineId: returnedQtyByMedicineId ?? Map<String, int>.from(this.returnedQtyByMedicineId),
    );
  }
}
