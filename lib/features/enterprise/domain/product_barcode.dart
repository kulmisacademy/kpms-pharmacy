/// Additional barcode linked to a medicine SKU (tenant-unique barcode value).
class ProductBarcode {
  const ProductBarcode({
    required this.id,
    required this.barcode,
    required this.medicineId,
    this.label = '',
  });

  final String id;
  final String barcode;
  final String medicineId;
  final String label;

  static String newClientId() =>
      'bc-${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}';

  static String normalize(String raw) => raw.trim();

  ProductBarcode copyWith({
    String? barcode,
    String? medicineId,
    String? label,
  }) {
    return ProductBarcode(
      id: id,
      barcode: barcode ?? this.barcode,
      medicineId: medicineId ?? this.medicineId,
      label: label ?? this.label,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'barcode': barcode,
        'medicineId': medicineId,
        'label': label,
      };

  static ProductBarcode fromJson(Map<String, dynamic> j) => ProductBarcode(
        id: '${j['id']}',
        barcode: normalize('${j['barcode'] ?? ''}'),
        medicineId: '${j['medicineId'] ?? ''}',
        label: '${j['label'] ?? ''}',
      );
}
