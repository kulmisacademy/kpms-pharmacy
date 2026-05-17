import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../supabase/supabase_bootstrap.dart';
import 'kpms_permission_context.dart';
import 'kpms_permission_gate.dart';

/// Emits current auth user id so permission providers rebuild on login/logout.
final supabaseAuthUserIdProvider = StreamProvider<String?>((ref) async* {
  final client = SupabaseBootstrap.clientOrNull;
  if (client == null) {
    yield null;
    return;
  }
  String? lastEmitted = client.auth.currentUser?.id;
  yield lastEmitted;
  await for (final state in client.auth.onAuthStateChange) {
    // Some auth events briefly omit session even while refresh completes; never emit null
    // if a session is still attached — avoids wiping permission/tenant providers mid-session.
    final id = state.session?.user.id ?? client.auth.currentSession?.user.id;
    if (id != lastEmitted) {
      lastEmitted = id;
      yield id;
    }
  }
});

/// Role + capability flags for navigation and route guards.
final kpmsPermissionContextProvider = FutureProvider<KpmsPermissionContext>((ref) async {
  final uidFromStream = ref.watch(supabaseAuthUserIdProvider).valueOrNull;
  final client = SupabaseBootstrap.clientOrNull;
  final uid = uidFromStream ?? client?.auth.currentUser?.id;
  if (uid == null || client == null) {
    KpmsPermissionGate.invalidate();
    return KpmsPermissionContext.fromProfileRow(null);
  }
  return KpmsPermissionGate.resolve(client, uid);
});

/// Revenue, profit, and other sensitive business figures (not POS line totals).
final kpmsCanViewFinancialMetricsProvider = Provider<bool>((ref) {
  final p = ref.watch(kpmsPermissionContextProvider).valueOrNull;
  if (p == null) return false;
  if (p.isPlatformSuperAdmin || p.isPharmacyAdminTier) return true;
  return p.features.canViewFinancialMetrics;
});
