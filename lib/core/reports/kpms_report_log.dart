import 'package:flutter/foundation.dart';

/// Report / export diagnostics — search `[kpms.report]`.
abstract final class KpmsReportLog {
  static const String _p = '[kpms.report]';

  static void _emit(String step, [String? detail]) {
    final tail = detail == null || detail.isEmpty ? '' : ' | $detail';
    debugPrint('$_p $step$tail');
  }

  static void reportGenerated(String reportSlug, {required String tenantId}) =>
      _emit('report_generated', 'slug=$reportSlug tenantId=$tenantId');

  static void exportStarted({required String reportSlug, required String format, required String tenantId}) =>
      _emit('export_started', 'slug=$reportSlug format=$format tenantId=$tenantId');

  static void exportCompleted({required String reportSlug, required String format, required String tenantId}) =>
      _emit('export_completed', 'slug=$reportSlug format=$format tenantId=$tenantId');
}
