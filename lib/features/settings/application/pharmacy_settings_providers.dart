import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/permission_providers.dart';
import '../../../core/persistence/kpms_persistence_log.dart';
import '../../../core/persistence/kpms_tenant_session_secure_store.dart';
import '../../../core/supabase/profile_tenant_gate.dart';
import '../../../core/supabase/supabase_bootstrap.dart';
import '../data/pharmacy_logo_repository.dart';
import '../data/pharmacy_settings_repository.dart';
import '../domain/pharmacy_branding.dart';
import '../domain/pharmacy_tenant.dart';

/// Session row from Supabase (tenant + profile display name for receipts).
typedef PharmacySessionData = ({PharmacyTenant tenant, String? profileFullName});

final pharmacySettingsRepositoryProvider = Provider<PharmacySettingsRepository>(
  (ref) => const PharmacySettingsRepository(),
);

final pharmacyLogoRepositoryProvider = Provider<PharmacyLogoRepository>(
  (ref) => const PharmacyLogoRepository(),
);

/// Profile + tenant for receipts, checkout, and settings.
///
/// Uses [AsyncNotifier] with **keepAlive** and a **last-good cache** so transient
/// Supabase errors or auth timing do not blank pharmacy branding mid-session.
final pharmacySessionProvider =
    AsyncNotifierProvider<PharmacySessionNotifier, PharmacySessionData?>(PharmacySessionNotifier.new);

class PharmacySessionNotifier extends AsyncNotifier<PharmacySessionData?> {
  PharmacySessionData? _lastGood;
  String? _lastGoodUserId;

  /// Release builds are slower on cold start (secure storage, JIT off); allow more time.
  static Duration get _restoreTimeout =>
      kReleaseMode ? const Duration(seconds: 32) : const Duration(seconds: 12);

  Future<void> _warmSecureSnapshot() async {
    if (kReleaseMode) {
      await Future<void>.delayed(const Duration(milliseconds: 80));
    }
    try {
      await KpmsTenantSessionSecureStore.read();
    } catch (e, st) {
      debugPrint('PharmacySessionNotifier: secure snapshot warm failed: $e\n$st');
    }
  }

  Future<void> _warmTenantGate(String uid) async {
    final client = SupabaseBootstrap.clientOrNull;
    if (client == null) return;
    KpmsPersistenceLog.tenantRestorationStarted();
    try {
      await ProfileTenantGate.hasTenantLinked(client, uid).timeout(_restoreTimeout);
      KpmsPersistenceLog.tenantRestorationCompleted(
        tenantId: ProfileTenantGate.cachedTenantId(uid),
      );
    } on TimeoutException {
      KpmsPersistenceLog.tenantRestorationTimeout();
    }
  }

  Future<PharmacySessionData?> _loadWithRetries(PharmacySettingsRepository repo) async {
    const maxAttempts = 3;
    Object? lastError;
    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      if (attempt > 0) {
        final ms = (180 * (1 << (attempt - 1))).clamp(180, 1600);
        await Future<void>.delayed(Duration(milliseconds: ms));
        if (kReleaseMode) {
          debugPrint('PharmacySessionNotifier: retry loadMyPharmacy attempt ${attempt + 1}/$maxAttempts');
        }
      }
      try {
        final v = await repo.loadMyPharmacy().timeout(_restoreTimeout);
        if (v != null) return v;
      } on TimeoutException catch (e) {
        lastError = e;
        KpmsPersistenceLog.tenantRestorationTimeout();
        continue;
      } catch (e) {
        lastError = e;
        continue;
      }
    }
    if (lastError != null) {
      debugPrint('PharmacySessionNotifier: loadMyPharmacy exhausted retries: $lastError');
    }
    return null;
  }

  @override
  Future<PharmacySessionData?> build() async {
    ref.keepAlive();

    final uid = ref.watch(supabaseAuthUserIdProvider).valueOrNull;
    if (uid == null) {
      _lastGood = null;
      _lastGoodUserId = null;
      return null;
    }

    await _warmSecureSnapshot();
    await _warmTenantGate(uid);

    final repo = ref.read(pharmacySettingsRepositoryProvider);
    try {
      final v = await _loadWithRetries(repo);
      if (v != null) {
        _lastGood = v;
        _lastGoodUserId = uid;
        return v;
      }
      if (_lastGoodUserId == uid && _lastGood != null) {
        debugPrint('PharmacySessionNotifier: load returned null; keeping cached tenant for $uid');
        return _lastGood;
      }
      return null;
    } catch (e, st) {
      debugPrint('PharmacySessionNotifier.build failed: $e\n$st');
      if (_lastGoodUserId == uid && _lastGood != null) {
        return _lastGood;
      }
      rethrow;
    }
  }

  /// Re-fetch from Supabase (e.g. after updating tenant in settings).
  Future<void> reload() async {
    final repo = ref.read(pharmacySettingsRepositoryProvider);
    final uid = ref.read(supabaseAuthUserIdProvider).valueOrNull;
    if (uid == null) {
      state = const AsyncValue.data(null);
      return;
    }

    await _warmSecureSnapshot();
    await _warmTenantGate(uid);

    final previous = state.valueOrNull ?? (_lastGoodUserId == uid ? _lastGood : null);
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      try {
        final v = await _loadWithRetries(repo);
        if (v != null) return v;
        return previous;
      } catch (e) {
        if (_lastGoodUserId == uid && _lastGood != null) {
          debugPrint('PharmacySessionNotifier.reload: error, using cache: $e');
          return _lastGood;
        }
        if (previous != null) return previous;
        rethrow;
      }
    });
    final v = state.valueOrNull;
    if (v != null) {
      _lastGood = v;
      _lastGoodUserId = uid;
    }
  }
}

/// Synchronous branding for widgets (defaults until tenant loads).
final pharmacyBrandingProvider = Provider<PharmacyBranding>((ref) {
  final async = ref.watch(pharmacySessionProvider);
  final data = async.valueOrNull;
  return PharmacyBranding.fromTenantAndProfile(
    tenant: data?.tenant,
    profileFullName: data?.profileFullName,
  );
});
