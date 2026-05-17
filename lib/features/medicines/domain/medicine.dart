import 'dart:typed_data';

import 'medicine_form_type.dart';

/// Pharmacy SKU — replace in-memory store with Supabase row mapping later.
class Medicine {
  const Medicine({
    required this.id,
    required this.name,
    this.expiryDate,
    required this.formType,
    this.customFormLabel,
    required this.quantity,
    required this.buyingPrice,
    required this.sellingPrice,
    required this.minimumStockAlert,
    this.imageBytes,
    this.batchCode,
    this.barcode,
  });

  final String id;
  final String name;
  final DateTime? expiryDate;
  final MedicineFormType formType;

  /// When [formType] is [MedicineFormType.other] or user typed a custom subtype label.
  final String? customFormLabel;
  final int quantity;
  final double buyingPrice;
  final double sellingPrice;
  final int minimumStockAlert;
  final Uint8List? imageBytes;
  final String? batchCode;

  /// EAN/UPC or internal barcode — used for POS scan & search.
  final String? barcode;

  bool get isLowStock => quantity <= minimumStockAlert;

  String get typeDisplayName {
    if (formType == MedicineFormType.other && (customFormLabel?.trim().isNotEmpty ?? false)) {
      return customFormLabel!.trim();
    }
    return formType.label;
  }

  Medicine copyWith({
    String? id,
    String? name,
    DateTime? expiryDate,
    MedicineFormType? formType,
    String? customFormLabel,
    int? quantity,
    double? buyingPrice,
    double? sellingPrice,
    int? minimumStockAlert,
    Uint8List? imageBytes,
    String? batchCode,
    String? barcode,
    bool clearImage = false,
    bool clearExpiry = false,
    bool clearCustomLabel = false,
    bool clearBarcode = false,
  }) {
    return Medicine(
      id: id ?? this.id,
      name: name ?? this.name,
      expiryDate: clearExpiry ? null : (expiryDate ?? this.expiryDate),
      formType: formType ?? this.formType,
      customFormLabel: clearCustomLabel ? null : (customFormLabel ?? this.customFormLabel),
      quantity: quantity ?? this.quantity,
      buyingPrice: buyingPrice ?? this.buyingPrice,
      sellingPrice: sellingPrice ?? this.sellingPrice,
      minimumStockAlert: minimumStockAlert ?? this.minimumStockAlert,
      imageBytes: clearImage ? null : (imageBytes ?? this.imageBytes),
      batchCode: batchCode ?? this.batchCode,
      barcode: clearBarcode ? null : (barcode ?? this.barcode),
    );
  }
}
