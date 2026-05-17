import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/notifications/pharmacy_notification_signal_provider.dart';
import '../../../core/auth/permission_providers.dart';
import '../../../core/tenant/kpms_active_tenant_provider.dart';
import '../data/pharmacy_notification_repository.dart';
import '../domain/pharmacy_notification_models.dart';

const int _notificationPageSize = 40;

final pharmacyNotificationFeedProvider =
    AsyncNotifierProvider<PharmacyNotificationFeedNotifier, PharmacyNotificationFeedModel>(
  PharmacyNotificationFeedNotifier.new,
);

class PharmacyNotificationFeedNotifier extends AsyncNotifier<PharmacyNotificationFeedModel> {
  @override
  Future<PharmacyNotificationFeedModel> build() async {
    ref.watch(pharmacyCloudNotificationSignalProvider);
    final tid = ref.watch(kpmsActiveTenantIdProvider).valueOrNull;
    final uid = ref.watch(supabaseAuthUserIdProvider).valueOrNull;
    if (tid == null || tid.isEmpty || uid == null) {
      return const PharmacyNotificationFeedModel(items: [], hasMore: false);
    }
    final first = await PharmacyNotificationRepository.fetchWithReadState(
      tenantId: tid,
      userId: uid,
      limit: _notificationPageSize,
      offset: 0,
    );
    return PharmacyNotificationFeedModel(
      items: first,
      hasMore: first.length >= _notificationPageSize,
    );
  }

  Future<void> loadMore() async {
    final cur = state.valueOrNull;
    final tid = ref.read(kpmsActiveTenantIdProvider).valueOrNull;
    final uid = ref.read(supabaseAuthUserIdProvider).valueOrNull;
    if (cur == null || !cur.hasMore || cur.isLoadingMore) return;
    if (tid == null || tid.isEmpty || uid == null) return;

    state = AsyncData(cur.copyWith(isLoadingMore: true));
    try {
      final more = await PharmacyNotificationRepository.fetchWithReadState(
        tenantId: tid,
        userId: uid,
        limit: _notificationPageSize,
        offset: cur.items.length,
      );
      state = AsyncData(
        PharmacyNotificationFeedModel(
          items: [...cur.items, ...more],
          hasMore: more.length >= _notificationPageSize,
          isLoadingMore: false,
        ),
      );
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  Future<void> refresh() async {
    final u = ref.read(supabaseAuthUserIdProvider).valueOrNull;
    final t = ref.read(kpmsActiveTenantIdProvider).valueOrNull;
    if (u == null || t == null || t.isEmpty) return;
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final first = await PharmacyNotificationRepository.fetchWithReadState(
        tenantId: t,
        userId: u,
        limit: _notificationPageSize,
        offset: 0,
      );
      return PharmacyNotificationFeedModel(
        items: first,
        hasMore: first.length >= _notificationPageSize,
      );
    });
    ref.invalidate(pharmacyNotificationUnreadCountProvider);
  }

  Future<void> markRead(String notificationId) async {
    final u = ref.read(supabaseAuthUserIdProvider).valueOrNull;
    if (u == null) return;
    await PharmacyNotificationRepository.markRead(notificationId: notificationId, userId: u);
    final v = state.valueOrNull;
    if (v != null) {
      final now = DateTime.now().toUtc();
      final nextItems = [
        for (final i in v.items)
          if (i.id == notificationId) i.copyWith(readAt: now) else i,
      ];
      state = AsyncData(v.copyWith(items: nextItems));
    }
    ref.invalidate(pharmacyNotificationUnreadCountProvider);
  }

  Future<void> markAllUnreadRead() async {
    final u = ref.read(supabaseAuthUserIdProvider).valueOrNull;
    if (u == null) return;
    try {
      await PharmacyNotificationRepository.markAllReadForTenant();
    } catch (_) {
      return;
    }
    await refresh();
  }
}

/// Server-backed unread total (survives paginated feed). Invalidates with realtime signal + feed actions.
final pharmacyNotificationUnreadCountProvider = FutureProvider.autoDispose<int>((ref) async {
  ref.watch(pharmacyCloudNotificationSignalProvider);
  final tid = ref.watch(kpmsActiveTenantIdProvider).valueOrNull;
  final uid = ref.watch(supabaseAuthUserIdProvider).valueOrNull;
  if (tid == null || tid.isEmpty || uid == null) return 0;
  return PharmacyNotificationRepository.unreadCount();
});

/// Shell badge + quick guards — synchronous read of async count (0 while loading).
final pharmacyNotificationUnreadCountSyncProvider = Provider<int>((ref) {
  return ref.watch(pharmacyNotificationUnreadCountProvider).valueOrNull ?? 0;
});
