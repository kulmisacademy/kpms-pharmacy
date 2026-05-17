import '../../features/debts/domain/debt_customer.dart';
import '../../features/medicines/domain/medicine.dart';
import '../../features/medicines/domain/medicine_form_type.dart';
import '../../features/purchases/domain/purchase_invoice.dart';
import '../../features/purchases/domain/purchase_return.dart';
import '../../features/sales/domain/completed_sale_invoice.dart';
import '../../features/sales/domain/sale_settlement.dart';
import '../../features/suppliers/domain/supplier.dart';

/// Maps domain models ↔ Supabase `pharmacy_*` rows.
abstract final class PharmacyCloudMapper {
  static Map<String, dynamic> medicineToRow(String tenantId, Medicine m) => {
        'tenant_id': tenantId,
        'client_id': m.id,
        'name': m.name,
        'expiry_date': m.expiryDate?.toUtc().toIso8601String(),
        'form_type': m.formType.name,
        'custom_form_label': m.customFormLabel,
        'quantity': m.quantity,
        'buying_price': m.buyingPrice,
        'selling_price': m.sellingPrice,
        'minimum_stock_alert': m.minimumStockAlert,
        'batch_code': m.batchCode,
        'barcode': m.barcode,
      };

  static Medicine medicineFromRow(Map<String, dynamic> r) {
    MedicineFormType form;
    try {
      form = MedicineFormType.values.byName('${r['form_type']}');
    } catch (_) {
      form = MedicineFormType.tablet;
    }
    return Medicine(
      id: '${r['client_id']}',
      name: '${r['name'] ?? ''}',
      expiryDate: r['expiry_date'] != null ? DateTime.tryParse('${r['expiry_date']}') : null,
      formType: form,
      customFormLabel: r['custom_form_label'] as String?,
      quantity: (r['quantity'] as num?)?.toInt() ?? 0,
      buyingPrice: (r['buying_price'] as num?)?.toDouble() ?? 0,
      sellingPrice: (r['selling_price'] as num?)?.toDouble() ?? 0,
      minimumStockAlert: (r['minimum_stock_alert'] as num?)?.toInt() ?? 0,
      batchCode: r['batch_code'] as String?,
      barcode: r['barcode'] as String?,
    );
  }

  static Map<String, dynamic> customerToRow(String tenantId, DebtCustomer c) => {
        'tenant_id': tenantId,
        'client_id': c.id,
        'name': c.name,
        'phone_display': c.phoneDisplay,
        'phone_key': c.phoneKey,
        'notes': c.notes,
        'created_at': c.createdAt.toUtc().toIso8601String(),
      };

  static DebtCustomer customerFromRow(Map<String, dynamic> r) => DebtCustomer(
        id: '${r['client_id']}',
        name: '${r['name'] ?? ''}',
        phoneDisplay: '${r['phone_display'] ?? ''}',
        phoneKey: '${r['phone_key'] ?? ''}',
        notes: '${r['notes'] ?? ''}',
        createdAt: DateTime.tryParse('${r['created_at']}') ?? DateTime.now(),
      );

  static Map<String, dynamic> supplierToRow(String tenantId, Supplier s) => {
        'tenant_id': tenantId,
        'client_id': s.id,
        'name': s.name,
        'phone': s.phone,
        'address': s.address,
        'notes': s.notes,
        'balance_owed': s.balanceOwed,
      };

  static Supplier supplierFromRow(Map<String, dynamic> r) => Supplier(
        id: '${r['client_id']}',
        name: '${r['name'] ?? ''}',
        phone: '${r['phone'] ?? ''}',
        address: '${r['address'] ?? ''}',
        notes: '${r['notes'] ?? ''}',
        balanceOwed: (r['balance_owed'] as num?)?.toDouble() ?? 0,
      );

  static Map<String, dynamic> saleToRow(String tenantId, CompletedSaleInvoice inv) => {
        'tenant_id': tenantId,
        'client_id': inv.invoiceNumber,
        'invoice_number': inv.invoiceNumber,
        'issued_at': inv.issuedAt.toUtc().toIso8601String(),
        'customer_name': inv.customerName,
        'customer_phone': inv.customerPhone,
        'payment_method': inv.paymentMethod,
        'cashier_name': inv.cashierName,
        'cashier_user_id': inv.cashierUserId,
        'subtotal': inv.subtotal,
        'tax_rate': inv.taxRate,
        'tax_amount': inv.taxAmount,
        'discount_amount': inv.discountAmount,
        'total': inv.total,
        'profit_at_sale': inv.profitAtSale,
        'settlement_mode': inv.settlementMode.name,
        'paid_toward_invoice': inv.paidTowardInvoice,
        'remaining_balance': inv.remainingBalance,
        'debt_customer_client_id': inv.debtCustomerId,
        'debt_customer_notes': inv.debtCustomerNotes,
        'debt_ledger': inv.debtLedger
            .map((e) => {
                  'recordedAt': e.recordedAt.toUtc().toIso8601String(),
                  'amount': e.amount,
                  'label': e.label,
                })
            .toList(),
      };

  static List<Map<String, dynamic>> saleItemsToRows(String tenantId, CompletedSaleInvoice inv) {
    return [
      for (final line in inv.lines)
        {
          'tenant_id': tenantId,
          'sale_client_id': inv.invoiceNumber,
          'line_client_id': line.lineId,
          'medicine_client_id': line.medicineId,
          'name': line.name,
          'quantity_sold': line.quantitySold,
          'quantity_returned': line.quantityReturned,
          'unit_sell': line.unitSell,
          'unit_buy': line.unitBuy,
        },
    ];
  }

  static CompletedSaleInvoice? saleFromRows(
    Map<String, dynamic> header,
    List<Map<String, dynamic>> itemRows,
  ) {
    SaleSettlementMode sm;
    try {
      sm = SaleSettlementMode.values.byName('${header['settlement_mode']}');
    } catch (_) {
      sm = SaleSettlementMode.paidInFull;
    }
    final ledgerRaw = header['debt_ledger'];
    final ledger = <SaleDebtLedgerEntry>[];
    if (ledgerRaw is List) {
      for (final e in ledgerRaw) {
        if (e is! Map) continue;
        final m = Map<String, dynamic>.from(e);
        ledger.add(
          SaleDebtLedgerEntry(
            recordedAt: DateTime.tryParse('${m['recordedAt']}') ?? DateTime.now(),
            amount: (m['amount'] as num?)?.toDouble() ?? 0,
            label: '${m['label'] ?? ''}',
          ),
        );
      }
    }
    final lines = [
      for (final r in itemRows)
        SoldLineItem(
          lineId: '${r['line_client_id']}',
          medicineId: '${r['medicine_client_id']}',
          name: '${r['name']}',
          quantitySold: (r['quantity_sold'] as num?)?.toInt() ?? 0,
          quantityReturned: (r['quantity_returned'] as num?)?.toInt() ?? 0,
          unitSell: (r['unit_sell'] as num?)?.toDouble() ?? 0,
          unitBuy: (r['unit_buy'] as num?)?.toDouble() ?? 0,
        ),
    ];
    return CompletedSaleInvoice(
      invoiceNumber: '${header['invoice_number']}',
      issuedAt: DateTime.tryParse('${header['issued_at']}') ?? DateTime.now(),
      customerName: '${header['customer_name'] ?? ''}',
      customerPhone: '${header['customer_phone'] ?? ''}',
      paymentMethod: '${header['payment_method'] ?? ''}',
      cashierName: '${header['cashier_name'] ?? ''}',
      lines: lines,
      subtotal: (header['subtotal'] as num?)?.toDouble() ?? 0,
      taxRate: (header['tax_rate'] as num?)?.toDouble() ?? 0,
      taxAmount: (header['tax_amount'] as num?)?.toDouble() ?? 0,
      discountAmount: (header['discount_amount'] as num?)?.toDouble() ?? 0,
      total: (header['total'] as num?)?.toDouble() ?? 0,
      profitAtSale: (header['profit_at_sale'] as num?)?.toDouble() ?? 0,
      settlementMode: sm,
      paidTowardInvoice: (header['paid_toward_invoice'] as num?)?.toDouble() ?? 0,
      remainingBalance: (header['remaining_balance'] as num?)?.toDouble() ?? 0,
      debtCustomerId: header['debt_customer_client_id'] as String?,
      debtCustomerNotes: '${header['debt_customer_notes'] ?? ''}',
      debtLedger: ledger,
      cashierUserId: header['cashier_user_id'] as String?,
    );
  }

  static Map<String, dynamic> saleReturnToRow(String tenantId, SalesReturnRecord r) => {
        'tenant_id': tenantId,
        'client_id': r.returnInvoiceNumber,
        'return_invoice_number': r.returnInvoiceNumber,
        'original_invoice_number': r.originalInvoiceNumber,
        'issued_at': r.issuedAt.toUtc().toIso8601String(),
        'cashier_name': r.cashierName,
        'reason': r.reason.name,
        'notes': r.notes,
        'lines': r.lines
            .map((l) => {
                  'name': l.name,
                  'quantity': l.quantity,
                  'unitSell': l.unitSell,
                  'lineRefund': l.lineRefund,
                })
            .toList(),
        'refund_total': r.refundTotal,
        'profit_reduction': r.profitReduction,
      };

  static SalesReturnRecord saleReturnFromRow(Map<String, dynamic> r) {
    ReturnReason reason;
    try {
      reason = ReturnReason.values.byName('${r['reason']}');
    } catch (_) {
      reason = ReturnReason.other;
    }
    final linesRaw = r['lines'];
    final lines = <SalesReturnLineSnapshot>[];
    if (linesRaw is List) {
      for (final e in linesRaw) {
        if (e is! Map) continue;
        final m = Map<String, dynamic>.from(e);
        lines.add(
          SalesReturnLineSnapshot(
            name: '${m['name']}',
            quantity: (m['quantity'] as num?)?.toInt() ?? 0,
            unitSell: (m['unitSell'] as num?)?.toDouble() ?? 0,
            lineRefund: (m['lineRefund'] as num?)?.toDouble() ?? 0,
          ),
        );
      }
    }
    return SalesReturnRecord(
      returnInvoiceNumber: '${r['return_invoice_number']}',
      originalInvoiceNumber: '${r['original_invoice_number']}',
      issuedAt: DateTime.tryParse('${r['issued_at']}') ?? DateTime.now(),
      cashierName: '${r['cashier_name'] ?? ''}',
      reason: reason,
      notes: '${r['notes'] ?? ''}',
      lines: lines,
      refundTotal: (r['refund_total'] as num?)?.toDouble() ?? 0,
      profitReduction: (r['profit_reduction'] as num?)?.toDouble() ?? 0,
    );
  }

  static Map<String, dynamic> purchaseToRow(String tenantId, PurchaseInvoice inv) => {
        'tenant_id': tenantId,
        'client_id': inv.invoiceNumber,
        'invoice_number': inv.invoiceNumber,
        'issued_at': inv.issuedAt.toUtc().toIso8601String(),
        'supplier_client_id': inv.supplierId,
        'supplier_name': inv.supplierName,
        'supplier_phone': inv.supplierPhone,
        'supplier_address': inv.supplierAddress,
        'cashier_name': inv.cashierName,
        'notes': inv.notes,
        'subtotal': inv.subtotal,
        'discount': inv.discount,
        'tax_rate': inv.taxRate,
        'tax_amount': inv.taxAmount,
        'grand_total': inv.grandTotal,
        'paid_amount': inv.paidAmount,
        'remaining_balance': inv.remainingBalance,
        'settlement_mode': inv.settlementMode.name,
        'payment_method': inv.paymentMethod,
        'return_credits_applied': inv.returnCreditsApplied,
        'returned_qty_by_medicine': inv.returnedQtyByMedicineId,
      };

  static List<Map<String, dynamic>> purchaseItemsToRows(String tenantId, PurchaseInvoice inv) {
    return [
      for (final line in inv.lines)
        {
          'tenant_id': tenantId,
          'purchase_client_id': inv.invoiceNumber,
          'line_client_id': '${inv.invoiceNumber}_${line.medicineId}',
          'medicine_client_id': line.medicineId,
          'name': line.name,
          'form_type': line.formType.name,
          'custom_form_label': line.customFormLabel,
          'expiry_date': line.expiryDate?.toUtc().toIso8601String(),
          'quantity': line.quantity,
          'buying_price': line.buyingPrice,
          'selling_price': line.sellingPrice,
          'line_total': line.lineTotal,
        },
    ];
  }

  static PurchaseInvoice? purchaseFromRows(
    Map<String, dynamic> header,
    List<Map<String, dynamic>> itemRows,
  ) {
    PurchaseSettlementMode sm;
    try {
      sm = PurchaseSettlementMode.values.byName('${header['settlement_mode']}');
    } catch (_) {
      sm = PurchaseSettlementMode.paidInFull;
    }
    final rq = header['returned_qty_by_medicine'];
    Map<String, int> rqMap = {};
    if (rq is Map) {
      for (final e in rq.entries) {
        rqMap['${e.key}'] = (e.value as num?)?.toInt() ?? 0;
      }
    }
    final lines = <PurchaseInvoiceLine>[];
    for (final r in itemRows) {
      MedicineFormType form;
      try {
        form = MedicineFormType.values.byName('${r['form_type']}');
      } catch (_) {
        form = MedicineFormType.tablet;
      }
      lines.add(
        PurchaseInvoiceLine(
          medicineId: '${r['medicine_client_id']}',
          name: '${r['name']}',
          formType: form,
          customFormLabel: r['custom_form_label'] as String?,
          expiryDate: r['expiry_date'] != null ? DateTime.tryParse('${r['expiry_date']}') : null,
          quantity: (r['quantity'] as num?)?.toInt() ?? 0,
          buyingPrice: (r['buying_price'] as num?)?.toDouble() ?? 0,
          sellingPrice: (r['selling_price'] as num?)?.toDouble() ?? 0,
          lineTotal: (r['line_total'] as num?)?.toDouble() ?? 0,
        ),
      );
    }
    return PurchaseInvoice(
      invoiceNumber: '${header['invoice_number']}',
      issuedAt: DateTime.tryParse('${header['issued_at']}') ?? DateTime.now(),
      supplierId: '${header['supplier_client_id']}',
      supplierName: '${header['supplier_name'] ?? ''}',
      supplierPhone: '${header['supplier_phone'] ?? ''}',
      supplierAddress: '${header['supplier_address'] ?? ''}',
      cashierName: '${header['cashier_name'] ?? ''}',
      notes: '${header['notes'] ?? ''}',
      lines: lines,
      subtotal: (header['subtotal'] as num?)?.toDouble() ?? 0,
      discount: (header['discount'] as num?)?.toDouble() ?? 0,
      taxRate: (header['tax_rate'] as num?)?.toDouble() ?? 0,
      taxAmount: (header['tax_amount'] as num?)?.toDouble() ?? 0,
      grandTotal: (header['grand_total'] as num?)?.toDouble() ?? 0,
      paidAmount: (header['paid_amount'] as num?)?.toDouble() ?? 0,
      remainingBalance: (header['remaining_balance'] as num?)?.toDouble() ?? 0,
      settlementMode: sm,
      paymentMethod: '${header['payment_method'] ?? ''}',
      returnCreditsApplied: (header['return_credits_applied'] as num?)?.toDouble() ?? 0,
      returnedQtyByMedicineId: rqMap,
    );
  }

  static Map<String, dynamic> purchaseReturnToRow(String tenantId, PurchaseReturnRecord r) => {
        'tenant_id': tenantId,
        'client_id': r.returnInvoiceNumber,
        'return_invoice_number': r.returnInvoiceNumber,
        'source_purchase_number': r.sourcePurchaseNumber,
        'issued_at': r.issuedAt.toUtc().toIso8601String(),
        'supplier_name': r.supplierName,
        'reason': r.reason.name,
        'notes': r.notes,
        'lines': r.lines
            .map((l) => {
                  'medicineName': l.medicineName,
                  'quantity': l.quantity,
                  'unitCost': l.unitCost,
                  'lineCredit': l.lineCredit,
                })
            .toList(),
        'total_credit_at_cost': r.totalCreditAtCost,
        'credit_applied_to_invoice': r.creditAppliedToInvoice,
        'supplier_balance_reduced': r.supplierBalanceReduced,
      };

  static PurchaseReturnRecord purchaseReturnFromRow(Map<String, dynamic> r) {
    PurchaseReturnReason reason;
    try {
      reason = PurchaseReturnReason.values.byName('${r['reason']}');
    } catch (_) {
      reason = PurchaseReturnReason.other;
    }
    final linesRaw = r['lines'];
    final lines = <PurchaseReturnLineSnapshot>[];
    if (linesRaw is List) {
      for (final e in linesRaw) {
        if (e is! Map) continue;
        final m = Map<String, dynamic>.from(e);
        lines.add(
          PurchaseReturnLineSnapshot(
            medicineName: '${m['medicineName']}',
            quantity: (m['quantity'] as num?)?.toInt() ?? 0,
            unitCost: (m['unitCost'] as num?)?.toDouble() ?? 0,
            lineCredit: (m['lineCredit'] as num?)?.toDouble() ?? 0,
          ),
        );
      }
    }
    return PurchaseReturnRecord(
      returnInvoiceNumber: '${r['return_invoice_number']}',
      sourcePurchaseNumber: '${r['source_purchase_number']}',
      issuedAt: DateTime.tryParse('${r['issued_at']}') ?? DateTime.now(),
      supplierName: '${r['supplier_name'] ?? ''}',
      reason: reason,
      notes: '${r['notes'] ?? ''}',
      lines: lines,
      totalCreditAtCost: (r['total_credit_at_cost'] as num?)?.toDouble() ?? 0,
      creditAppliedToInvoice: (r['credit_applied_to_invoice'] as num?)?.toDouble() ?? 0,
      supplierBalanceReduced: (r['supplier_balance_reduced'] as num?)?.toDouble() ?? 0,
    );
  }

}
