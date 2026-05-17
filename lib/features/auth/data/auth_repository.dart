import 'dart:convert';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/persistence/kpms_tenant_session_secure_store.dart';
import '../../../core/auth/kpms_permission_gate.dart';
import '../../../core/auth/kpms_permission_revoke_sync.dart';
import '../../../core/supabase/profile_tenant_gate.dart';
import '../../../core/supabase/supabase_bootstrap.dart';

/// Supabase Auth + profile RPCs. The app only runs when Supabase is configured; [isAvailable] is still useful for tests.
class AuthRepository {
  const AuthRepository();

  SupabaseClient? get _client => SupabaseBootstrap.clientOrNull;

  /// Supabase returns 422 / `email_exists` when signup uses an email that already has an account.
  bool isDuplicateSignupError(AuthException e) {
    final code = e.code?.toLowerCase();
    if (code == 'email_exists' ||
        code == 'user_already_exists' ||
        code == 'identity_already_exists') {
      return true;
    }
    if (e.statusCode == '422') return true;
    final m = e.message.toLowerCase();
    return m.contains('already registered') ||
        m.contains('already exists') ||
        m.contains('user already');
  }

  bool get isAvailable => _client != null;

  Map<String, dynamic>? _functionJson(dynamic data) {
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    if (data is String) {
      try {
        final o = jsonDecode(data);
        if (o is Map) return Map<String, dynamic>.from(o);
      } catch (_) {}
    }
    return null;
  }

  /// `functions.invoke` throws [FunctionException] for any status outside 2xx — map body to [Exception] codes.
  Never _throwFromFunctionException(FunctionException e) {
    if (e.status == 404) {
      throw Exception('edge_function_not_deployed');
    }
    final map = _functionJson(e.details);
    if (map != null) {
      final err = map['error'] ?? map['message'];
      if (err is String && err.isNotEmpty) {
        throw Exception(err);
      }
    }
    if (e.status == 429) {
      throw Exception('rate_limited');
    }
    throw Exception('service_unavailable');
  }

  User? get currentUser => _client?.auth.currentUser;

  Session? get currentSession => _client?.auth.currentSession;

  Stream<AuthState> get onAuthStateChange =>
      _client?.auth.onAuthStateChange ?? const Stream<AuthState>.empty();

  Future<AuthResponse> signInWithEmail({
    required String email,
    required String password,
  }) async {
    final c = _client!;
    // Do not refresh here — extra token calls hit Auth rate limits on web; sign-in already sets the session.
    return c.auth.signInWithPassword(email: email.trim(), password: password);
  }

  Future<void> signOut() async {
    final uid = _client?.auth.currentUser?.id;
    await KpmsPermissionRevokeSync.clearForUser(uid);
    await KpmsTenantSessionSecureStore.clear();
    await _client?.auth.signOut();
    KpmsPermissionGate.invalidate();
    ProfileTenantGate.invalidate();
  }

  /// Sends a 6-digit OTP via Edge Function + custom SMTP (no Supabase recovery links).
  /// Returns server-reported expiry when present (for UI countdown).
  Future<DateTime?> sendPasswordResetEmail(String email) async {
    final c = _client!;
    try {
      final res = await c.functions.invoke(
        'request-password-reset',
        body: {'email': email.trim()},
      );
      final map = _functionJson(res.data);
      final exp = map?['expires_at'] as String?;
      if (exp != null) return DateTime.tryParse(exp);
      return null;
    } on FunctionException catch (e) {
      _throwFromFunctionException(e);
    }
  }

  /// Verifies OTP; returns a short-lived **challenge token** for [completePasswordResetWithChallenge].
  Future<String> verifyPasswordRecoveryOtp({
    required String email,
    required String token,
  }) async {
    final c = _client!;
    try {
      final res = await c.functions.invoke(
        'verify-password-reset-otp',
        body: {'email': email.trim(), 'code': token.trim()},
      );
      final map = _functionJson(res.data);
      final ch = map?['challenge_token'] as String?;
      if (ch != null && ch.isNotEmpty) return ch;
      throw Exception('service_unavailable');
    } on FunctionException catch (e) {
      _throwFromFunctionException(e);
    }
  }

  /// Final step: set new password using challenge from [verifyPasswordRecoveryOtp].
  Future<void> completePasswordResetWithChallenge({
    required String email,
    required String challengeToken,
    required String newPassword,
  }) async {
    final c = _client!;
    try {
      await c.functions.invoke(
        'complete-password-reset',
        body: {
          'email': email.trim(),
          'challenge_token': challengeToken,
          'password': newPassword,
        },
      );
    } on FunctionException catch (e) {
      _throwFromFunctionException(e);
    }
  }

  /// Updates password for the signed-in user (session must be valid).
  Future<void> updatePassword(String newPassword) async {
    final c = _client!;
    await c.auth.updateUser(UserAttributes(password: newPassword));
  }

  Future<void> resendSignupEmail({required String email}) async {
    final c = _client!;
    await c.auth.resend(type: OtpType.signup, email: email.trim());
  }

  Future<AuthResponse> signUpWithEmail({
    required String email,
    required String password,
    String? fullName,
  }) async {
    final c = _client!;
    final meta = fullName?.trim();
    if (meta != null && meta.isNotEmpty) {
      return c.auth.signUp(
        email: email.trim(),
        password: password,
        data: {'full_name': meta},
      );
    }
    return c.auth.signUp(email: email.trim(), password: password);
  }

  /// Creates tenant + subscription and links `profiles.tenant_id` (requires migration RPC).
  Future<void> registerPharmacyTenant({
    required String name,
    required String address,
    required String phone,
    required String license,
    required String owner,
  }) async {
    final c = _client!;
    await c.rpc(
      'register_pharmacy',
      params: {
        'p_name': name,
        'p_address': address,
        'p_phone': phone,
        'p_license': license,
        'p_owner': owner,
      },
    );
  }
}
