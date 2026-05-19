import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/product_barcode.dart';

final productBarcodesProvider =
    StateNotifierProvider<ProductBarcodesNotifier, List<ProductBarcode>>((ref) {
  return ProductBarcodesNotifier();
});

class ProductBarcodesNotifier extends StateNotifier<List<ProductBarcode>> {
  ProductBarcodesNotifier() : super(const []);

  void replaceAll(List<ProductBarcode> next) {
    state = List<ProductBarcode>.from(next);
  }

  bool mergeWorkspaceEntity(ProductBarcode incoming) {
    final idx = state.indexWhere((b) => b.id == incoming.id);
    if (idx < 0) {
      state = [...state, incoming];
      return true;
    }
    state = [
      for (final b in state)
        if (b.id == incoming.id) incoming else b,
    ];
    return true;
  }

  void removeWorkspaceEntity(String clientId) {
    state = state.where((b) => b.id != clientId).toList();
  }

  /// Returns error if barcode is invalid or already used in this tenant cache.
  String? validateNew(String raw, {String? excludeId}) {
    final code = ProductBarcode.normalize(raw);
    if (code.isEmpty) return 'Barcode cannot be empty.';
    if (code.length < 4) return 'Barcode is too short.';
    for (final b in state) {
      if (excludeId != null && b.id == excludeId) continue;
      if (b.barcode == code) return 'This barcode is already registered.';
    }
    return null;
  }

  void add(ProductBarcode barcode) {
    state = [...state, barcode];
  }

  void remove(String id) {
    state = state.where((b) => b.id != id).toList();
  }

  List<ProductBarcode> forMedicine(String medicineId) =>
      state.where((b) => b.medicineId == medicineId).toList(growable: false);

  String? medicineIdForBarcode(String raw) {
    final code = ProductBarcode.normalize(raw);
    if (code.isEmpty) return null;
    for (final b in state) {
      if (b.barcode == code) return b.medicineId;
    }
    return null;
  }
}

/// Resolves medicine id from primary catalog barcode + extra registry.
final pharmacyBarcodeLookupProvider = Provider<String? Function(String)>((ref) {
  final extras = ref.watch(productBarcodesProvider);
  return (String raw) {
    final code = ProductBarcode.normalize(raw);
    if (code.isEmpty) return null;
    for (final b in extras) {
      if (b.barcode == code) return b.medicineId;
    }
    return null;
  };
});
