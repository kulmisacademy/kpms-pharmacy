import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_bootstrap.dart';
import '../domain/staff_member.dart';

class StaffRepository {
  const StaffRepository();

  SupabaseClient? get _c => SupabaseBootstrap.clientOrNull;

  Future<List<StaffMember>> listTenantStaff() async {
    final c = _c!;
    final uid = c.auth.currentUser?.id;
    if (uid == null) return [];

    try {
      await c.rpc('ensure_my_profile');
    } catch (_) {}

    final me = await c.from('profiles').select('tenant_id').eq('id', uid).maybeSingle();
    final tid = me?['tenant_id'];
    if (tid == null) return [];

    final rows = await c
        .from('profiles')
        .select('id, full_name, account_email, phone, role, staff_status, permissions, last_sign_in_at')
        .eq('tenant_id', tid)
        .order('full_name')
        .limit(2000);
    return [for (final r in (rows as List)) StaffMember.fromRow(Map<String, dynamic>.from(r as Map))];
  }

  Future<String> createInvitation({
    required String email,
    required String fullName,
    required String phone,
    required String role,
    required Map<String, dynamic> permissions,
  }) async {
    final c = _c!;
    final res = await c.rpc(
      'create_staff_invitation',
      params: {
        'p_email': email.trim(),
        'p_full_name': fullName.trim(),
        'p_phone': phone.trim(),
        'p_role': role.trim(),
        'p_permissions': permissions,
      },
    );
    return '$res'.trim();
  }

  Future<void> updateStaffProfile({
    required String staffId,
    String? fullName,
    String? phone,
    String? staffStatus,
    Map<String, dynamic>? permissions,
    String? role,
  }) async {
    final c = _c!;
    await c.rpc(
      'update_tenant_staff_profile',
      params: {
        'p_staff_id': staffId,
        'p_full_name': fullName,
        'p_phone': phone,
        'p_staff_status': staffStatus,
        'p_permissions': permissions,
        'p_role': role,
      },
    );
  }

  Future<({String email, String? fullName})?> peekInvitation(String token) async {
    final c = _c;
    if (c == null) return null;
    try {
      final rows = await c.rpc(
        'peek_staff_invitation',
        params: {'p_token': token.trim()},
      );
      if (rows is List && rows.isNotEmpty) {
        final m = Map<String, dynamic>.from(rows.first as Map);
        return (email: '${m['email']}', fullName: m['full_name'] as String?);
      }
      if (rows is Map) {
        final m = Map<String, dynamic>.from(rows);
        return (email: '${m['email']}', fullName: m['full_name'] as String?);
      }
    } catch (e, st) {
      debugPrint('peek_staff_invitation: $e\n$st');
    }
    return null;
  }

  Future<void> claimInvitation(String token) async {
    final c = _c!;
    await c.rpc('claim_staff_invitation', params: {'p_token': token.trim()});
  }

  Future<StaffMember?> fetchStaffMember(String staffId) async {
    final c = _c;
    if (c == null) return null;
    final row = await c
        .from('profiles')
        .select('id, full_name, account_email, phone, role, staff_status, permissions, last_sign_in_at')
        .eq('id', staffId)
        .maybeSingle();
    if (row == null) return null;
    return StaffMember.fromRow(Map<String, dynamic>.from(row));
  }

  Future<void> sendPasswordResetEmail(String email) async {
    final c = _c;
    if (c == null) return;
    try {
      await c.functions.invoke(
        'request-password-reset',
        body: {'email': email.trim()},
      );
    } on FunctionException catch (e) {
      if (e.status == 404) {
        throw Exception('edge_function_not_deployed');
      }
      final map = _staffFnJson(e.details);
      final err = map?['error'];
      if (err is String && err.isNotEmpty) {
        throw Exception(err);
      }
      if (e.status == 429) {
        throw Exception('rate_limited');
      }
      throw Exception('service_unavailable');
    }
  }

  Map<String, dynamic>? _staffFnJson(dynamic data) {
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    if (data is String) {
      try {
        final o = jsonDecode(data);
        if (o is Map) return Map<String, dynamic>.from(o);
      } catch (_) {}
    }
    return null;
  }

  /// Best-effort audit row (RPC may be absent until migration is applied).
  Future<void> tryLogActivity({
    required String action,
    String? entityType,
    String? entityRef,
    Map<String, dynamic>? metadata,
  }) async {
    final c = _c;
    if (c == null) return;
    try {
      await c.rpc(
        'log_staff_activity',
        params: {
          'p_action': action,
          'p_entity_type': entityType,
          'p_entity_ref': entityRef,
          'p_metadata': metadata ?? const <String, dynamic>{},
        },
      );
    } catch (e, st) {
      debugPrint('log_staff_activity: $e\n$st');
    }
  }

  Future<List<Map<String, dynamic>>> listStaffActivity(String staffId, {int limit = 40}) async {
    final c = _c;
    if (c == null) return [];
    try {
      final rows = await c
          .from('staff_activity_log')
          .select('action, entity_type, entity_ref, metadata, created_at')
          .eq('actor_id', staffId)
          .order('created_at', ascending: false)
          .limit(limit);
      return [for (final r in (rows as List)) Map<String, dynamic>.from(r as Map)];
    } catch (e, st) {
      debugPrint('listStaffActivity: $e\n$st');
      return [];
    }
  }

  /// Creates auth user + tenant profile via Edge Function `create-tenant-staff` (deploy with service role).
  Future<void> createStaffAccount({
    required String email,
    required String password,
    required String fullName,
    required String phone,
    required String role,
    required Map<String, dynamic> permissions,
  }) async {
    final c = _c!;
    try {
      final res = await c.functions.invoke(
        'create-tenant-staff',
        body: {
          'email': email.trim(),
          'password': password,
          'full_name': fullName.trim(),
          'phone': phone.trim(),
          'role': role.trim(),
          'permissions': permissions,
        },
      );
      if (res.status != 200) {
        final err = res.data is Map ? (res.data as Map)['error'] : res.data;
        throw Exception(err ?? 'Create staff failed (${res.status})');
      }
    } on FunctionException catch (e) {
      if (e.status == 404) {
        throw Exception(
          'Staff Edge Functions are not deployed. From the repo root run: '
          'supabase functions deploy create-tenant-staff delete-tenant-staff',
        );
      }
      rethrow;
    }
  }

  /// Deletes auth user (cascade profile) via Edge Function `delete-tenant-staff`.
  Future<void> deleteStaffAccount(String staffId) async {
    final c = _c!;
    try {
      final res = await c.functions.invoke(
        'delete-tenant-staff',
        body: {'staff_id': staffId},
      );
      if (res.status != 200) {
        final err = res.data is Map ? (res.data as Map)['error'] : res.data;
        throw Exception(err ?? 'Delete staff failed (${res.status})');
      }
    } on FunctionException catch (e) {
      if (e.status == 404) {
        throw Exception(
          'Staff Edge Functions are not deployed. From the repo root run: '
          'supabase functions deploy create-tenant-staff delete-tenant-staff',
        );
      }
      rethrow;
    }
  }

  Future<void> registerDeviceSession({required String deviceId, String platform = 'android'}) async {
    final c = _c;
    if (c == null) return;
    try {
      await c.rpc(
        'kpms_register_staff_device_session',
        params: {
          'p_device_id': deviceId,
          'p_platform': platform,
        },
      );
    } catch (e, st) {
      debugPrint('registerDeviceSession: $e\n$st');
    }
  }

  Future<List<Map<String, dynamic>>> listMyDeviceSessions() async {
    final c = _c;
    if (c == null) return [];
    try {
      final rows = await c.rpc('kpms_list_my_device_sessions');
      if (rows is List) {
        return [for (final r in rows) Map<String, dynamic>.from(r as Map)];
      }
    } catch (e, st) {
      debugPrint('listMyDeviceSessions: $e\n$st');
    }
    return [];
  }

  Future<void> revokeDeviceSession({required String sessionId}) async {
    final c = _c!;
    await c.rpc('kpms_revoke_staff_device_session', params: {'p_session_id': sessionId});
  }

  Future<void> forceLogoutStaffMember({required String staffId}) async {
    final c = _c!;
    await c.rpc('kpms_force_logout_staff_member', params: {'p_staff_id': staffId});
  }
}
