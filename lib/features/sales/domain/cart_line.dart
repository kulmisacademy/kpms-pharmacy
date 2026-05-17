/// Single POS line — unit prices copied from [Medicine] at add time (editable sell).
class CartLine {
  CartLine({
    required this.id,
    required this.medicineId,
    required this.name,
    required this.quantity,
    required this.unitBuy,
    required this.unitSell,
  });

  final String id;
  final String medicineId;
  final String name;
  int quantity;
  final double unitBuy;
  double unitSell;

  double get lineSubtotal => quantity * unitSell;
  double get lineProfit => quantity * (unitSell - unitBuy);

  bool get priceViolatesFloor => unitSell < unitBuy;

  CartLine copyWith({
    int? quantity,
    double? unitSell,
  }) {
    return CartLine(
      id: id,
      medicineId: medicineId,
      name: name,
      quantity: quantity ?? this.quantity,
      unitBuy: unitBuy,
      unitSell: unitSell ?? this.unitSell,
    );
  }
}
