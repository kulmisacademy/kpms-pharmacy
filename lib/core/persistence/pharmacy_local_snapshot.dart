import 'dart:convert';

import '../../features/debts/domain/debt_customer.dart';
import '../../features/medicines/domain/medicine.dart';
import '../../features/medicines/domain/medicine_form_type.dart';
import '../../features/purchases/application/purchase_ledger_notifier.dart';
import '../../features/purchases/domain/purchase_invoice.dart';
import '../../features/purchases/domain/purchase_return.dart';
import '../../features/sales/application/sales_ledger_notifier.dart';
import '../../features/sales/domain/completed_sale_invoice.dart';
import '../../features/sales/domain/sale_settlement.dart';
import '../../features/suppliers/domain/supplier.dart';

/// Local JSON snapshot of pharmacy workspace (until Supabase inventory/ledger sync ships).
abstract final class PharmacyLocalSnapshot {
  static const int _version = 1;

  static Map<String, dynamic> encodeFull({
    required List<Medicine> medicines,
    required SalesLedgerState sales,
    required PurchaseLedgerState purchases,
    required List<DebtCustomer> debtCustomers,
    required List<Supplier> suppliers,
  }) {
    return {
      'v': _version,
      'medicines': medicines.map(_medicineToJson).toList(),
      'sales': _salesToJson(sales),
      'purchases': _purchasesToJson(purchases),
      'debtCustomers': debtCustomers.map(_debtCustomerToJson).toList(),
      'suppliers': suppliers.map(_supplierToJson).toList(),
    };
  }

  static String encodeJson({
    required List<Medicine> medicines,
    required SalesLedgerState sales,
    required PurchaseLedgerState purchases,
    required List<DebtCustomer> debtCustomers,
    required List<Supplier> suppliers,
  }) =>
      jsonEncode(encodeFull(
        medicines: medicines,
        sales: sales,
        purchases: purchases,
        debtCustomers: debtCustomers,
        suppliers: suppliers,
      ));

  static ({
    List<Medicine> medicines,
    SalesLedgerState sales,
    PurchaseLedgerState purchases,
    List<DebtCustomer> debtCustomers,
    List<Supplier> suppliers,
  })?
      decode(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    try {
      final m = jsonDecode(raw);
      if (m is! Map<String, dynamic>) return null;
      if ((m['v'] as num?)?.toInt() != _version) return null;
      return (
        medicines: (m['medicines'] as List?)?.map((e) => _medicineFromJson(Map<String, dynamic>.from(e as Map))).toList() ?? const [],
        sales: _salesFromJson(m['sales'] as Map<String, dynamic>?),
        purchases: _purchasesFromJson(m['purchases'] as Map<String, dynamic>?),
        debtCustomers: (m['debtCustomers'] as List?)?.map((e) => _debtCustomerFromJson(Map<String, dynamic>.from(e as Map))).toList() ?? const [],
        suppliers: (m['suppliers'] as List?)?.map((e) => _supplierFromJson(Map<String, dynamic>.from(e as Map))).toList() ?? const [],
      );
    } catch (_) {
      return null;
    }
  }

  static Map<String, dynamic> _medicineToJson(Medicine m) {
    return {
      'id': m.id,
      'name': m.name,
      'expiry': m.expiryDate?.toIso8601String(),
      'form': m.formType.name,
      'customForm': m.customFormLabel,
      'qty': m.quantity,
      'buy': m.buyingPrice,
      'sell': m.sellingPrice,
      'min': m.minimumStockAlert,
      'batch': m.batchCode,
      'barcode': m.barcode,
    };
  }

  static Medicine _medicineFromJson(Map<String, dynamic> j) {
    MedicineFormType form;
    try {
      form = MedicineFormType.values.byName('${j['form']}');
    } catch (_) {
      form = MedicineFormType.tablet;
    }
    return Medicine(
      id: '${j['id']}',
      name: '${j['name'] ?? 'Item'}',
      expiryDate: j['expiry'] != null ? DateTime.tryParse('${j['expiry']}') : null,
      formType: form,
      customFormLabel: j['customForm'] as String?,
      quantity: (j['qty'] as num?)?.toInt() ?? 0,
      buyingPrice: (j['buy'] as num?)?.toDouble() ?? 0,
      sellingPrice: (j['sell'] as num?)?.toDouble() ?? 0,
      minimumStockAlert: (j['min'] as num?)?.toInt() ?? 0,
      batchCode: j['batch'] as String?,
      barcode: j['barcode'] as String?,
    );
  }

  static Map<String, dynamic> _salesToJson(SalesLedgerState s) {
    return {
      'invoices': s.invoices.map(_invoiceToJson).toList(),
      'returns': s.returns.map(_saleReturnToJson).toList(),
    };
  }

  static SalesLedgerState _salesFromJson(Map<String, dynamic>? m) {
    if (m == null) return const SalesLedgerState();
    final inv = (m['invoices'] as List?)?.map((e) => _invoiceFromJson(Map<String, dynamic>.from(e as Map))).toList() ?? const [];
    final ret = (m['returns'] as List?)?.map((e) => _saleReturnFromJson(Map<String, dynamic>.from(e as Map))).toList() ?? const [];
    return SalesLedgerState(invoices: inv, returns: ret);
  }

  static Map<String, dynamic> _invoiceToJson(CompletedSaleInvoice i) {
    return {
      'invoiceNumber': i.invoiceNumber,
      'issuedAt': i.issuedAt.toIso8601String(),
      'customerName': i.customerName,
      'customerPhone': i.customerPhone,
      'paymentMethod': i.paymentMethod,
      'cashierName': i.cashierName,
      'cashierUserId': i.cashierUserId,
      'lines': i.lines.map(_soldLineToJson).toList(),
      'subtotal': i.subtotal,
      'taxRate': i.taxRate,
      'taxAmount': i.taxAmount,
      'discountAmount': i.discountAmount,
      'total': i.total,
      'profitAtSale': i.profitAtSale,
      'settlement': i.settlementMode.name,
      'paidTowardInvoice': i.paidTowardInvoice,
      'remainingBalance': i.remainingBalance,
      'debtCustomerId': i.debtCustomerId,
      'debtCustomerNotes': i.debtCustomerNotes,
      'debtLedger': i.debtLedger.map(_debtLedgerToJson).toList(),
    };
  }

  static CompletedSaleInvoice _invoiceFromJson(Map<String, dynamic> j) {
    SaleSettlementMode sm;
    try {
      sm = SaleSettlementMode.values.byName('${j['settlement']}');
    } catch (_) {
      sm = SaleSettlementMode.paidInFull;
    }
    return CompletedSaleInvoice(
      invoiceNumber: '${j['invoiceNumber']}',
      issuedAt: DateTime.tryParse('${j['issuedAt']}') ?? DateTime.now(),
      customerName: '${j['customerName'] ?? ''}',
      customerPhone: '${j['customerPhone'] ?? ''}',
      paymentMethod: '${j['paymentMethod'] ?? ''}',
      cashierName: '${j['cashierName'] ?? ''}',
      lines: (j['lines'] as List?)?.map((e) => _soldLineFromJson(Map<String, dynamic>.from(e as Map))).toList() ?? const [],
      subtotal: (j['subtotal'] as num?)?.toDouble() ?? 0,
      taxRate: (j['taxRate'] as num?)?.toDouble() ?? 0,
      taxAmount: (j['taxAmount'] as num?)?.toDouble() ?? 0,
      discountAmount: (j['discountAmount'] as num?)?.toDouble() ?? 0,
      total: (j['total'] as num?)?.toDouble() ?? 0,
      profitAtSale: (j['profitAtSale'] as num?)?.toDouble() ?? 0,
      settlementMode: sm,
      paidTowardInvoice: (j['paidTowardInvoice'] as num?)?.toDouble() ?? 0,
      remainingBalance: (j['remainingBalance'] as num?)?.toDouble() ?? 0,
      debtCustomerId: j['debtCustomerId'] as String?,
      debtCustomerNotes: '${j['debtCustomerNotes'] ?? ''}',
      debtLedger: (j['debtLedger'] as List?)?.map((e) => _debtLedgerFromJson(Map<String, dynamic>.from(e as Map))).toList() ?? const [],
      cashierUserId: j['cashierUserId'] as String?,
    );
  }

  static Map<String, dynamic> _soldLineToJson(SoldLineItem l) => {
        'lineId': l.lineId,
        'medicineId': l.medicineId,
        'name': l.name,
        'quantitySold': l.quantitySold,
        'quantityReturned': l.quantityReturned,
        'unitSell': l.unitSell,
        'unitBuy': l.unitBuy,
      };

  static SoldLineItem _soldLineFromJson(Map<String, dynamic> j) => SoldLineItem(
        lineId: '${j['lineId']}',
        medicineId: '${j['medicineId']}',
        name: '${j['name']}',
        quantitySold: (j['quantitySold'] as num?)?.toInt() ?? 0,
        quantityReturned: (j['quantityReturned'] as num?)?.toInt() ?? 0,
        unitSell: (j['unitSell'] as num?)?.toDouble() ?? 0,
        unitBuy: (j['unitBuy'] as num?)?.toDouble() ?? 0,
      );

  static Map<String, dynamic> _debtLedgerToJson(SaleDebtLedgerEntry e) => {
        'recordedAt': e.recordedAt.toIso8601String(),
        'amount': e.amount,
        'label': e.label,
      };

  static SaleDebtLedgerEntry _debtLedgerFromJson(Map<String, dynamic> j) => SaleDebtLedgerEntry(
        recordedAt: DateTime.tryParse('${j['recordedAt']}') ?? DateTime.now(),
        amount: (j['amount'] as num?)?.toDouble() ?? 0,
        label: '${j['label']}',
      );

  static Map<String, dynamic> _saleReturnToJson(SalesReturnRecord r) => {
        'returnInvoiceNumber': r.returnInvoiceNumber,
        'originalInvoiceNumber': r.originalInvoiceNumber,
        'issuedAt': r.issuedAt.toIso8601String(),
        'cashierName': r.cashierName,
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
        'refundTotal': r.refundTotal,
        'profitReduction': r.profitReduction,
      };

  static SalesReturnRecord _saleReturnFromJson(Map<String, dynamic> j) {
    ReturnReason reason;
    try {
      reason = ReturnReason.values.byName('${j['reason']}');
    } catch (_) {
      reason = ReturnReason.other;
    }
    return SalesReturnRecord(
      returnInvoiceNumber: '${j['returnInvoiceNumber']}',
      originalInvoiceNumber: '${j['originalInvoiceNumber']}',
      issuedAt: DateTime.tryParse('${j['issuedAt']}') ?? DateTime.now(),
      cashierName: '${j['cashierName']}',
      reason: reason,
      notes: '${j['notes']}',
      lines: (j['lines'] as List?)
              ?.map((e) {
                final m = Map<String, dynamic>.from(e as Map);
                return SalesReturnLineSnapshot(
                  name: '${m['name']}',
                  quantity: (m['quantity'] as num?)?.toInt() ?? 0,
                  unitSell: (m['unitSell'] as num?)?.toDouble() ?? 0,
                  lineRefund: (m['lineRefund'] as num?)?.toDouble() ?? 0,
                );
              })
              .toList() ??
          const [],
      refundTotal: (j['refundTotal'] as num?)?.toDouble() ?? 0,
      profitReduction: (j['profitReduction'] as num?)?.toDouble() ?? 0,
    );
  }

  static Map<String, dynamic> _purchasesToJson(PurchaseLedgerState s) => {
        'invoices': s.invoices.map(_purchaseInvoiceToJson).toList(),
        'returns': s.returns.map(_purchaseReturnToJson).toList(),
      };

  static PurchaseLedgerState _purchasesFromJson(Map<String, dynamic>? m) {
    if (m == null) return const PurchaseLedgerState();
    final inv = (m['invoices'] as List?)?.map((e) => _purchaseInvoiceFromJson(Map<String, dynamic>.from(e as Map))).toList() ?? const [];
    final ret = (m['returns'] as List?)?.map((e) => _purchaseReturnFromJson(Map<String, dynamic>.from(e as Map))).toList() ?? const [];
    return PurchaseLedgerState(invoices: inv, returns: ret);
  }

  static Map<String, dynamic> _purchaseInvoiceToJson(PurchaseInvoice p) => {
        'invoiceNumber': p.invoiceNumber,
        'issuedAt': p.issuedAt.toIso8601String(),
        'supplierId': p.supplierId,
        'supplierName': p.supplierName,
        'supplierPhone': p.supplierPhone,
        'supplierAddress': p.supplierAddress,
        'cashierName': p.cashierName,
        'notes': p.notes,
        'lines': p.lines.map((l) => {
              'medicineId': l.medicineId,
              'name': l.name,
              'form': l.formType.name,
              'customForm': l.customFormLabel,
              'expiry': l.expiryDate?.toIso8601String(),
              'quantity': l.quantity,
              'buyingPrice': l.buyingPrice,
              'sellingPrice': l.sellingPrice,
              'lineTotal': l.lineTotal,
            }).toList(),
        'subtotal': p.subtotal,
        'discount': p.discount,
        'taxRate': p.taxRate,
        'taxAmount': p.taxAmount,
        'grandTotal': p.grandTotal,
        'paidAmount': p.paidAmount,
        'remainingBalance': p.remainingBalance,
        'settlementMode': p.settlementMode.name,
        'paymentMethod': p.paymentMethod,
        'returnCreditsApplied': p.returnCreditsApplied,
        'returnedQtyByMedicineId': p.returnedQtyByMedicineId,
      };

  static PurchaseInvoice _purchaseInvoiceFromJson(Map<String, dynamic> j) {
    PurchaseSettlementMode sm;
    try {
      sm = PurchaseSettlementMode.values.byName('${j['settlementMode']}');
    } catch (_) {
      sm = PurchaseSettlementMode.paidInFull;
    }
    final rq = j['returnedQtyByMedicineId'];
    Map<String, int> rqMap = {};
    if (rq is Map) {
      for (final e in rq.entries) {
        rqMap['${e.key}'] = (e.value as num?)?.toInt() ?? 0;
      }
    }
    return PurchaseInvoice(
      invoiceNumber: '${j['invoiceNumber']}',
      issuedAt: DateTime.tryParse('${j['issuedAt']}') ?? DateTime.now(),
      supplierId: '${j['supplierId']}',
      supplierName: '${j['supplierName']}',
      supplierPhone: '${j['supplierPhone']}',
      supplierAddress: '${j['supplierAddress']}',
      cashierName: '${j['cashierName']}',
      notes: '${j['notes']}',
      lines: (j['lines'] as List?)?.map((e) {
            final m = Map<String, dynamic>.from(e as Map);
            MedicineFormType form;
            try {
              form = MedicineFormType.values.byName('${m['form']}');
            } catch (_) {
              form = MedicineFormType.tablet;
            }
            return PurchaseInvoiceLine(
              medicineId: '${m['medicineId']}',
              name: '${m['name']}',
              formType: form,
              customFormLabel: m['customForm'] as String?,
              expiryDate: m['expiry'] != null ? DateTime.tryParse('${m['expiry']}') : null,
              quantity: (m['quantity'] as num?)?.toInt() ?? 0,
              buyingPrice: (m['buyingPrice'] as num?)?.toDouble() ?? 0,
              sellingPrice: (m['sellingPrice'] as num?)?.toDouble() ?? 0,
              lineTotal: (m['lineTotal'] as num?)?.toDouble() ?? 0,
            );
          }).toList() ??
          const [],
      subtotal: (j['subtotal'] as num?)?.toDouble() ?? 0,
      discount: (j['discount'] as num?)?.toDouble() ?? 0,
      taxRate: (j['taxRate'] as num?)?.toDouble() ?? 0,
      taxAmount: (j['taxAmount'] as num?)?.toDouble() ?? 0,
      grandTotal: (j['grandTotal'] as num?)?.toDouble() ?? 0,
      paidAmount: (j['paidAmount'] as num?)?.toDouble() ?? 0,
      remainingBalance: (j['remainingBalance'] as num?)?.toDouble() ?? 0,
      settlementMode: sm,
      paymentMethod: '${j['paymentMethod']}',
      returnCreditsApplied: (j['returnCreditsApplied'] as num?)?.toDouble() ?? 0,
      returnedQtyByMedicineId: rqMap,
    );
  }

  static Map<String, dynamic> _purchaseReturnToJson(PurchaseReturnRecord r) => {
        'returnInvoiceNumber': r.returnInvoiceNumber,
        'sourcePurchaseNumber': r.sourcePurchaseNumber,
        'issuedAt': r.issuedAt.toIso8601String(),
        'supplierName': r.supplierName,
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
        'totalCreditAtCost': r.totalCreditAtCost,
        'creditAppliedToInvoice': r.creditAppliedToInvoice,
        'supplierBalanceReduced': r.supplierBalanceReduced,
      };

  static PurchaseReturnRecord _purchaseReturnFromJson(Map<String, dynamic> j) {
    PurchaseReturnReason reason;
    try {
      reason = PurchaseReturnReason.values.byName('${j['reason']}');
    } catch (_) {
      reason = PurchaseReturnReason.other;
    }
    return PurchaseReturnRecord(
      returnInvoiceNumber: '${j['returnInvoiceNumber']}',
      sourcePurchaseNumber: '${j['sourcePurchaseNumber']}',
      issuedAt: DateTime.tryParse('${j['issuedAt']}') ?? DateTime.now(),
      supplierName: '${j['supplierName']}',
      reason: reason,
      notes: '${j['notes']}',
      lines: (j['lines'] as List?)
              ?.map((e) {
                final m = Map<String, dynamic>.from(e as Map);
                return PurchaseReturnLineSnapshot(
                  medicineName: '${m['medicineName']}',
                  quantity: (m['quantity'] as num?)?.toInt() ?? 0,
                  unitCost: (m['unitCost'] as num?)?.toDouble() ?? 0,
                  lineCredit: (m['lineCredit'] as num?)?.toDouble() ?? 0,
                );
              })
              .toList() ??
          const [],
      totalCreditAtCost: (j['totalCreditAtCost'] as num?)?.toDouble() ?? 0,
      creditAppliedToInvoice: (j['creditAppliedToInvoice'] as num?)?.toDouble() ?? 0,
      supplierBalanceReduced: (j['supplierBalanceReduced'] as num?)?.toDouble() ?? 0,
    );
  }

  static Map<String, dynamic> _debtCustomerToJson(DebtCustomer c) => {
        'id': c.id,
        'name': c.name,
        'phoneDisplay': c.phoneDisplay,
        'phoneKey': c.phoneKey,
        'notes': c.notes,
        'createdAt': c.createdAt.toIso8601String(),
      };

  static DebtCustomer _debtCustomerFromJson(Map<String, dynamic> j) => DebtCustomer(
        id: '${j['id']}',
        name: '${j['name']}',
        phoneDisplay: '${j['phoneDisplay']}',
        phoneKey: '${j['phoneKey']}',
        notes: '${j['notes']}',
        createdAt: DateTime.tryParse('${j['createdAt']}') ?? DateTime.now(),
      );

  static Map<String, dynamic> _supplierToJson(Supplier s) => {
        'id': s.id,
        'name': s.name,
        'phone': s.phone,
        'address': s.address,
        'notes': s.notes,
        'balanceOwed': s.balanceOwed,
      };

  static Supplier _supplierFromJson(Map<String, dynamic> j) => Supplier(
        id: '${j['id']}',
        name: '${j['name']}',
        phone: '${j['phone']}',
        address: '${j['address']}',
        notes: '${j['notes']}',
        balanceOwed: (j['balanceOwed'] as num?)?.toDouble() ?? 0,
      );
}
