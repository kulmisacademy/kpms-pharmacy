import '../../settings/domain/pharmacy_branding.dart';
import '../domain/completed_sale_invoice.dart';
import '../domain/sale_invoice.dart';
import '../domain/sale_settlement.dart';

/// Builds a print / dialog [SaleInvoice] from a ledger [CompletedSaleInvoice].
SaleInvoice saleInvoiceFromCompleted({
  required CompletedSaleInvoice ledger,
  required PharmacyBranding branding,
}) {
  final phone = ledger.customerPhone.trim();
  final customerPhoneReceipt = phone.isEmpty ? '—' : phone;
  return SaleInvoice(
    pharmacyName: branding.businessName,
    addressLine: branding.addressLine,
    phoneLine: branding.phoneLine,
    invoiceNumber: ledger.invoiceNumber,
    issuedAt: ledger.issuedAt,
    cashierLabel: ledger.cashierName,
    customerName: ledger.customerName,
    customerPhone: customerPhoneReceipt,
    paymentMethod: ledger.paymentMethod,
    lines: [
      for (final l in ledger.lines)
        SaleInvoiceLine(
          itemName: l.name,
          quantity: l.quantitySold,
          amount: l.quantitySold * l.unitSell,
        ),
    ],
    subtotal: ledger.subtotal,
    taxRate: ledger.taxRate,
    taxAmount: ledger.taxAmount,
    discountAmount: ledger.discountAmount,
    discountLabel: ledger.discountAmount > 0.009 ? 'Discount (Member)' : 'Discount',
    total: ledger.total,
    paidTowardBill: ledger.settlementMode == SaleSettlementMode.paidInFull ? null : ledger.paidTowardInvoice,
    balanceDueAfterSale: ledger.settlementMode == SaleSettlementMode.paidInFull ? null : ledger.remainingBalance,
    creditStatusLabel: ledger.settlementMode.shortLabel,
    receiptFooter: branding.receiptFooter,
    showReceiptQr: branding.showReceiptQr,
    logoUrl: branding.logoUrl,
  );
}
