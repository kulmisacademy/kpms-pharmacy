/// Supplier record — in-memory until Supabase.
class Supplier {
  const Supplier({
    required this.id,
    required this.name,
    required this.phone,
    required this.address,
    this.notes = '',
    this.balanceOwed = 0,
  });

  final String id;
  final String name;
  final String phone;
  final String address;
  final String notes;

  /// Amount the pharmacy still owes this supplier (from credit purchases).
  final double balanceOwed;

  Supplier copyWith({
    String? id,
    String? name,
    String? phone,
    String? address,
    String? notes,
    double? balanceOwed,
  }) {
    return Supplier(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      notes: notes ?? this.notes,
      balanceOwed: balanceOwed ?? this.balanceOwed,
    );
  }
}
