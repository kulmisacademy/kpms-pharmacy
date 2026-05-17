import '../domain/medicine.dart';

/// Pre-aggregated catalog metrics (O(n) over full catalog; keep off hot search rebuild path).
class MedicineCatalogInsights {
  const MedicineCatalogInsights({
    required this.total,
    required this.inStock,
    required this.lowStock,
    required this.expired,
    required this.expiringSoon,
  });

  final int total;
  final int inStock;
  final int lowStock;
  final int expired;
  final int expiringSoon;

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  static MedicineCatalogInsights compute(List<Medicine> meds, {required int soonWithinDays}) {
    final today = _dateOnly(DateTime.now());
    var inStock = 0;
    var low = 0;
    var exp = 0;
    var soon = 0;
    for (final m in meds) {
      if (m.quantity > 0) inStock++;
      if (m.isLowStock) low++;
      final e = m.expiryDate;
      if (e != null) {
        final ed = _dateOnly(e);
        if (ed.isBefore(today)) {
          exp++;
        } else {
          final diff = ed.difference(today).inDays;
          if (diff >= 0 && diff <= soonWithinDays) soon++;
        }
      }
    }
    return MedicineCatalogInsights(
      total: meds.length,
      inStock: inStock,
      lowStock: low,
      expired: exp,
      expiringSoon: soon,
    );
  }
}
