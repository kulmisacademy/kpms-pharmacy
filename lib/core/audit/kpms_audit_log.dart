import 'package:flutter/foundation.dart';

/// Audit trail diagnostics — search `[kpms.audit]`.
abstract final class KpmsAuditLog {
  static const String _p = '[kpms.audit]';

  static void _emit(String step, [String? detail]) {
    final tail = detail == null || detail.isEmpty ? '' : ' | $detail';
    debugPrint('$_p $step$tail');
  }

  static void writeStarted(String action, {String? entityType}) =>
      _emit('write_started', '$action entity=${entityType ?? "—"}');

  static void writeCompleted(String action, {String? entityRef}) =>
      _emit('write_completed', '$action ref=${entityRef ?? "—"}');

  static void writeFailed(String action, Object error) => _emit('write_failed', '$action $error');

  static void queuedOffline(String action) => _emit('queued_offline', action);
}
