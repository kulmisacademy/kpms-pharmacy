import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/auth/kpms_permission_gate.dart';
import '../../../core/auth/permission_providers.dart';
import '../../../core/constants/app_prefs_keys.dart';
import '../../../core/constants/app_routes.dart';
import '../../../core/supabase/auth_user_helpers.dart';
import '../../../core/supabase/profile_tenant_gate.dart';
import '../../../core/supabase/supabase_bootstrap.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/kpms_feedback.dart';
import '../../../l10n/l10n_context.dart';
import '../../auth/application/auth_providers.dart';

String? _describeBootstrapFailure(Object e) {
  final lower = e.toString().toLowerCase();
  if (lower.contains('already exists') || lower.contains('operator already')) {
    return 'First-user auto-setup skipped: a platform operator already exists in `profiles`.';
  }
  if (lower.contains('does not exist') || lower.contains('404') || lower.contains('pgrst202')) {
    return 'Bootstrap RPC not found — push migration `20260518120000_bootstrap_platform_super_admin.sql`.';
  }
  if (lower.contains('profile row missing')) {
    return 'No `profiles` row for this login — complete pharmacy signup once or add a profile in SQL.';
  }
  return null;
}

/// Dedicated **platform operator** sign-in (web-style). Pharmacy staff use [AppRoutes.login].
class SuperAdminLoginScreen extends ConsumerStatefulWidget {
  const SuperAdminLoginScreen({super.key, this.initialEmail});

  /// Optional prefilled email (e.g. after pharmacy login detected platform role).
  final String? initialEmail;

  @override
  ConsumerState<SuperAdminLoginScreen> createState() => _SuperAdminLoginScreenState();
}

class _SuperAdminLoginScreenState extends ConsumerState<SuperAdminLoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  bool _rememberDevice = true;

  @override
  void initState() {
    super.initState();
    final pre = widget.initialEmail?.trim();
    if (pre != null && pre.isNotEmpty) {
      _email.text = pre;
    }
    _loadRememberPref();
  }

  Future<void> _loadRememberPref() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _rememberDevice = prefs.getBool(AppPrefsKeys.platformRememberDevice) ?? true;
    });
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    final l = context.l10n;
    final email = _email.text.trim();
    final password = _password.text;
    if (email.isEmpty || !email.contains('@')) {
      kpmsSnack(context, l.validationEmailInvalid, isError: true);
      return;
    }
    if (password.length < 6) {
      kpmsSnack(context, l.validationPasswordLength, isError: true);
      return;
    }
    setState(() => _busy = true);
    try {
      final repo = ref.read(authRepositoryProvider);
      final res = await repo.signInWithEmail(email: email, password: password);
      if (!mounted) return;

      final client = SupabaseBootstrap.clientOrNull;
      if (client == null) return;

      if (kIsWeb) {
        await Future<void>.delayed(const Duration(milliseconds: 80));
      }
      if (!mounted) return;

      final session = res.session ?? client.auth.currentSession;
      final user = session?.user ?? res.user ?? kpmsAuthUser(client);

      if (session == null && user != null && !kpmsEmailVerified(user)) {
        context.go('${AppRoutes.verifyEmail}?email=${Uri.encodeComponent(email)}');
        return;
      }

      if (session != null) {
        ProfileTenantGate.invalidate();
        KpmsPermissionGate.invalidate();
        ref.invalidate(kpmsPermissionContextProvider);
        final uid = user?.id ?? kpmsAuthUserId(client);
        if (uid != null) {
          var perm = await KpmsPermissionGate.resolve(client, uid);
          if (!mounted) return;

          Future<void> finishOperatorSignIn() async {
            final prefs = await SharedPreferences.getInstance();
            await prefs.setBool(AppPrefsKeys.platformRememberDevice, _rememberDevice);
            if (!mounted) return;
            ref.invalidate(kpmsPermissionContextProvider);
            context.go(AppRoutes.superAdmin);
          }

          if (perm.isPlatformSuperAdmin) {
            await finishOperatorSignIn();
            return;
          }

          String? bootstrapDetail;
          try {
            await client.rpc('bootstrap_platform_super_admin_if_vacant');
            KpmsPermissionGate.invalidate();
            ref.invalidate(kpmsPermissionContextProvider);
            perm = await KpmsPermissionGate.resolve(client, uid);
            if (!mounted) return;
            if (perm.isPlatformSuperAdmin) {
              await finishOperatorSignIn();
              return;
            }
          } catch (e) {
            bootstrapDetail = _describeBootstrapFailure(e);
          }

          await repo.signOut();
          KpmsPermissionGate.invalidate();
          if (!mounted) return;
          debugPrint(
            'SuperAdminLogin: access denied for $uid. ${bootstrapDetail ?? ''}',
          );
          kpmsSnack(
            context,
            l.superAdminAccessDenied,
            isError: true,
          );
          return;
        }
      }
      kpmsSnack(context, l.authCheckEmailConfirm, isError: false);
    } on AuthException catch (e) {
      if (mounted) kpmsSnackError(context, e);
    } catch (e) {
      if (mounted) kpmsSnackError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l = context.l10n;
    final maxW = 420.0;

    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF050A14),
              AppColors.brandNavy,
              Color(0xFF0F172A),
            ],
            stops: [0.0, 0.45, 1.0],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxW),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Icon(Icons.admin_panel_settings_rounded, size: 48, color: AppColors.primary.withValues(alpha: 0.95)),
                    const SizedBox(height: 16),
                    Text(
                      l.superAdminLoginTitle,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      l.superAdminLoginSubtitle,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white.withValues(alpha: 0.78), height: 1.35),
                    ),
                    const SizedBox(height: 32),
                    Material(
                      color: theme.colorScheme.surface,
                      elevation: 8,
                      shadowColor: Colors.black.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(20),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(22, 26, 22, 22),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(l.authWorkEmailLabel, style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700)),
                            const SizedBox(height: 8),
                            TextField(
                              controller: _email,
                              keyboardType: TextInputType.emailAddress,
                              autofillHints: const [AutofillHints.email],
                              textInputAction: TextInputAction.next,
                              decoration: InputDecoration(
                                hintText: 'name@organization.com',
                                prefixIcon: const Icon(Icons.alternate_email_rounded),
                              ),
                            ),
                            const SizedBox(height: 18),
                            Text(l.authPasswordLabel, style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700)),
                            const SizedBox(height: 8),
                            TextField(
                              controller: _password,
                              obscureText: true,
                              autofillHints: const [AutofillHints.password],
                              onSubmitted: (_) => _busy ? null : _signIn(),
                              decoration: InputDecoration(
                                hintText: '••••••••',
                                prefixIcon: const Icon(Icons.lock_outline_rounded),
                              ),
                            ),
                            const SizedBox(height: 12),
                            CheckboxListTile(
                              contentPadding: EdgeInsets.zero,
                              controlAffinity: ListTileControlAffinity.leading,
                              value: _rememberDevice,
                              onChanged: _busy
                                  ? null
                                  : (v) {
                                      if (v == null) return;
                                      setState(() => _rememberDevice = v);
                                    },
                              title: Text(l.platformRememberDevice, style: theme.textTheme.bodyMedium),
                              subtitle: Text(
                                l.platformRememberDeviceHint,
                                style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor, height: 1.35),
                              ),
                            ),
                            const SizedBox(height: 10),
                            FilledButton(
                              onPressed: _busy ? null : _signIn,
                              child: _busy
                                  ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2))
                                  : Text(l.authSignInButton),
                            ),
                            const SizedBox(height: 16),
                            TextButton(
                              onPressed: () => context.go(AppRoutes.login),
                              child: Text(
                                l.superAdminPharmacyPortalLink,
                                style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
