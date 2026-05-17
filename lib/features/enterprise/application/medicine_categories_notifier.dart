import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/medicine_category.dart';

final medicineCategoriesProvider =
    StateNotifierProvider<MedicineCategoriesNotifier, List<MedicineCategory>>((ref) {
  return MedicineCategoriesNotifier();
});

class MedicineCategoriesNotifier extends StateNotifier<List<MedicineCategory>> {
  MedicineCategoriesNotifier() : super(const []);

  void replaceAll(List<MedicineCategory> next) {
    state = List<MedicineCategory>.from(next)
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
  }

  void add(MedicineCategory category) {
    state = [...state, category]..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
  }

  void update(MedicineCategory category) {
    state = [
      for (final c in state)
        if (c.id == category.id) category else c,
    ]..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
  }

  void remove(String id) {
    state = state.where((c) => c.id != id).toList();
  }

  List<MedicineCategory> childrenOf(String? parentId) {
    return state.where((c) => c.parentId == parentId).toList(growable: false);
  }

  /// Returns error message if delete is unsafe; null if OK.
  String? validateDelete(String id) {
    for (final c in state) {
      if (c.parentId == id) return 'Remove or reassign child categories first.';
    }
    return null;
  }

  int countInSubtree(String id) => state.where((c) => c.parentId == id).length;
}
