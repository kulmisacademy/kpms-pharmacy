import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';

/// Startup diagnostics without printing secrets (URLs/keys are never logged).
abstract final class KpmsEnvDiagnostics {
  static void logAfterEnvLoad({
    required bool releaseMode,
    required bool hadDartDefines,
    required bool hadBundledSupabaseKeys,
    required bool hadIoRootLayer,
    required bool loadedGeneratedDebugAsset,
  }) {
    final msg = 'env: mode=${releaseMode ? "release" : "debug"} '
        'defines=$hadDartDefines '
        'bundledKeys=$hadBundledSupabaseKeys '
        'rootIo=$hadIoRootLayer '
        'generatedDebugAsset=$loadedGeneratedDebugAsset';
    if (kDebugMode) {
      debugPrint('[kpms] $msg');
    }
    developer.log(msg, name: 'kpms');
  }

  static void logSupabaseInitAttempt({required bool configured, required bool succeeded}) {
    final msg = 'supabase: configured=$configured init=${succeeded ? "ok" : "skipped_or_failed"}';
    if (kDebugMode) {
      debugPrint('[kpms] $msg');
    }
    developer.log(msg, name: 'kpms');
  }
}
