/// Tenant-scoped operational expense.
class PharmacyExpense {
  const PharmacyExpense({
    required this.id,
    required this.category,
    required this.amount,
    required this.note,
    required this.issuedAt,
    this.createdBy,
    this.createdAt,
  });

  final String id;
  final String category;
  final double amount;
  final String note;
  final DateTime issuedAt;
  final String? createdBy;
  final DateTime? createdAt;

  static String newClientId() =>
      'exp-${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}';

  PharmacyExpense copyWith({
    String? category,
    double? amount,
    String? note,
    DateTime? issuedAt,
  }) {
    return PharmacyExpense(
      id: id,
      category: category ?? this.category,
      amount: amount ?? this.amount,
      note: note ?? this.note,
      issuedAt: issuedAt ?? this.issuedAt,
      createdBy: createdBy,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'category': category,
        'amount': amount,
        'note': note,
        'issuedAt': issuedAt.toUtc().toIso8601String(),
        'createdBy': createdBy,
        'createdAt': createdAt?.toUtc().toIso8601String(),
      };

  static PharmacyExpense fromJson(Map<String, dynamic> j) => PharmacyExpense(
        id: '${j['id']}',
        category: '${j['category'] ?? 'general'}',
        amount: (j['amount'] as num?)?.toDouble() ?? 0,
        note: '${j['note'] ?? ''}',
        issuedAt: DateTime.tryParse('${j['issuedAt']}') ?? DateTime.now(),
        createdBy: j['createdBy'] as String?,
        createdAt: j['createdAt'] != null ? DateTime.tryParse('${j['createdAt']}') : null,
      );
}

/// Built-in expense category labels (tenant may extend via free text).
abstract final class PharmacyExpenseCategories {
  static const general = 'general';
  static const rent = 'rent';
  static const utilities = 'utilities';
  static const payroll = 'payroll';
  static const supplies = 'supplies';
  static const transport = 'transport';
  static const other = 'other';

  static const presets = [general, rent, utilities, payroll, supplies, transport, other];

  static String label(String id) => switch (id) {
        general => 'General',
        rent => 'Rent',
        utilities => 'Utilities',
        payroll => 'Payroll',
        supplies => 'Supplies',
        transport => 'Transport',
        other => 'Other',
        _ => id,
      };
}
