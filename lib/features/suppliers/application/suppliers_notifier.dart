import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/supplier.dart';

final suppliersProvider = StateNotifierProvider<SuppliersNotifier, List<Supplier>>((ref) {
  return SuppliersNotifier();
});

class SuppliersNotifier extends StateNotifier<List<Supplier>> {
  SuppliersNotifier() : super(const []);

  void replaceAll(List<Supplier> next) {
    state = List<Supplier>.from(next);
  }

  void addSupplier(Supplier s) {
    state = [s, ...state];
  }

  void updateSupplier(Supplier updated) {
    state = [
      for (final s in state)
        if (s.id == updated.id) updated else s,
    ];
  }

  Supplier? byId(String id) {
    for (final s in state) {
      if (s.id == id) return s;
    }
    return null;
  }

  /// Increases amount owed to supplier (credit / unpaid balance on a purchase).
  void addBalanceOwed(String supplierId, double amount) {
    if (amount <= 0) return;
    state = [
      for (final s in state)
        if (s.id == supplierId) s.copyWith(balanceOwed: s.balanceOwed + amount) else s,
    ];
  }

  /// Reduces balance when supplier is paid (not wired in UI yet — hook for payments).
  void reduceBalanceOwed(String supplierId, double amount) {
    if (amount <= 0) return;
    state = [
      for (final s in state)
        if (s.id == supplierId)
          s.copyWith(balanceOwed: (s.balanceOwed - amount).clamp(0, 1e15))
        else
          s,
    ];
  }
}
