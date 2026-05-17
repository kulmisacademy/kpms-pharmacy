import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/persistence/kpms_persistence_log.dart';
import '../../../core/persistence/kpms_tenant_session_secure_store.dart';
import '../../../core/settings/kpms_settings_log.dart';
import '../../../core/supabase/auth_user_helpers.dart';
import '../../../core/supabase/profile_tenant_gate.dart';
import '../../../core/supabase/supabase_bootstrap.dart';
import '../domain/pharmacy_tenant.dart';

/// Loads and persists `public.tenants` for the signed-in pharmacy user.
class PharmacySettingsRepository {
  const PharmacySettingsRepository();

  SupabaseClient? get _client => SupabaseBootstrap.clientOrNull;

  Future<({PharmacyTenant tenant, String? profileFullName})?> loadMyPharmacy() async {
    final c = _client;
    final uid = kpmsAuthUserId(c);
    if (c == null || uid == null) return null;

    KpmsSettingsLog.profileQueryStarted();
    KpmsPersistenceLog.tenantRestorationStarted();

    final binding = await ProfileTenantGate.resolveWorkspaceBinding(c, uid);
    if (binding == null) {
      KpmsSettingsLog.profileQueryResult(hasTenant: false);
      KpmsPersistenceLog.tenantQueryResult(hasTenant: false);
      return null;
    }

    KpmsPersistenceLog.tenantQueryResult(hasTenant: true, tenantId: binding.tenantId);

    Map<String, dynamic>? row;
    const maxAttempts = 4;
    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      if (attempt > 0) {
        final ms = (120 * (1 << (attempt - 1))).clamp(120, 1200);
        await Future<void>.delayed(Duration(milliseconds: ms));
      }
      row = await c.from('tenants').select().eq('id', binding.tenantId).maybeSingle();
      if (row != null) break;
    }

    if (row != null) {
      KpmsSettingsLog.profileQueryResult(hasTenant: true, tenantId: binding.tenantId, tenantRow: true);
      KpmsSettingsLog.tenantRestored();
      KpmsPersistenceLog.tenantRestorationCompleted(tenantId: binding.tenantId);
      return (
        tenant: PharmacyTenant.fromRow(row),
        profileFullName: binding.profileFullName,
      );
    }

    // RLS/network hiccup: still expose workspace using binding + secure snapshot name.
    final snap = await KpmsTenantSessionSecureStore.read();
    final name = binding.profileFullName ??
        (snap?.userId == uid ? snap?.pharmacyName : null) ??
        'Pharmacy';

    KpmsSettingsLog.profileQueryResult(hasTenant: true, tenantId: binding.tenantId, tenantRow: false);
    KpmsPersistenceLog.tenantRestorationCompleted(tenantId: binding.tenantId);

    return (
      tenant: PharmacyTenant.fromRow({
        'id': binding.tenantId,
        'name': name,
        'settings': <String, dynamic>{},
      }),
      profileFullName: binding.profileFullName,
    );
  }

  Future<void> updateTenant({
    required String tenantId,
    required String name,
    String? address,
    String? phone,
    String? licenseNumber,
    String? ownerName,
    Map<String, dynamic>? settings,
  }) async {
    final c = _client!;
    final payload = <String, dynamic>{
      'name': name.trim(),
      'address': address?.trim(),
      'phone': phone?.trim(),
      'license_number': licenseNumber?.trim(),
      'owner_name': ownerName?.trim(),
    };
    if (settings != null) payload['settings'] = settings;

    await c.from('tenants').update(payload).eq('id', tenantId);
  }
}
