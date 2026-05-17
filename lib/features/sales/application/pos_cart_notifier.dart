import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../analytics/application/sales_analytics_notifier.dart';
import '../../../core/tenant/kpms_active_tenant_provider.dart';
import '../../medicines/data/medicine_catalog_notifier.dart';
import '../../medicines/domain/medicine.dart';
import '../domain/cart_line.dart';

final posCartProvider = StateNotifierProvider<PosCartNotifier, List<CartLine>>((ref) {
  return PosCartNotifier(ref);
});

class PosCartNotifier extends StateNotifier<List<CartLine>> {
  PosCartNotifier(this._ref) : super(const []);

  final Ref _ref;

  String _newLineId() => 'line_${DateTime.now().microsecondsSinceEpoch}';

  /// Returns false if sell price would be below buying price at default selling price.
  bool addOrIncrement(Medicine m, {int addQty = 1}) {
    if (m.sellingPrice < m.buyingPrice) return false;

    final existing = state.indexWhere((l) => l.medicineId == m.id);
    if (existing >= 0) {
      final line = state[existing];
      final nextQty = line.quantity + addQty;
      state = [
        for (var i = 0; i < state.length; i++)
          if (i == existing)
            CartLine(
              id: line.id,
              medicineId: line.medicineId,
              name: line.name,
              quantity: nextQty,
              unitBuy: line.unitBuy,
              unitSell: line.unitSell,
            )
          else
            state[i],
      ];
      return true;
    }

    state = [
      CartLine(
        id: _newLineId(),
        medicineId: m.id,
        name: m.name,
        quantity: addQty,
        unitBuy: m.buyingPrice,
        unitSell: m.sellingPrice,
      ),
      ...state,
    ];
    return true;
  }

  void setQuantity(String lineId, int q) {
    if (q < 1) {
      remove(lineId);
      return;
    }
    state = [
      for (final l in state)
        if (l.id == lineId) l.copyWith(quantity: q) else l,
    ];
  }

  void setUnitSell(String lineId, double sell) {
    state = [
      for (final l in state)
        if (l.id == lineId) l.copyWith(unitSell: sell) else l,
    ];
  }

  void remove(String lineId) {
    state = state.where((l) => l.id != lineId).toList();
  }

  void clear() {
    state = const [];
  }

  double get subtotal => state.fold(0.0, (s, l) => s + l.lineSubtotal);
  double get totalProfit => state.fold(0.0, (s, l) => s + l.lineProfit);
  int get itemCount => state.fold(0, (s, l) => s + l.quantity);

  bool get hasBlockingPrice =>
      state.any((l) => l.unitSell < l.unitBuy);

  /// Completes sale: decrement stock, clear cart. Returns false if validation fails.
  /// Optional [recordRevenue] / [recordProfit] override ledger totals (e.g. after checkout discounts & tax).
  bool completeSale({
    double? recordRevenue,
    double? recordProfit,
  }) {
    if (state.isEmpty) return false;
    if (hasBlockingPrice) return false;

    final revenue = subtotal;
    final profit = totalProfit;

    final delta = <String, int>{};
    for (final l in state) {
      delta[l.medicineId] = (delta[l.medicineId] ?? 0) + l.quantity;
    }

    _ref.read(medicineCatalogProvider.notifier).applySale(delta);
    CartLine? topQty;
    for (final l in state) {
      if (topQty == null || l.quantity > topQty.quantity) topQty = l;
    }
    final tenantId = _ref.read(kpmsActiveTenantIdProvider).valueOrNull;
    _ref.read(salesAnalyticsProvider.notifier).recordCheckout(
          revenue: recordRevenue ?? revenue,
          profit: recordProfit ?? profit,
          topSkuName: topQty?.name,
          topSkuQty: topQty?.quantity ?? 0,
          tenantId: tenantId,
        );
    state = const [];
    return true;
  }
}
