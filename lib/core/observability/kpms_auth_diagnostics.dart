import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../monitoring/kpms_release_monitoring.dart';

/// Structured auth / tenant restore logging + optional Sentry breadcrumbs (when monitoring is on).
abstract final class KpmsAuthDiagnostics {
  static const String _ns = 'kpms.auth';

  static const _breadcrumbEvents = <String>{
    'tenant_restore',
    'auth_state',
    'auth_session',
    'tenant_gate_full_invalidate',
    'tenant_gate_transient_invalidate',
  };

  static void log(String event, [Map<String, Object?>? fields]) {
    final payload = <String, Object?>{
      't': DateTime.now().toUtc().toIso8601String(),
      'event': event,
      if (fields != null) ...fields,
    };
    if (kDebugMode) {
      try {
        debugPrint('[$_ns] ${jsonEncode(payload)}');
      } catch (_) {
        debugPrint('[$_ns] $event $fields');
      }
    }
    if (KpmsReleaseMonitoring.isReady && _breadcrumbEvents.contains(event)) {
      KpmsReleaseMonitoring.addBreadcrumb('kpms.auth', event, data: fields);
    }
  }
}