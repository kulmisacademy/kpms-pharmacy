import 'package:flutter/foundation.dart';

import '../config/kpms_environment.dart';

/// Builds `redirectTo` for Supabase password recovery emails.
///
/// **Web:** same origin + `/reset-password` (add this URL to Supabase Auth redirect allow list).
/// **Mobile:** set `KPMS_AUTH_PASSWORD_RESET_REDIRECT` in env to a universal link / app scheme URL.
abstract final class KpmsAuthRecoveryRedirect {
  static String? build() {
    final custom = KpmsEnvironment.authPasswordResetRedirectUrl?.trim();
    if (custom != null && custom.isNotEmpty) {
      return custom;
    }
    if (kIsWeb) {
      final origin = Uri.base.origin;
      return '$origin/reset-password';
    }
    return null;
  }

  /// `resetPasswordForEmail(redirectTo:)` — **web** uses [build] for SPA recovery links.
  ///
  /// **Mobile:** returns a custom URL only when [KpmsEnvironment.authPasswordResetRedirectUrl] is set
  /// (deep link / universal link). Otherwise returns `null` so recovery emails should use the
  /// **`{{ .Token }}`** OTP template in Supabase (Auth → Emails → Reset password) and users complete
  /// reset inside the app — never `localhost`.
  static String? resetPasswordRedirectOrNull() {
    if (kIsWeb) return build();
    final custom = KpmsEnvironment.authPasswordResetRedirectUrl?.trim();
    if (custom != null && custom.isNotEmpty) return custom;
    return null;
  }
}
