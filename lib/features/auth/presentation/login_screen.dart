import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/audit/pharmacy_audit_hooks.dart';
import '../../../core/auth/kpms_password_policy.dart';
import '../../../core/auth/login_rate_limiter.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/constants/app_routes.dart';
import '../../../core/supabase/auth_user_helpers.dart';
import '../../../core/supabase/supabase_bootstrap.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/kpms_feedback.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../l10n/l10n_context.dart';
import '../../../providers/theme_provider.dart';
import '../../../core/auth/kpms_permission_gate.dart';
import '../../../core/auth/permission_providers.dart';
import '../../../core/supabase/profile_tenant_gate.dart';
import '../../../core/tenant/pharmacy_workspace_isolation.dart';
import '../../../features/enterprise/application/pharmacy_enterprise_bootstrap.dart';
import '../../../providers/pharmacy_local_workspace.dart';
import '../application/auth_providers.dart';

/// Soft diagonal accent lines over the auth gradient (cheap to paint).
class _AuthStripePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.tertiary.withValues(alpha: 0.07)
      ..strokeWidth = 1.25
      ..strokeCap = StrokeCap.round;
    const spacing = 52.0;
    final span = size.width + size.height * 1.2;
    for (var x = -span; x < span; x += spacing) {
      canvas.drawLine(Offset(x, size.height), Offset(x + size.height * 0.85, 0), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Pharmacy workspace sign-in — email/password only (no platform links).
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> with SingleTickerProviderStateMixin {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;

  late final AnimationController _entrance;
  late final Animation<double> _entranceCurve;

  @override
  void initState() {
    super.initState();
    _entrance = AnimationController(vsync: this, duration: const Duration(milliseconds: 780));
    _entranceCurve = CurvedAnimation(parent: _entrance, curve: Curves.easeOutCubic, reverseCurve: Curves.easeInCubic);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _entrance.forward();
    });
  }

  @override
  void dispose() {
    _entrance.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _signInWithSupabase() async {
    final l = context.l10n;
    final repo = ref.read(authRepositoryProvider);
    final email = _email.text.trim();
    final password = _password.text;
    if (email.isEmpty || !email.contains('@')) {
      kpmsSnack(context, l.validationEmailInvalid, isError: true);
      return;
    }
    if (!KpmsPasswordPolicy.meetsSignInMinimum(password)) {
      kpmsSnack(context, l.validationPasswordLength, isError: true);
      return;
    }
    if (LoginRateLimiter.isLockedOut(email)) {
      kpmsSnack(context, l.authTooManyAttempts, isError: true);
      return;
    }

    setState(() => _busy = true);
    try {
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
        LoginRateLimiter.recordSuccess(email);
        resetTenantSessionCaches(ref, reason: 'login_success');
        unawaited(PharmacyAuditHooks.authEvent('auth.login_success'));
        ref.invalidate(pharmacyWorkspaceBootstrapProvider);
        ref.invalidate(pharmacyEnterpriseBootstrapProvider);
        KpmsPermissionGate.invalidate();
        ref.invalidate(kpmsPermissionContextProvider);
        final uid = user?.id ?? kpmsAuthUserId(client);
        if (uid != null) {
          final perm = await KpmsPermissionGate.resolve(client, uid);
          if (!mounted) return;
          if (perm.isPlatformSuperAdmin) {
            context.go(AppRoutes.superAdmin);
            return;
          }
          final hasTenant = await ProfileTenantGate.hasTenantLinked(client, uid);
          if (!mounted) return;
          context.go(hasTenant ? perm.defaultLandingRoute : AppRoutes.pharmacyRegistration);
          return;
        }
        if (!mounted) return;
        context.go(AppRoutes.home);
        return;
      }
      LoginRateLimiter.recordFailure(email);
      kpmsSnack(context, l.authCheckEmailConfirm, isError: false);
    } on AuthException catch (e) {
      LoginRateLimiter.recordFailure(email);
      if (mounted) kpmsSnackError(context, e);
    } catch (e) {
      LoginRateLimiter.recordFailure(email);
      if (mounted) kpmsSnackError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final inputFill = scheme.surface.withValues(alpha: isDark ? 0.88 : 0.97);
    final authInputTheme = theme.copyWith(
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: inputFill,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: scheme.outline.withValues(alpha: isDark ? 0.25 : 0.35)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
        hintStyle: textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant.withValues(alpha: 0.75)),
      ),
    );

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          const DecoratedBox(decoration: BoxDecoration(gradient: AppColors.brandGradient)),
          RepaintBoundary(
            child: CustomPaint(
              painter: _AuthStripePainter(),
              child: const SizedBox.expand(),
            ),
          ),
          SafeArea(
            child: Align(
              alignment: AlignmentDirectional.topEnd,
              child: FadeTransition(
                opacity: _entranceCurve,
                child: SlideTransition(
                  position: Tween<Offset>(begin: const Offset(0.12, 0), end: Offset.zero).animate(_entranceCurve),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
                    child: Material(
                      color: Colors.white.withValues(alpha: 0.08),
                      shape: const CircleBorder(),
                      clipBehavior: Clip.antiAlias,
                      child: IconButton(
                        tooltip: l.shellToggleTheme,
                        onPressed: () {
                          final dark = Theme.of(context).brightness == Brightness.dark;
                          ref.read(themeModeProvider.notifier).setTheme(dark ? ThemeMode.light : ThemeMode.dark);
                        },
                        icon: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 280),
                          switchInCurve: Curves.easeOut,
                          switchOutCurve: Curves.easeIn,
                          transitionBuilder: (child, anim) => RotationTransition(turns: anim, child: FadeTransition(opacity: anim, child: child)),
                          child: Icon(
                            isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                            key: ValueKey<bool>(isDark),
                            color: Colors.white.withValues(alpha: 0.92),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: FadeTransition(
                    opacity: _entranceCurve,
                    child: SlideTransition(
                      position: Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero).animate(_entranceCurve),
                      child: GlassCard(
                        borderRadius: 22,
                        padding: const EdgeInsets.fromLTRB(26, 30, 26, 26),
                        child: Theme(
                          data: authInputTheme,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  DecoratedBox(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(18),
                                      gradient: LinearGradient(
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                        colors: [
                                          AppColors.primary.withValues(alpha: 0.35),
                                          AppColors.tertiary.withValues(alpha: 0.2),
                                        ],
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: AppColors.primary.withValues(alpha: 0.35),
                                          blurRadius: 18,
                                          spreadRadius: 0,
                                          offset: const Offset(0, 6),
                                        ),
                                      ],
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.all(12),
                                      child: Icon(Icons.local_pharmacy_rounded, color: Colors.white.withValues(alpha: 0.95), size: 26),
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          l.authPharmacySignInTitle,
                                          style: textTheme.titleLarge?.copyWith(
                                            fontWeight: FontWeight.w800,
                                            letterSpacing: -0.2,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          l.authPharmacySignInSubtitle,
                                          style: textTheme.bodySmall?.copyWith(
                                            color: scheme.onSurface.withValues(alpha: 0.72),
                                            height: 1.4,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Text(
                                AppConstants.appFullName,
                                textAlign: TextAlign.center,
                                style: textTheme.labelSmall?.copyWith(
                                  color: scheme.onSurface.withValues(alpha: 0.55),
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.35,
                                ),
                              ),
                              const SizedBox(height: 26),
                              TextField(
                                controller: _email,
                                keyboardType: TextInputType.emailAddress,
                                autofillHints: const [AutofillHints.email],
                                textInputAction: TextInputAction.next,
                                decoration: InputDecoration(
                                  labelText: l.commonEmail,
                                  prefixIcon: Icon(Icons.mail_outline_rounded, color: scheme.onSurfaceVariant),
                                ),
                              ),
                              const SizedBox(height: 14),
                              TextField(
                                controller: _password,
                                obscureText: true,
                                autofillHints: const [AutofillHints.password],
                                textInputAction: TextInputAction.done,
                                onSubmitted: (_) {
                                  if (!_busy) _signInWithSupabase();
                                },
                                decoration: InputDecoration(
                                  labelText: l.authPasswordLabel,
                                  prefixIcon: Icon(Icons.lock_outline_rounded, color: scheme.onSurfaceVariant),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Align(
                                alignment: AlignmentDirectional.centerEnd,
                                child: TextButton(
                                  style: TextButton.styleFrom(
                                    foregroundColor: AppColors.primary,
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  ),
                                  onPressed: () => context.push(AppRoutes.forgotPassword),
                                  child: Text(l.authForgotPasswordLink, style: const TextStyle(fontWeight: FontWeight.w600)),
                                ),
                              ),
                              const SizedBox(height: 6),
                              DecoratedBox(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppColors.primary.withValues(alpha: 0.38),
                                      blurRadius: 20,
                                      offset: const Offset(0, 10),
                                    ),
                                  ],
                                ),
                                child: FilledButton(
                                  onPressed: _busy ? null : _signInWithSupabase,
                                  style: FilledButton.styleFrom(
                                    backgroundColor: AppColors.primary,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                    elevation: 0,
                                  ),
                                  child: AnimatedSwitcher(
                                    duration: const Duration(milliseconds: 220),
                                    switchInCurve: Curves.easeOut,
                                    switchOutCurve: Curves.easeIn,
                                    child: _busy
                                        ? SizedBox(
                                            key: const ValueKey('busy'),
                                            height: 22,
                                            width: 22,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2.2,
                                              color: Colors.white.withValues(alpha: 0.95),
                                            ),
                                          )
                                        : Text(
                                            l.authSignInButton,
                                            key: const ValueKey('label'),
                                            style: const TextStyle(fontWeight: FontWeight.w700, letterSpacing: 0.2),
                                          ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 18),
                              Center(
                                child: TextButton(
                                  style: TextButton.styleFrom(
                                    foregroundColor: AppColors.primary,
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  ),
                                  onPressed: () => context.push(AppRoutes.pharmacyRegistration),
                                  child: Text(l.authRegisterPharmacyLink, style: const TextStyle(fontWeight: FontWeight.w700)),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
