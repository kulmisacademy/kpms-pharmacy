import 'package:flutter/foundation.dart';

import '../constants/app_routes.dart';
import 'kpms_role_presets.dart';
import 'staff_feature_access.dart';

/// Parsed `profiles.role`, `staff_status`, and `profiles.permissions` for routing & navigation.
@immutable
class KpmsPermissionContext {
  const KpmsPermissionContext({
    required this.rawRole,
    required this.isPlatformSuperAdmin,
    required this.isPharmacyAdminTier,
    required this.isCashierTier,
    required this.staffActive,
    required this.features,
    this.permissionRevokeNonce = 0,
    this.mustChangePassword = false,
  });

  static int _nonce(Map<String, dynamic>? row) {
    final v = row?['permission_revoke_nonce'];
    if (v is int) return v;
    return int.tryParse('$v') ?? 0;
  }

  static bool _mustPw(Map<String, dynamic>? row) {
    final v = row?['must_change_password'];
    if (v is bool) return v;
    final s = '$v'.toLowerCase();
    return s == 'true' || s == '1';
  }

  factory KpmsPermissionContext.fromProfileRow(Map<String, dynamic>? row) {
    final nonce = _nonce(row);
    final mustPw = _mustPw(row);
    if (row == null) {
      return KpmsPermissionContext(
        rawRole: 'unknown',
        isPlatformSuperAdmin: false,
        isPharmacyAdminTier: false,
        isCashierTier: true,
        staffActive: false,
        features: StaffFeatureAccess.fromPermissionsMap(null, whenEmptyUseManagerPreset: false),
        permissionRevokeNonce: 0,
        mustChangePassword: false,
      );
    }

    final raw = (row['role'] as String?)?.trim().toLowerCase() ?? '';
    final status = (row['staff_status'] as String?)?.trim().toLowerCase() ?? 'active';
    final staffActive = status != 'inactive';

    Map<String, dynamic>? permMap;
    final p = row['permissions'];
    if (p is Map<String, dynamic>) {
      permMap = p;
    } else if (p is Map) {
      permMap = Map<String, dynamic>.from(p);
    }

    switch (raw) {
      case 'platform_super_admin':
      case 'super_admin':
        return KpmsPermissionContext(
          rawRole: 'platform_super_admin',
          isPlatformSuperAdmin: true,
          isPharmacyAdminTier: false,
          isCashierTier: false,
          staffActive: staffActive,
          features: StaffFeatureAccess.tenantAdmin(),
          permissionRevokeNonce: nonce,
          mustChangePassword: mustPw,
        );
      case 'pharmacy_owner':
      case 'pharmacist':
      case 'pharmacy_admin':
        return KpmsPermissionContext(
          rawRole: raw.isEmpty ? 'pharmacist' : raw,
          isPlatformSuperAdmin: false,
          isPharmacyAdminTier: true,
          isCashierTier: false,
          staffActive: staffActive,
          features: StaffFeatureAccess.tenantAdmin(),
          permissionRevokeNonce: nonce,
          mustChangePassword: mustPw,
        );
      case 'cashier':
      case 'staff':
        return KpmsPermissionContext(
          rawRole: raw.isEmpty ? 'staff' : raw,
          isPlatformSuperAdmin: false,
          isPharmacyAdminTier: false,
          isCashierTier: true,
          staffActive: staffActive,
          features: StaffFeatureAccess.fromPermissionsMap(permMap, whenEmptyUseManagerPreset: false),
          permissionRevokeNonce: nonce,
          mustChangePassword: mustPw,
        );
      case 'manager':
        return KpmsPermissionContext(
          rawRole: 'manager',
          isPlatformSuperAdmin: false,
          isPharmacyAdminTier: false,
          isCashierTier: false,
          staffActive: staffActive,
          features: StaffFeatureAccess.fromPermissionsMap(permMap, whenEmptyUseManagerPreset: true),
          permissionRevokeNonce: nonce,
          mustChangePassword: mustPw,
        );
      case 'clinical_pharmacist':
      case 'accountant':
      case 'inventory_manager':
        final merged = KpmsRolePresets.mergeRoleDefaults(raw, permMap);
        return KpmsPermissionContext(
          rawRole: raw,
          isPlatformSuperAdmin: false,
          isPharmacyAdminTier: false,
          isCashierTier: false,
          staffActive: staffActive,
          features: StaffFeatureAccess.fromPermissionsMap(merged, whenEmptyUseManagerPreset: false),
          permissionRevokeNonce: nonce,
          mustChangePassword: mustPw,
        );
      default:
        return KpmsPermissionContext(
          rawRole: raw.isEmpty ? 'unknown' : raw,
          isPlatformSuperAdmin: false,
          isPharmacyAdminTier: false,
          isCashierTier: true,
          staffActive: staffActive,
          features: StaffFeatureAccess.fromPermissionsMap(permMap, whenEmptyUseManagerPreset: false),
          permissionRevokeNonce: nonce,
          mustChangePassword: mustPw,
        );
    }
  }

  final String rawRole;
  final bool isPlatformSuperAdmin;
  final bool isPharmacyAdminTier;
  final bool isCashierTier;
  final bool staffActive;
  final StaffFeatureAccess features;

  /// Server-side [profiles.permission_revoke_nonce] (forced logout / RBAC refresh).
  final int permissionRevokeNonce;

  /// When true, router nudges user to profile / password change (invite flow).
  final bool mustChangePassword;

  bool get canManageStaffDirectory => isPharmacyAdminTier || features.canManageStaffDirectory;

  String get defaultLandingRoute {
    if (isPlatformSuperAdmin) return AppRoutes.superAdmin;
    if (!staffActive) return AppRoutes.login;
    if (isPharmacyAdminTier) return AppRoutes.home;
    return features.defaultWorkspaceRoute;
  }

  String get safeFallbackRoute => defaultLandingRoute;

  bool canAccessLocation(String location) {
    if (isPlatformSuperAdmin) {
      if (location == AppRoutes.superAdminLogin) return false;
      return location.startsWith(AppRoutes.superAdmin);
    }

    if (location.startsWith(AppRoutes.superAdmin)) {
      return false;
    }

    if (location == AppRoutes.resetPassword || location == AppRoutes.forgotPassword) {
      return true;
    }

    if (!staffActive) {
      if (location.startsWith(AppRoutes.login) ||
          location.startsWith(AppRoutes.splash) ||
          location.startsWith(AppRoutes.forgotPassword)) {
        return true;
      }
      return false;
    }

    if (location.startsWith(AppRoutes.joinStaff)) {
      return true;
    }

    if (location == AppRoutes.staffCreate ||
        location.startsWith(AppRoutes.staffInvite) ||
        (location.startsWith('${AppRoutes.staff}/') && location.endsWith('/edit'))) {
      return canManageStaffDirectory;
    }
    final staffProfileMatch = RegExp(r'^/app/staff/([^/]+)$').firstMatch(location);
    if (staffProfileMatch != null) {
      final seg = staffProfileMatch.group(1)!;
      if (seg != 'create' && seg != 'invite') {
        return canManageStaffDirectory;
      }
    }

    if (isPharmacyAdminTier) {
      return true;
    }

    return features.canAccessRoute(location);
  }

  /// Bottom dock: fourth shortcut is Settings only when explicitly allowed.
  bool get showSettingsInDock => isPharmacyAdminTier || features.canAccessRoute(AppRoutes.settings);
}
