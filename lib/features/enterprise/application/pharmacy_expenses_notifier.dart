import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/pharmacy_expense.dart';

final pharmacyExpensesProvider =
    StateNotifierProvider<PharmacyExpensesNotifier, List<PharmacyExpense>>((ref) {
  return PharmacyExpensesNotifier();
});

class PharmacyExpensesNotifier extends StateNotifier<List<PharmacyExpense>> {
  PharmacyExpensesNotifier() : super(const []);

  void replaceAll(List<PharmacyExpense> next) {
    state = List<PharmacyExpense>.from(next)
      ..sort((a, b) => b.issuedAt.compareTo(a.issuedAt));
  }

  void add(PharmacyExpense expense) {
    state = [expense, ...state];
  }

  void update(PharmacyExpense expense) {
    state = [
      for (final e in state)
        if (e.id == expense.id) expense else e,
    ]..sort((a, b) => b.issuedAt.compareTo(a.issuedAt));
  }

  void remove(String id) {
    state = state.where((e) => e.id != id).toList();
  }

  List<PharmacyExpense> filtered({
    String? category,
    DateTime? from,
    DateTime? to,
    String search = '',
  }) {
    final q = search.trim().toLowerCase();
    return state.where((e) {
      if (category != null && category.isNotEmpty && e.category != category) return false;
      if (from != null && e.issuedAt.isBefore(from)) return false;
      if (to != null && e.issuedAt.isAfter(to)) return false;
      if (q.isNotEmpty && !e.note.toLowerCase().contains(q) && !e.category.toLowerCase().contains(q)) {
        return false;
      }
      return true;
    }).toList(growable: false);
  }

  double totalForMonth(DateTime anchor) {
    return state
        .where((e) => e.issuedAt.year == anchor.year && e.issuedAt.month == anchor.month)
        .fold(0.0, (s, e) => s + e.amount);
  }

  double totalForDay(DateTime day) {
    final d = DateTime(day.year, day.month, day.day);
    return state
        .where((e) {
          final ed = DateTime(e.issuedAt.year, e.issuedAt.month, e.issuedAt.day);
          return ed == d;
        })
        .fold(0.0, (s, e) => s + e.amount);
  }
}
