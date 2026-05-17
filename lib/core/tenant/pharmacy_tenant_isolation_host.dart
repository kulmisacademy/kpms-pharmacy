import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/enterprise/application/pharmacy_enterprise_bootstrap.dart';
import '../../providers/pharmacy_local_workspace.dart';
import '../auth/permission_providers.dart';
import '../supabase/supabase_bootstrap.dart';
import '../../features/notifications/application/pharmacy_notifications_providers.dart';
import '../../features/pharmacy_cloud/application/pharmacy_cloud_providers.dart';
import '../notifications/pharmacy_notification_signal_provider.dart';
import 'pharmacy_workspace_isolation.dart';

/// Watches auth + tenant changes; clears in-memory workspace to prevent cross-pharmacy leakage.
class PharmacyTenantIsolationHost extends ConsumerStatefulWidget {
  const PharmacyTenantIsolationHost({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<PharmacyTenantIsolationHost> createState() => _PharmacyTenantIsolationHostState();
}

class _PharmacyTenantIsolationHostState extends ConsumerState<PharmacyTenantIsolationHost> {
  String? _lastUserId;
  String? _lastTenantId;

  @override
  Widget build(BuildContext context) {
    final uid = ref.watch(supabaseAuthUserIdProvider).valueOrNull;
    final tenantId = ref.watch(kpmsActiveTenantIdProvider).valueOrNull;

    if (uid == null) {
      if (_lastUserId != null) {
        resetTenantSessionCaches(ref, reason: 'signed_out');
        ref.invalidate(pharmacyWorkspaceBootstrapProvider);
        ref.invalidate(pharmacyEnterpriseBootstrapProvider);
        _invalidateNotificationCaches(ref);
        _lastUserId = null;
        _lastTenantId = null;
      }
    } else if (_lastUserId != null && _lastUserId != uid) {
      resetTenantSessionCaches(ref, reason: 'user_changed');
      ref.invalidate(pharmacyWorkspaceBootstrapProvider);
      ref.invalidate(pharmacyEnterpriseBootstrapProvider);
      _invalidateNotificationCaches(ref);
      _lastUserId = uid;
      _lastTenantId = null;
    } else {
      _lastUserId = uid;
    }

    if (uid != null && tenantId != null && tenantId.isNotEmpty && _lastTenantId != tenantId) {
      if (_lastTenantId != null) {
        clearOperationalWorkspace(ref, reason: 'tenant_id_changed');
        ref.invalidate(pharmacyWorkspaceBootstrapProvider);
        ref.invalidate(pharmacyEnterpriseBootstrapProvider);
        _invalidateNotificationCaches(ref);
      }
      _lastTenantId = tenantId;
    }

    ref.listen<AsyncValue<String?>>(supabaseAuthUserIdProvider, (prev, next) {
      final p = prev?.valueOrNull;
      final n = next.valueOrNull;
      if (p != n) {
        resetTenantSessionCaches(ref, reason: p == null ? 'signed_in' : (n == null ? 'signed_out' : 'user_changed'));
        ref.invalidate(pharmacyWorkspaceBootstrapProvider);
        ref.invalidate(pharmacyEnterpriseBootstrapProvider);
        _invalidateNotificationCaches(ref);
        ref.read(pharmacyCloudSyncGenerationProvider.notifier).state++;
        _lastUserId = n;
        _lastTenantId = null;
      }
    });

    return widget.child;
  }

  void _invalidateNotificationCaches(WidgetRef ref) {
    ref.read(pharmacyCloudNotificationSignalProvider.notifier).state = 0;
    ref.invalidate(pharmacyNotificationFeedProvider);
    ref.invalidate(pharmacyNotificationUnreadCountProvider);
  }
}

/// Must wrap app inside [ProviderScope].
class PharmacyAuthIsolationListener extends ConsumerStatefulWidget {
  const PharmacyAuthIsolationListener({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<PharmacyAuthIsolationListener> createState() => _PharmacyAuthIsolationListenerState();
}

class _PharmacyAuthIsolationListenerState extends ConsumerState<PharmacyAuthIsolationListener> {
  @override
  void initState() {
    super.initState();
    final client = SupabaseBootstrap.clientOrNull;
    if (client != null) {
      client.auth.onAuthStateChange.listen((state) {
        if (state.event == AuthChangeEvent.signedOut) {
          if (!mounted) return;
          resetTenantSessionCaches(ref, reason: 'auth_signed_out');
          ref.invalidate(pharmacyWorkspaceBootstrapProvider);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
