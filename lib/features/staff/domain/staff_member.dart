import 'package:flutter/foundation.dart';

/// Row from `profiles` for tenant staff directory.
@immutable
class StaffMember {
  const StaffMember({
    required this.id,
    required this.fullName,
    this.email,
    this.phone,
    required this.role,
    required this.staffStatus,
    required this.permissions,
    this.lastSignInAt,
  });

  final String id;
  final String fullName;

  /// Denormalized from `profiles.account_email` (sign-in address).
  final String? email;
  final String? phone;
  final String role;
  final String staffStatus;
  final Map<String, dynamic> permissions;
  final DateTime? lastSignInAt;

  factory StaffMember.fromRow(Map<String, dynamic> row) {
    Map<String, dynamic> perms = {};
    final p = row['permissions'];
    if (p is Map<String, dynamic>) {
      perms = p;
    } else if (p is Map) {
      perms = Map<String, dynamic>.from(p);
    }
    DateTime? last;
    final ls = row['last_sign_in_at'];
    if (ls is String) last = DateTime.tryParse(ls);

    final em = row['account_email'];
    final emailStr = em != null && '$em'.trim().isNotEmpty ? '$em'.trim() : null;

    return StaffMember(
      id: '${row['id']}',
      fullName: '${row['full_name'] ?? '—'}'.trim().isEmpty ? '—' : '${row['full_name']}'.trim(),
      email: emailStr,
      phone: row['phone'] != null ? '${row['phone']}'.trim() : null,
      role: '${row['role'] ?? 'staff'}',
      staffStatus: '${row['staff_status'] ?? 'active'}',
      permissions: perms,
      lastSignInAt: last,
    );
  }

  String get permissionsSummary {
    if (permissions.isEmpty) return 'Default';
    final n = permissions.entries.where((e) => e.value == true).length;
    return '$n enabled';
  }
}
