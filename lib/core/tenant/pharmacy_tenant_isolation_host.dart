import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/enterprise/application/pharmacy_enterprise_bootstrap.dart';
import '../../providers/pharmacy_local_workspace.dart';
import '../auth/permission_providers.dart';
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
  String? _lastTenantId;

  void _onAuthSessionChanged(String? prevUid, String? nextUid) {
    if (prevUid == nextUid) return;

    if (nextUid == null) {
      resetTenantSessionCaches(ref, reason: 'signed_out');
    } else if (prevUid == null) {
      resetTenantSessionCaches(ref, reason: 'signed_in');
    } else {
      resetTenantSessionCaches(ref, reason: 'user_changed');
    }

    ref.invalidate(pharmacyWorkspaceBootstrapProvider);
    ref.invalidate(pharmacyEnterpriseBootstrapProvider);
    _invalidateNotificationCaches(ref);
    ref.read(pharmacyCloudSyncGenerationProvider.notifier).state++;
    _lastTenantId = null;
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<String?>>(supabaseAuthUserIdProvider, (prev, next) {
      _onAuthSessionChanged(prev?.valueOrNull, next.valueOrNull);
    });

    final uid = ref.watch(supabaseAuthUserIdProvider).valueOrNull;
    final tenantId = ref.watch(kpmsActiveTenantIdProvider).valueOrNull;

    if (uid != null && tenantId != null && tenantId.isNotEmpty && _lastTenantId != tenantId) {
      if (_lastTenantId != null) {
        clearOperationalWorkspace(ref, reason: 'tenant_id_changed');
        ref.invalidate(pharmacyWorkspaceBootstrapProvider);
        ref.invalidate(pharmacyEnterpriseBootstrapProvider);
        _invalidateNotificationCaches(ref);
      }
      _lastTenantId = tenantId;
    } else if (uid == null) {
      _lastTenantId = null;
    }

    return widget.child;
  }

  void _invalidateNotificationCaches(WidgetRef ref) {
    ref.read(pharmacyCloudNotificationSignalProvider.notifier).state = 0;
    ref.invalidate(pharmacyNotificationFeedProvider);
    ref.invalidate(pharmacyNotificationUnreadCountProvider);
  }
}
