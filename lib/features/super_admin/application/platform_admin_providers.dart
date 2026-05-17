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

final superAdminAuditFilterProvider = StateProvider<(String action, String query)>((ref) => ('', ''));

final superAdminAuditProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final repo = ref.watch(platformAdminRepositoryProvider);
  final f = ref.watch(superAdminAuditFilterProvider);
  return repo.listAudit(limit: 200, action: f.$1, query: f.$2);
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
