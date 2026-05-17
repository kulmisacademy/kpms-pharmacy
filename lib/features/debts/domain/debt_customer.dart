/// Customer record for AR / on-account sales (in-memory until backend).
class DebtCustomer {
  const DebtCustomer({
    required this.id,
    required this.name,
    required this.phoneDisplay,
    required this.phoneKey,
    this.notes = '',
    required this.createdAt,
  });

  final String id;
  final String name;
  final String phoneDisplay;
  final String phoneKey;
  final String notes;
  final DateTime createdAt;

  DebtCustomer copyWith({
    String? name,
    String? phoneDisplay,
    String? phoneKey,
    String? notes,
  }) {
    return DebtCustomer(
      id: id,
      name: name ?? this.name,
      phoneDisplay: phoneDisplay ?? this.phoneDisplay,
      phoneKey: phoneKey ?? this.phoneKey,
      notes: notes ?? this.notes,
      createdAt: createdAt,
    );
  }
}
