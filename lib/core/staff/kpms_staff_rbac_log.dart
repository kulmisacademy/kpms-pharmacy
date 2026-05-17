import 'package:flutter/foundation.dart';

/// Staff / RBAC diagnostics — search `[kpms.staff]` or `[kpms.rbac]`.
abstract final class KpmsStaffRbacLog {
  static const String _staff = '[kpms.staff]';
  static const String _rbac = '[kpms.rbac]';

  static void _emit(String prefix, String step, [String? detail]) {
    final tail = detail == null || detail.isEmpty ? '' : ' | $detail';
    debugPrint('$prefix $step$tail');
  }

  static void staffCreated({required String tenantId, String? staffId}) =>
      _emit(_staff, 'staff_created', 'tenantId=$tenantId${staffId == null ? '' : ' id=$staffId'}');

  static void staffDisabled({required String staffId}) => _emit(_staff, 'staff_disabled', 'id=$staffId');

  static void roleAssigned({required String staffId, required String role}) =>
      _emit(_rbac, 'role_assigned', 'id=$staffId role=$role');

  static void permissionUpdated({required String staffId}) =>
      _emit(_rbac, 'permission_updated', 'id=$staffId');

  static void sessionRevoked({required String sessionId}) =>
      _emit(_staff, 'session_revoked', 'session=$sessionId');

  static void forcedLogout({required String detail}) => _emit(_staff, 'forced_logout', detail);

  static void suspiciousLogin({required String detail}) => _emit(_staff, 'suspicious_login', detail);
}
