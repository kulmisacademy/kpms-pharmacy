import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../persistence/kpms_persistence_log.dart';
import '../supabase/profile_tenant_gate.dart';
import '../supabase/supabase_bootstrap.dart';
import '../auth/permission_providers.dart';

/// Resolved active pharmacy tenant id (per auth user — never shared across pharmacies).
final kpmsActiveTenantIdProvider = FutureProvider<String?>((ref) async {
  final uid = ref.watch(supabaseAuthUserIdProvider).valueOrNull;
  final client = SupabaseBootstrap.clientOrNull;
  if (uid == null || client == null) return null;

  KpmsPersistenceLog.tenantRestorationStarted();
  try {
    final binding = await ProfileTenantGate.resolveWorkspaceBinding(client, uid).timeout(
      const Duration(seconds: 12),
      onTimeout: () {
        KpmsPersistenceLog.tenantRestorationTimeout();
        return null;
      },
    );
    if (binding == null) return ProfileTenantGate.cachedTenantId(uid);
    KpmsPersistenceLog.tenantRestorationCompleted(tenantId: binding.tenantId);
    return binding.tenantId;
  } catch (e) {
    KpmsPersistenceLog.tenantRestorationTimeout();
    return ProfileTenantGate.cachedTenantId(uid);
  }
});
