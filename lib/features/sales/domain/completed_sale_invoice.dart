// Ledger models for completed POS sales and returns (in-memory until Supabase).

import 'sale_settlement.dart';

enum InvoiceReturnStatus {
  none,
  partial,
  fullyReturned,
}

enum ReturnReason {
  wrongMedicine,
  damagedMedicine,
  customerChangedMind,
  expiredMedicine,
  other;

  String get label => switch (this) {
        ReturnReason.wrongMedicine => 'Wrong medicine',
        ReturnReason.damagedMedicine => 'Damaged medicine',
        ReturnReason.customerChangedMind => 'Customer changed mind',
        ReturnReason.expiredMedicine => 'Expired medicine',
        ReturnReason.other => 'Other',
      };
}

class SoldLineItem {
  const SoldLineItem({
    required this.lineId,
    required this.medicineId,
    required this.name,
    required this.quantitySold,
    required this.quantityReturned,
    required this.unitSell,
    required this.unitBuy,
  });

  final String lineId;
  final String medicineId;
  final String name;
  final int quantitySold;
  final int quantityReturned;
  final double unitSell;
  final double unitBuy;

  int get quantityRemaining => quantitySold - quantityReturned;

  double get lineSaleTotal => quantitySold * unitSell;

  double get marginPerUnit => unitSell - unitBuy;

  double get profitAtSale => quantitySold * marginPerUnit;

  double get profitRemaining => quantityRemaining * marginPerUnit;

  double refundForReturnQty(int qty) => unitSell * qty;

  double profitReductionForReturnQty(int qty) => marginPerUnit * qty;

  SoldLineItem copyWith({
    int? quantityReturned,
  }) {
    return SoldLineItem(
      lineId: lineId,
      medicineId: medicineId,
      name: name,
      quantitySold: quantitySold,
      quantityReturned: quantityReturned ?? this.quantityReturned,
      unitSell: unitSell,
      unitBuy: unitBuy,
    );
  }
}

class CompletedSaleInvoice {
  const CompletedSaleInvoice({
    required this.invoiceNumber,
    required this.issuedAt,
    required this.customerName,
    required this.customerPhone,
    required this.paymentMethod,
    required this.cashierName,
    required this.lines,
    required this.subtotal,
    required this.taxRate,
    required this.taxAmount,
    required this.discountAmount,
    required this.total,
    required this.profitAtSale,
    this.settlementMode = SaleSettlementMode.paidInFull,
    this.paidTowardInvoice = 0,
    this.remainingBalance = 0,
    this.debtCustomerId,
    this.debtCustomerNotes = '',
    this.debtLedger = const [],
    this.cashierUserId,
  });

  final String invoiceNumber;
  final DateTime issuedAt;
  final String customerName;
  final String customerPhone;
  final String paymentMethod;
  final String cashierName;
  final List<SoldLineItem> lines;
  final double subtotal;
  final double taxRate;
  final double taxAmount;
  final double discountAmount;
  final double total;
  final double profitAtSale;

  /// Auth user id of cashier when checkout ran (for staff stats / transactions).
  final String? cashierUserId;

  /// Cash vs partial / full customer credit.
  final SaleSettlementMode settlementMode;

  /// Cumulative amount applied to this invoice (checkout + debt payments).
  final double paidTowardInvoice;

  /// Amount still owed on this invoice (customer credit).
  final double remainingBalance;

  /// Links to [DebtCustomer] when sale created partial/full debt.
  final String? debtCustomerId;

  /// Optional notes captured at checkout for credit sales.
  final String debtCustomerNotes;

  /// Payment history toward this invoice (paid at sale + debt payments).
  final List<SaleDebtLedgerEntry> debtLedger;

  InvoiceReturnStatus get returnStatus {
    if (lines.every((l) => l.quantityReturned == 0)) {
      return InvoiceReturnStatus.none;
    }
    if (lines.every((l) => l.quantityReturned >= l.quantitySold)) {
      return InvoiceReturnStatus.fullyReturned;
    }
    return InvoiceReturnStatus.partial;
  }

  double get profitAfterReturns =>
      lines.fold(0.0, (s, l) => s + l.profitRemaining);

  double get totalReturnedUnits =>
      lines.fold(0, (s, l) => s + l.quantityReturned);

  bool get hasOpenDebt => remainingBalance > 0.009;

  DateTime? get lastDebtPaymentAt {
    if (debtLedger.isEmpty) return null;
    return debtLedger.last.recordedAt;
  }

  CompletedSaleInvoice copyWith({
    List<SoldLineItem>? lines,
    SaleSettlementMode? settlementMode,
    double? paidTowardInvoice,
    double? remainingBalance,
    String? debtCustomerId,
    String? debtCustomerNotes,
    List<SaleDebtLedgerEntry>? debtLedger,
    String? cashierUserId,
  }) {
    return CompletedSaleInvoice(
      invoiceNumber: invoiceNumber,
      issuedAt: issuedAt,
      customerName: customerName,
      customerPhone: customerPhone,
      paymentMethod: paymentMethod,
      cashierName: cashierName,
      lines: lines ?? this.lines,
      subtotal: subtotal,
      taxRate: taxRate,
      taxAmount: taxAmount,
      discountAmount: discountAmount,
      total: total,
      profitAtSale: profitAtSale,
      settlementMode: settlementMode ?? this.settlementMode,
      paidTowardInvoice: paidTowardInvoice ?? this.paidTowardInvoice,
      remainingBalance: remainingBalance ?? this.remainingBalance,
      debtCustomerId: debtCustomerId ?? this.debtCustomerId,
      debtCustomerNotes: debtCustomerNotes ?? this.debtCustomerNotes,
      debtLedger: debtLedger ?? this.debtLedger,
      cashierUserId: cashierUserId ?? this.cashierUserId,
    );
  }
}

class SalesReturnLineSnapshot {
  const SalesReturnLineSnapshot({
    required this.name,
    required this.quantity,
    required this.unitSell,
    required this.lineRefund,
  });

  final String name;
  final int quantity;
  final double unitSell;
  final double lineRefund;
}

class SalesReturnRecord {
  const SalesReturnRecord({
    required this.returnInvoiceNumber,
    required this.originalInvoiceNumber,
    required this.issuedAt,
    required this.cashierName,
    required this.reason,
    required this.notes,
    required this.lines,
    required this.refundTotal,
    required this.profitReduction,
  });

  final String returnInvoiceNumber;
  final String originalInvoiceNumber;
  final DateTime issuedAt;
  final String cashierName;
  final ReturnReason reason;
  final String notes;
  final List<SalesReturnLineSnapshot> lines;
  final double refundTotal;
  final double profitReduction;

  static String generateReturnNumber([DateTime? at]) {
    final now = at ?? DateTime.now();
    final seq = (now.microsecondsSinceEpoch % 1_000_000).toString().padLeft(6, '0');
    return 'RTN-${now.year}-$seq';
  }
}
