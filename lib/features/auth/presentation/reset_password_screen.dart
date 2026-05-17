import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/auth/kpms_password_policy.dart';
import '../../../core/constants/app_routes.dart';
import '../../../core/supabase/supabase_bootstrap.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/kpms_feedback.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../l10n/app_localizations.dart';

/// Completes Supabase password recovery (user arrived via email link with recovery session).
class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _pw = TextEditingController();
  final _pw2 = TextEditingController();
  StreamSubscription<AuthState>? _sub;
  bool _recovery = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final client = SupabaseBootstrap.clientOrNull;
      if (client?.auth.currentSession != null) {
        setState(() => _recovery = true);
      }
    });
    final client = SupabaseBootstrap.clientOrNull;
    if (client == null) return;
    _sub = client.auth.onAuthStateChange.listen((data) {
      if (data.event == AuthChangeEvent.passwordRecovery) {
        setState(() => _recovery = true);
      }
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _pw.dispose();
    _pw2.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final l = AppLocalizations.of(context);
    final a = _pw.text;
    final b = _pw2.text;
    if (!KpmsPasswordPolicy.meetsPharmacySignupRules(a)) {
      kpmsSnack(context, l.validationPasswordSignupRules, isError: true);
      return;
    }
    if (a != b) {
      kpmsSnack(context, l.validationPasswordMismatch, isError: true);
      return;
    }
    final client = SupabaseBootstrap.clientOrNull;
    if (client == null) return;
    setState(() => _busy = true);
    try {
      await client.auth.updateUser(UserAttributes(password: a));
      await client.auth.signOut();
      if (!mounted) return;
      kpmsSnack(context, l.resetPasswordDone, isError: false);
      context.go(AppRoutes.login);
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
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          DecoratedBox(decoration: const BoxDecoration(gradient: AppColors.brandGradient)),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: IconButton.filledTonal(
                          onPressed: () => context.canPop() ? context.pop() : context.go(AppRoutes.login),
                          icon: const Icon(Icons.arrow_back_rounded),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        l.resetPasswordTitle,
                        style: theme.textTheme.headlineSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        l.resetPasswordSubtitle,
                        style: theme.textTheme.bodySmall?.copyWith(color: Colors.white70, height: 1.4),
                      ),
                      const SizedBox(height: 24),
                      if (!_recovery)
                        GlassCard(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(l.resetPasswordInvalidLink, style: theme.textTheme.bodyMedium),
                              const SizedBox(height: 16),
                              FilledButton(
                                onPressed: () => context.go(AppRoutes.forgotPassword),
                                child: Text(l.authForgotSendLink),
                              ),
                              TextButton(
                                onPressed: () => context.go(AppRoutes.login),
                                child: Text(l.resetPasswordBackToSignIn),
                              ),
                            ],
                          ),
                        )
                      else
                        GlassCard(
                          padding: const EdgeInsets.all(22),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              TextField(
                                controller: _pw,
                                obscureText: true,
                                decoration: InputDecoration(
                                  labelText: l.authPasswordLabel,
                                  prefixIcon: const Icon(Icons.lock_outline_rounded),
                                ),
                              ),
                              const SizedBox(height: 14),
                              TextField(
                                controller: _pw2,
                                obscureText: true,
                                decoration: InputDecoration(
                                  labelText: l.changePasswordConfirm,
                                  prefixIcon: const Icon(Icons.lock_outline_rounded),
                                ),
                                onSubmitted: (_) {
                                  if (!_busy) _submit();
                                },
                              ),
                              const SizedBox(height: 8),
                              Text(
                                l.validationPasswordSignupRules,
                                style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
                              ),
                              const SizedBox(height: 18),
                              FilledButton(
                                onPressed: _busy ? null : _submit,
                                child: _busy
                                    ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2))
                                    : Text(l.resetPasswordSubmit),
                              ),
                            ],
                          ),
                        ),
                    ],
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
