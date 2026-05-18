import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/bootstrap/kpms_env_validation.dart';
import 'core/config/kpms_environment.dart';
import 'core/monitoring/kpms_release_monitoring.dart';
import 'core/performance/kpms_performance_log.dart';
import 'core/supabase/kpms_supabase_auth_recovery.dart';
import 'core/supabase/supabase_bootstrap.dart';
import 'providers/theme_provider.dart';

void _installGlobalErrorHandlers() {
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    if (kDebugMode) {
      debugPrint('[kpms] FlutterError: ${details.exceptionAsString()}');
    }
    KpmsReleaseMonitoring.captureFlutterError(details);
  };

  PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
    if (kDebugMode) {
      debugPrint('[kpms] PlatformDispatcher.onError: $error\n$stack');
    }
    KpmsReleaseMonitoring.captureException(error, stackTrace: stack);
    return true;
  };

  if (kReleaseMode) {
    ErrorWidget.builder = (FlutterErrorDetails details) {
      return Material(
        color: const Color(0xFFF5F5F5),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Something went wrong.\nPlease restart the app.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade900, fontSize: 16, height: 1.35),
            ),
          ),
        ),
      );
    };
  }
}

Future<void> _bootstrapApp() async {
  final sw = Stopwatch()..start();
  _installGlobalErrorHandlers();
  await Future.wait([
    SupabaseBootstrap.init(),
    preloadInitialThemeMode(),
  ]);
  KpmsSupabaseAuthRecovery.install();
  runApp(const ProviderScope(child: KpmsApp()));
  sw.stop();
  KpmsPerformanceLog.startupCompleted(ms: sw.elapsedMilliseconds);
}

void main() {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    await KpmsEnvironment.load();
    KpmsEnvValidation.logAfterDotenvLoad();

    await KpmsReleaseMonitoring.runWithOptionalSentry(_bootstrapApp);
  }, (Object error, StackTrace stack) {
    KpmsReleaseMonitoring.captureException(error, stackTrace: stack);
    if (kDebugMode) {
      debugPrint('[kpms] Uncaught async error: $error\n$stack');
    }
  });
}
