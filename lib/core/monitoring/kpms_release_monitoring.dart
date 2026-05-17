import 'package:flutter/foundation.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import '../config/kpms_environment.dart';

/// Production crash + breadcrumb pipeline (Sentry).
///
/// **Firebase Crashlytics:** not wired in-tree (requires `google-services.json` /
/// `GoogleService-Info.plist` + Gradle/iOS plugin). After `flutterfire configure`, forward
/// [captureException] / Flutter fatal errors to `FirebaseCrashlytics.instance` from the same hooks.
abstract final class KpmsReleaseMonitoring {
  static bool _ready = false;

  static bool get isReady => _ready;

  /// Highest precedence: `--dart-define=KPMS_SENTRY_DSN=...`, then bundled env.
  static String resolveSentryDsn() {
    const fromDefine = String.fromEnvironment('KPMS_SENTRY_DSN', defaultValue: '');
    if (fromDefine.trim().isNotEmpty) return fromDefine.trim();
    return (KpmsEnvironment.sentryDsn ?? '').trim();
  }

  /// When [dsn] is empty, runs [bootstrap] immediately. Otherwise wraps with [SentryFlutter.init].
  static Future<void> runWithOptionalSentry(Future<void> Function() bootstrap) async {
    final dsn = resolveSentryDsn();
    if (dsn.isEmpty) {
      await bootstrap();
      return;
    }

    await SentryFlutter.init(
      (options) {
        options.dsn = dsn;
        options.environment = kReleaseMode ? 'production' : 'development';
        options.tracesSampleRate = kReleaseMode ? 0.12 : 0.0;
        options.sendDefaultPii = false;
      },
      appRunner: () async {
        _ready = true;
        await bootstrap();
      },
    );
  }

  static void addBreadcrumb(String category, String message, {Map<String, Object?>? data}) {
    if (!_ready) return;
    try {
      Sentry.addBreadcrumb(
        Breadcrumb(
          category: category,
          message: message,
          data: data,
          level: SentryLevel.info,
          timestamp: DateTime.now().toUtc(),
        ),
      );
    } catch (_) {}
  }

  static Future<void> captureException(
    Object throwable, {
    StackTrace? stackTrace,
    Map<String, Object?>? extras,
  }) async {
    if (!_ready) return;
    try {
      if (extras == null || extras.isEmpty) {
        await Sentry.captureException(throwable, stackTrace: stackTrace);
      } else {
        await Sentry.captureException(
          throwable,
          stackTrace: stackTrace,
          withScope: (scope) {
            scope.setContexts('kpms', Map<String, dynamic>.from(extras));
          },
        );
      }
    } catch (_) {}
  }

  static Future<void> captureFlutterError(FlutterErrorDetails details) async {
    if (!_ready) return;
    try {
      await Sentry.captureException(
        details.exception,
        stackTrace: details.stack,
      );
    } catch (_) {}
  }
}
