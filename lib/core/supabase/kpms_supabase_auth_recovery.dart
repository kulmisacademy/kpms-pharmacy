import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../auth/kpms_permission_gate.dart';
import '../monitoring/kpms_auth_health_metrics.dart';
import '../observability/kpms_auth_diagnostics.dart';
import 'supabase_bootstrap.dart';

/// Token lifecycle hooks: keep permission cache aligned with refreshed JWTs without
/// wiping tenant sticky state.
abstract final class KpmsSupabaseAuthRecovery {
  static StreamSubscription<AuthState>? _sub;

  static void install() {
    _sub?.cancel();
    final client = SupabaseBootstrap.clientOrNull;
    if (client == null) return;

    _sub = client.auth.onAuthStateChange.listen((data) {
      final ev = data.event;
      switch (ev) {
        case AuthChangeEvent.tokenRefreshed:
          // Do not invalidate permission/tenant caches on every JWT refresh — causes
          // settings reload loops and empty workspace flashes on mobile.
          KpmsAuthDiagnostics.log('auth_state', {'event': 'token_refreshed'});
          break;
        case AuthChangeEvent.userUpdated:
          KpmsPermissionGate.invalidate();
          KpmsAuthDiagnostics.log('auth_state', {'event': 'user_updated'});
          break;
        case AuthChangeEvent.signedOut:
          KpmsAuthDiagnostics.log('auth_state', {'event': 'signed_out'});
          break;
        default:
          KpmsAuthDiagnostics.log('auth_state', {'event': ev.name});
          break;
      }
    });
  }

  static Future<void> dispose() async {
    await _sub?.cancel();
    _sub = null;
  }

  /// Debounced foreground refresh — one attempt per [minInterval] while a session exists.
  static Future<void> refreshSessionAfterResume({
    Duration debounce = const Duration(milliseconds: 500),
    Duration minInterval = const Duration(seconds: 45),
  }) async {
    await Future<void>.delayed(debounce);
    final client = SupabaseBootstrap.clientOrNull;
    if (client == null) return;
    final session = client.auth.currentSession;
    if (session == null) return;

    // The supabase_flutter SDK already auto-refreshes the token on resume. Calling
    // refreshSession() in parallel rotates the refresh token and can collide with the
    // SDK's in-flight refresh — the loser uses an already-rotated token, GoTrue returns
    // 400, and the user is signed out unexpectedly. So only refresh when the access
    // token has genuinely expired (nothing valid left to collide with); otherwise let
    // the SDK handle it silently.
    if (!session.isExpired) return;

    final now = DateTime.now();
    if (_lastResumeRefresh != null && now.difference(_lastResumeRefresh!) < minInterval) {
      return;
    }
    _lastResumeRefresh = now;

    try {
      await client.auth.refreshSession();
      KpmsAuthHealthMetrics.onResumeRefreshOk();
      KpmsAuthDiagnostics.log('auth_session', {'event': 'resume_refresh_ok'});
    } catch (e, st) {
      KpmsAuthHealthMetrics.onResumeRefreshFail(e, st);
      KpmsAuthDiagnostics.log('auth_session', {'event': 'resume_refresh_fail', 'err': '$e'});
    }
  }

  static DateTime? _lastResumeRefresh;
}
