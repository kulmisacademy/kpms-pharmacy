import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/kpms_permission_gate.dart';
import '../auth/permission_providers.dart';
import 'pharmacy_operational_gate.dart';
import 'supabase_bootstrap.dart';

/// Non-blocking subscription / grace banner for pharmacy workspace (Super Admin plans).
final pharmacySubscriptionBannerProvider = FutureProvider.autoDispose<String?>((ref) async {
  final client = SupabaseBootstrap.clientOrNull;
  final uid = ref.watch(supabaseAuthUserIdProvider).valueOrNull;
  if (client == null || uid == null) return null;
  final perm = await KpmsPermissionGate.resolve(client, uid);
  if (perm.isPlatformSuperAdmin) return null;
  final st = await PharmacyOperationalGate.resolve(client, uid);
  if (st.blocked) return null;
  final msg = st.subscriptionWarningMessage;
  if (st.subscriptionWarning && msg != null && msg.trim().isNotEmpty) return msg.trim();
  return null;
});
