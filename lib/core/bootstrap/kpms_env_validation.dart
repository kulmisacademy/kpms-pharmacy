import 'package:flutter/foundation.dart';

import '../config/kpms_environment.dart';
import '../supabase/supabase_bootstrap.dart';

/// Non-sensitive hints after [KpmsEnvironment.load] (debug only).
abstract final class KpmsEnvValidation {
  static void logAfterDotenvLoad() {
    if (!kDebugMode) return;
    if (SupabaseBootstrap.isConfigured) return;
    final err = KpmsEnvironment.loadError;
    if (err != null) {
      debugPrint('[kpms] Environment load error: $err');
    }
    for (final line in KpmsEnvironment.startupIssues) {
      debugPrint('[kpms] $line');
    }
    debugPrint(
      '[kpms] Hint: add `.env` next to pubspec; Android/iOS Debug copies it to assets/env/generated_debug.env. '
      'Web: `dart run tool/kpms_sync_root_env.dart`. Optional: `--dart-define-from-file=.env`.',
    );
  }
}
