import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../constants/app_prefs_keys.dart';
import '../staff/kpms_staff_rbac_log.dart';
import 'kpms_permission_context.dart';
import 'kpms_permission_gate.dart';

/// Persists and enforces [KpmsPermissionContext.permissionRevokeNonce] (forced refresh / logout).
abstract final class KpmsPermissionRevokeSync {
  KpmsPermissionRevokeSync._();

  static String _key(String userId) => '${AppPrefsKeys.permissionRevokeNonce}_$userId';

  /// Call after loading permission context. Signs out when server nonce advanced vs last ack.
  static Future<void> applyAfterResolve(String userId, KpmsPermissionContext ctx) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _key(userId);
    final prev = prefs.getInt(key);
    final server = ctx.permissionRevokeNonce;
    if (prev != null && server > prev) {
      debugPrint('[kpms.rbac] session_revoked | nonce $prev→$server');
      KpmsStaffRbacLog.forcedLogout(detail: 'nonce $prev→$server');
      KpmsPermissionGate.invalidate();
      await clearForUser(userId);
      await Supabase.instance.client.auth.signOut();
      return;
    }
    await prefs.setInt(key, server);
  }

  static Future<void> clearForUser(String? userId) async {
    if (userId == null || userId.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key(userId));
  }
}
