import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_bootstrap.dart';
import '../../settings/application/pharmacy_settings_providers.dart';

/// Active catalog rows for tenant-facing plan cards.
final subscriptionCatalogPlansProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final c = SupabaseBootstrap.clientOrNull;
  if (c == null) return const [];
  final rows = await c.from('subscription_plans').select().eq('is_active', true).order('sort_order');
  return (rows as List<dynamic>).map((e) => Map<String, dynamic>.from(e as Map)).toList(growable: false);
});

/// Current tenant subscription row + joined plan (if any).
final myTenantSubscriptionProvider = FutureProvider.autoDispose<Map<String, dynamic>?>((ref) async {
  final sess = ref.watch(pharmacySessionProvider).valueOrNull;
  final tid = sess?.tenant.id;
  if (tid == null) return null;
  final c = SupabaseBootstrap.clientOrNull;
  if (c == null) return null;
  final sub = await c.from('subscriptions').select().eq('tenant_id', tid).order('created_at', ascending: false).limit(1).maybeSingle();
  if (sub == null) return null;
  final m = Map<String, dynamic>.from(sub);
  final pid = m['plan_id'];
  if (pid != null) {
    final plan = await c.from('subscription_plans').select().eq('id', pid).maybeSingle();
    if (plan != null) {
      m['plan_row'] = plan;
    }
  }
  return m;
});
