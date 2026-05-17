import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../suppliers/application/suppliers_notifier.dart';
import '../domain/supplier_payment_record.dart';

final supplierPaymentsProvider =
    StateNotifierProvider<SupplierPaymentsNotifier, List<SupplierPaymentRecord>>((ref) {
  return SupplierPaymentsNotifier(ref);
});

class SupplierPaymentsNotifier extends StateNotifier<List<SupplierPaymentRecord>> {
  SupplierPaymentsNotifier(this._ref) : super(const []);

  final Ref _ref;

  List<SupplierPaymentRecord> forSupplier(String supplierId) {
    final list = state.where((p) => p.supplierId == supplierId).toList();
    list.sort((a, b) => b.paidAt.compareTo(a.paidAt));
    return list;
  }

  /// Returns `null` on success, or error message.
  String? recordPayment({
    required String supplierId,
    required double amount,
    String note = '',
  }) {
    if (amount <= 0) return 'Enter a positive amount.';
    final sup = _ref.read(suppliersProvider.notifier).byId(supplierId);
    if (sup == null) return 'Supplier not found.';
    if (amount > sup.balanceOwed + 0.009) {
      return 'Amount exceeds outstanding balance (\$${sup.balanceOwed.toStringAsFixed(2)}).';
    }
    _ref.read(suppliersProvider.notifier).reduceBalanceOwed(supplierId, amount);
    final rec = SupplierPaymentRecord(
      id: 'spay_${DateTime.now().microsecondsSinceEpoch}',
      supplierId: supplierId,
      amount: amount,
      paidAt: DateTime.now(),
      note: note.trim(),
    );
    state = [rec, ...state];
    return null;
  }
}
