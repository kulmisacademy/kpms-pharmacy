import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/kpms_feedback.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../l10n/l10n_context.dart';
import '../application/auth_providers.dart';

/// PRD §5.1 — Email verification (Supabase Auth resend).
class VerifyEmailScreen extends ConsumerStatefulWidget {
  const VerifyEmailScreen({super.key});

  @override
  ConsumerState<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends ConsumerState<VerifyEmailScreen> {
  bool _busy = false;

  String? get _emailFromRoute => GoRouter.maybeOf(context)?.state.uri.queryParameters['email'];

  Future<void> _resend() async {
    final l = context.l10n;
    final email = _emailFromRoute?.trim();
    if (email == null || email.isEmpty || !email.contains('@')) {
      kpmsSnack(context, l.authVerifyMissingEmail, isError: true);
      return;
    }
    final repo = ref.read(authRepositoryProvider);
    setState(() => _busy = true);
    try {
      await repo.resendSignupEmail(email: email);
      if (mounted) kpmsSnack(context, l.authVerifySent);
    } catch (e) {
      if (mounted) kpmsSnack(context, l.authVerifyResendFailed('$e'), isError: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l = context.l10n;
    final email = _emailFromRoute;

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          const DecoratedBox(decoration: BoxDecoration(gradient: AppColors.brandGradient)),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: GlassCard(
                    padding: const EdgeInsets.all(28),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Icon(Icons.mark_email_unread_outlined, size: 52, color: theme.colorScheme.primary),
                        const SizedBox(height: 16),
                        Text(
                          l.authVerifyTitle,
                          style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          email != null && email.isNotEmpty
                              ? l.authVerifyBodyWithEmail(email)
                              : l.authVerifyBodyGeneric,
                          style: theme.textTheme.bodyMedium?.copyWith(color: theme.hintColor, height: 1.45),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        FilledButton(
                          onPressed: _busy ? null : _resend,
                          child: _busy
                              ? const SizedBox(
                                  height: 22,
                                  width: 22,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : Text(l.authVerifyResend),
                        ),
                        TextButton(
                          onPressed: () => context.go(AppRoutes.login),
                          child: Text(l.authVerifyBackSignIn),
                        ),
                      ],
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
