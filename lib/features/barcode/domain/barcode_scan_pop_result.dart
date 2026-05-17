import '../../medicines/domain/medicine.dart';

/// Result when leaving the barcode scanner (especially from POS / pharmacy flows).
class BarcodeScanPopResult {
  const BarcodeScanPopResult({
    required this.rawCode,
    this.matchedMedicine,
    this.cartHandledInScanner = false,
    this.openAddMedicine = false,
    this.posSearchOnly = false,
  });

  /// Scanned raw string (trimmed for display / search).
  final String rawCode;

  /// Present when catalog matched by barcode (exact).
  final Medicine? matchedMedicine;

  /// POS: cart was updated inside the scanner (auto-add on).
  final bool cartHandledInScanner;

  /// Caller should open Add Medicine with [rawCode] prefilled.
  final bool openAddMedicine;

  /// POS: only update catalog search — do not add to cart (even if [matchedMedicine] is set).
  final bool posSearchOnly;
}
