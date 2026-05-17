import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// PKCE is required for secure browser auth; also supported on mobile/desktop.

import '../config/kpms_env_diagnostics.dart';
import '../config/kpms_environment.dart';

/// Initializes Supabase using [KpmsEnvironment] (dart-define → bundled assets → project-root `.env*` on desktop).
abstract final class SupabaseBootstrap {
  static String _resolveUrl() => KpmsEnvironment.supabaseUrl?.trim() ?? '';

  static String _resolveAnonKey() => KpmsEnvironment.supabaseAnonKey?.trim() ?? '';

  /// True when URL and anon key resolved (anon / public key only — never service_role).
  static bool get isConfigured => KpmsEnvironment.isConfigured;

  static Future<void> init() async {
    final url = _resolveUrl();
    final key = _resolveAnonKey();
    if (url.isEmpty || key.isEmpty) {
      KpmsEnvDiagnostics.logSupabaseInitAttempt(configured: false, succeeded: false);
      return;
    }
    try {
      await Supabase.initialize(
        url: url,
        anonKey: key,
        authOptions: const FlutterAuthClientOptions(
          authFlowType: AuthFlowType.pkce,
        ),
      );
      KpmsEnvDiagnostics.logSupabaseInitAttempt(configured: true, succeeded: true);
    } catch (e, st) {
      KpmsEnvDiagnostics.logSupabaseInitAttempt(configured: true, succeeded: false);
      debugPrint('Supabase init failed: $e\n$st');
    }
  }

  static SupabaseClient? get clientOrNull {
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }
}
