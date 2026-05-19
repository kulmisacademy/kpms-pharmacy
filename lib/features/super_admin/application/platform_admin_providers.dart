import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/platform_admin_repository.dart';

final platformAdminRepositoryProvider = Provider<PlatformAdminRepository>(
  (ref) => const PlatformAdminRepository(),
);

/// `(search, status)` — `status` one of all|active|suspended|archived.
final superAdminPharmacyDirectoryQueryProvider = StateProvider<(String, String)>((ref) => ('', 'all'));

final superAdminPharmaciesProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final q = ref.watch(superAdminPharmacyDirectoryQueryProvider);
  final repo = ref.watch(platformAdminRepositoryProvider);
  return repo.listPharmacies(search: q.$1, status: q.$2);
});

final superAdminDashboardStatsProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final repo = ref.watch(platformAdminRepositoryProvider);
  return repo.dashboardStats();
});

final superAdminPlatformHealthProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final repo = ref.watch(platformAdminRepositoryProvider);
  return repo.platformHealth();
});

final superAdminPlansProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final repo = ref.watch(platformAdminRepositoryProvider);
  return repo.listPlans();
});

final superAdminAuditFilterProvider = StateProvider<(String action, String query, int days)>((ref) => ('', '', 30));

final superAdminAuditProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final repo = ref.watch(platformAdminRepositoryProvider);
  final f = ref.watch(superAdminAuditFilterProvider);
  final rows = await repo.listAudit(limit: 300, action: f.$1, query: f.$2);
  if (f.$3 <= 0) return rows;
  final cutoff = DateTime.now().subtract(Duration(days: f.$3));
  return rows.where((r) {
    final dt = DateTime.tryParse(r['created_at']?.toString() ?? '');
    return dt == null || dt.isAfter(cutoff);
  }).toList(growable: false);
});

final superAdminUsersProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final repo = ref.watch(platformAdminRepositoryProvider);
  return repo.listUsers(limit: 250);
});

final superAdminGlobalSettingsProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final repo = ref.watch(platformAdminRepositoryProvider);
  return repo.getGlobalSettings();
});

final superAdminPharmacyDetailProvider =
    FutureProvider.autoDispose.family<({Map<String, dynamic>? tenant, Map<String, dynamic>? subscription}), String>(
  (ref, tenantId) async {
    final repo = ref.watch(platformAdminRepositoryProvider);
    final tenant = await repo.fetchTenant(tenantId);
    final sub = await repo.fetchLatestSubscription(tenantId);
    return (tenant: tenant, subscription: sub);
  },
);

final superAdminPharmacyStatsProvider = FutureProvider.autoDispose.family<Map<String, dynamic>, String>(
  (ref, tenantId) => ref.watch(platformAdminRepositoryProvider).pharmacyStats(tenantId),
);

/// Cross-tenant users with client-side filters: `(search, role, tenantId)`.
final superAdminUsersFilterProvider = StateProvider<(String, String, String)>((ref) => ('', '', ''));

final superAdminFilteredUsersProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final repo = ref.watch(platformAdminRepositoryProvider);
  final f = ref.watch(superAdminUsersFilterProvider);
  final rows = await repo.listUsers(limit: 400);
  final q = f.$1.trim().toLowerCase();
  final role = f.$2.trim().toLowerCase();
  final tenant = f.$3.trim();
  return rows.where((r) {
    if (tenant.isNotEmpty && r['tenant_id']?.toString() != tenant) return false;
    if (role.isNotEmpty && (r['role']?.toString().toLowerCase() ?? '') != role) return false;
    if (q.isEmpty) return true;
    final hay = '${r['full_name']} ${r['account_email']} ${r['pharmacy_name']}'.toLowerCase();
    return hay.contains(q);
  }).toList(growable: false);
});

final superAdminTenantStaffProvider = FutureProvider.autoDispose.family<List<Map<String, dynamic>>, String>(
  (ref, tenantId) async {
    final rows = await ref.watch(platformAdminRepositoryProvider).listUsers(limit: 400);
    return rows.where((r) => r['tenant_id']?.toString() == tenantId).toList(growable: false);
  },
);

final superAdminTenantAuditProvider = FutureProvider.autoDispose.family<List<Map<String, dynamic>>, String>(
  (ref, tenantId) async {
    return ref.watch(platformAdminRepositoryProvider).listAudit(limit: 80, query: tenantId);
  },
);
