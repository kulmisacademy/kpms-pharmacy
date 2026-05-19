import 'dart:convert';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/logging/kpms_superadmin_platform_log.dart';
import '../../../core/supabase/supabase_bootstrap.dart';

/// Super Admin platform RPCs and scoped reads (RLS + role checks on server).
class PlatformAdminRepository {
  const PlatformAdminRepository();

  SupabaseClient? get _c => SupabaseBootstrap.clientOrNull;

  Future<({List<Map<String, dynamic>> rows, int total, int limit, int offset})> listPharmaciesPage({
    String search = '',
    String status = 'all',
    int limit = 50,
    int offset = 0,
  }) async {
    final raw = await _c!.rpc(
      'super_admin_list_pharmacies',
      params: {
        'p_search': search.trim().isEmpty ? null : search.trim(),
        'p_status': status.trim().isEmpty ? 'all' : status.trim(),
        'p_limit': limit,
        'p_offset': offset,
      },
    );
    Map<String, dynamic> map;
    if (raw is Map<String, dynamic>) {
      map = raw;
    } else if (raw is Map) {
      map = Map<String, dynamic>.from(raw);
    } else if (raw is String) {
      map = Map<String, dynamic>.from(jsonDecode(raw) as Map);
    } else if (raw is List) {
      final rows = raw.map((e) => Map<String, dynamic>.from(e as Map)).toList(growable: false);
      KpmsPlatformLog.directoryLoaded(rows: rows.length, detail: 'legacy_array');
      return (rows: rows, total: rows.length, limit: rows.length, offset: 0);
    } else {
      return (rows: <Map<String, dynamic>>[], total: 0, limit: limit, offset: offset);
    }

    final rowsRaw = map['rows'];
    final rows = rowsRaw is List
        ? rowsRaw.map((e) => Map<String, dynamic>.from(e as Map)).toList(growable: false)
        : <Map<String, dynamic>>[];
    final total = (map['total'] as num?)?.toInt() ?? rows.length;
    KpmsPlatformLog.directoryLoaded(rows: rows.length, detail: 'total=$total offset=$offset');
    return (
      rows: rows,
      total: total,
      limit: (map['limit'] as num?)?.toInt() ?? limit,
      offset: (map['offset'] as num?)?.toInt() ?? offset,
    );
  }

  /// Back-compat: first page only (max 200 rows server-side).
  Future<List<Map<String, dynamic>>> listPharmacies({
    String search = '',
    String status = 'all',
  }) async {
    final page = await listPharmaciesPage(search: search, status: status, limit: 200, offset: 0);
    return page.rows;
  }

  Future<Map<String, dynamic>> dashboardStats() async {
    final raw = await _c!.rpc('super_admin_dashboard_stats');
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) return Map<String, dynamic>.from(raw);
    return {};
  }

  Future<Map<String, dynamic>> platformHealth() async {
    final raw = await _c!.rpc('super_admin_platform_health');
    KpmsPlatformLog.healthChecked(source: 'super_admin_platform_health');
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) return Map<String, dynamic>.from(raw);
    return {};
  }

  Future<Map<String, dynamic>> pharmacyStats(String tenantId) async {
    final raw = await _c!.rpc('super_admin_get_pharmacy_stats', params: {'p_tenant_id': tenantId});
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) return Map<String, dynamic>.from(raw);
    return {};
  }

  Future<void> updatePharmacy({
    required String tenantId,
    required String name,
    String? address,
    String? phone,
    String? license,
    String? ownerName,
  }) async {
    await _c!.rpc(
      'super_admin_update_pharmacy',
      params: {
        'p_tenant_id': tenantId,
        'p_name': name,
        'p_address': address,
        'p_phone': phone,
        'p_license': license,
        'p_owner_name': ownerName,
      },
    );
  }

  Future<void> suspendPharmacy(String tenantId, String? reason) async {
    await _c!.rpc(
      'super_admin_suspend_pharmacy',
      params: {'p_tenant_id': tenantId, 'p_reason': reason ?? ''},
    );
    KpmsSuperadminLog.pharmacySuspended(tenantId: tenantId, detail: reason);
  }

  Future<void> reactivatePharmacy(String tenantId) async {
    await _c!.rpc('super_admin_reactivate_pharmacy', params: {'p_tenant_id': tenantId});
    KpmsSuperadminLog.pharmacyActivated(tenantId: tenantId);
  }

  Future<void> archivePharmacy(String tenantId) async {
    await _c!.rpc('super_admin_archive_pharmacy', params: {'p_tenant_id': tenantId});
    KpmsSuperadminLog.tenantDisabled(tenantId: tenantId, detail: 'archived');
  }

  Future<void> deletePharmacyHard(String tenantId) async {
    await _c!.rpc('super_admin_delete_pharmacy_hard', params: {'p_tenant_id': tenantId});
    KpmsSuperadminLog.tenantDisabled(tenantId: tenantId, detail: 'hard_deleted');
  }

  Future<void> resetPharmacyAccount(String tenantId) async {
    await _c!.rpc('super_admin_reset_pharmacy_account', params: {'p_tenant_id': tenantId});
  }

  Future<void> forceLogoutTenant(String tenantId) async {
    await _c!.rpc('super_admin_force_logout_tenant', params: {'p_tenant_id': tenantId});
    KpmsSuperadminLog.forcedLogout(tenantId: tenantId);
  }

  Future<void> assignSubscription({
    required String tenantId,
    required String planId,
    DateTime? expiresAt,
    DateTime? graceEndsAt,
    String billingInterval = 'monthly',
    required String paymentStatus,
    required String status,
  }) async {
    await _c!.rpc(
      'super_admin_assign_subscription',
      params: {
        'p_tenant_id': tenantId,
        'p_plan_id': planId,
        'p_expires_at': expiresAt?.toUtc().toIso8601String(),
        'p_payment_status': paymentStatus,
        'p_status': status,
        'p_grace_ends_at': graceEndsAt?.toUtc().toIso8601String(),
        'p_billing_interval': billingInterval,
      },
    );
    KpmsSuperadminLog.subscriptionUpdated(tenantId: tenantId, detail: 'plan=$planId');
  }

  Future<void> setTenantFeatureFlag({
    required String tenantId,
    required String flagKey,
    required Object value,
  }) async {
    await _c!.rpc(
      'super_admin_set_tenant_feature_flag',
      params: {
        'p_tenant_id': tenantId,
        'p_flag_key': flagKey,
        'p_value': value,
      },
    );
    KpmsSuperadminLog.featureFlagChanged(tenantId: tenantId, key: flagKey);
  }

  Future<List<Map<String, dynamic>>> listPlans() async {
    final raw = await _c!.rpc('super_admin_list_plans');
    return _asMapList(raw);
  }

  Future<String> upsertPlan({
    String? id,
    required String slug,
    required String name,
    String? description,
    required int monthlyPriceCents,
    required int yearlyPriceCents,
    required int sortOrder,
    required bool isActive,
    int? maxMedicines,
    int? maxStaff,
    int? maxBranches,
    int? maxStorageMb,
    Map<String, dynamic>? features,
  }) async {
    final raw = await _c!.rpc(
      'super_admin_upsert_plan',
      params: {
        'p_id': id,
        'p_slug': slug,
        'p_name': name,
        'p_description': description,
        'p_monthly_price_cents': monthlyPriceCents,
        'p_sort_order': sortOrder,
        'p_is_active': isActive,
        'p_yearly_price_cents': yearlyPriceCents,
        'p_max_medicines': maxMedicines,
        'p_max_staff': maxStaff,
        'p_max_branches': maxBranches,
        'p_max_storage_mb': maxStorageMb,
        'p_features': features,
      },
    );
    return raw?.toString() ?? '';
  }

  Future<void> deletePlan(String planId) async {
    await _c!.rpc('super_admin_delete_plan', params: {'p_plan_id': planId});
  }

  Future<Map<String, dynamic>> getGlobalSettings() async {
    final raw = await _c!.rpc('super_admin_get_global_settings');
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) return Map<String, dynamic>.from(raw);
    return {};
  }

  Future<void> setGlobalSettings({
    String? brandingAppName,
    String? brandingTagline,
    bool? maintenanceMode,
    String? maintenanceMessage,
    String? globalNotificationTitle,
    String? globalNotificationBody,
    bool? globalNotificationActive,
    int? defaultTrialDays,
  }) async {
    await _c!.rpc(
      'super_admin_set_global_settings',
      params: {
        'p_branding_app_name': brandingAppName,
        'p_branding_tagline': brandingTagline,
        'p_maintenance_mode': maintenanceMode,
        'p_maintenance_message': maintenanceMessage,
        'p_global_notification_title': globalNotificationTitle,
        'p_global_notification_body': globalNotificationBody,
        'p_global_notification_active': globalNotificationActive,
        'p_default_trial_days': defaultTrialDays,
      },
    );
  }

  Future<List<Map<String, dynamic>>> listAudit({
    int limit = 150,
    String action = '',
    String query = '',
  }) async {
    final raw = await _c!.rpc(
      'super_admin_list_audit',
      params: {
        'p_limit': limit,
        'p_action': action.trim().isEmpty ? null : action.trim(),
        'p_query': query.trim().isEmpty ? null : query.trim(),
      },
    );
    return _asMapList(raw);
  }

  Future<List<Map<String, dynamic>>> listUsers({int limit = 200}) async {
    final raw = await _c!.rpc('super_admin_list_users', params: {'p_limit': limit});
    return _asMapList(raw);
  }

  Future<void> publishGlobalNotification({required String title, required String body}) async {
    await _c!.rpc(
      'super_admin_publish_global_notification',
      params: {'p_title': title, 'p_body': body},
    );
    KpmsSuperadminLog.announcementSent(detail: title);
  }

  Future<Map<String, dynamic>?> fetchTenant(String tenantId) async {
    return _c!.from('tenants').select().eq('id', tenantId).maybeSingle();
  }

  Future<Map<String, dynamic>?> fetchLatestSubscription(String tenantId) async {
    final sub = await _c!
        .from('subscriptions')
        .select()
        .eq('tenant_id', tenantId)
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();
    if (sub == null) return null;
    final m = Map<String, dynamic>.from(sub);
    final pid = m['plan_id'];
    if (pid != null) {
      final plan = await _c!.from('subscription_plans').select().eq('id', pid).maybeSingle();
      if (plan != null) {
        m['subscription_plans'] = plan;
      }
    }
    return m;
  }

  List<Map<String, dynamic>> _asMapList(dynamic raw) {
    if (raw is List) {
      return raw.map((e) => Map<String, dynamic>.from(e as Map)).toList(growable: false);
    }
    if (raw is String) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          return decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList(growable: false);
        }
      } catch (_) {}
    }
    return const [];
  }
}
