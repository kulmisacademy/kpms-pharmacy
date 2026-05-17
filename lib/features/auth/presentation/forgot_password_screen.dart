import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/kpms_password_policy.dart';
import '../../../core/auth/password_recovery_rate_limiter.dart';
import '../../../core/constants/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/kpms_feedback.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/kpms_otp_input.dart';
import '../../../l10n/app_localizations.dart';
import '../../../l10n/l10n_context.dart';
import '../application/auth_providers.dart';

enum _ForgotStep { email, otp, password }

/// Password recovery: email → OTP email → verify → new password, entirely in-app (no browser / recovery links).
class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _email = TextEditingController();
  final _otp = TextEditingController();
  final _pw1 = TextEditingController();
  final _pw2 = TextEditingController();
  bool _busy = false;
  bool _resendBusy = false;
  bool _obscurePw1 = true;
  bool _obscurePw2 = true;
  _ForgotStep _step = _ForgotStep.email;
  int _resendSeconds = 0;
  Timer? _resendTimer;
  Timer? _otpExpiryTimer;
  String? _challengeToken;
  DateTime? _otpExpiresAt;

  @override
  void initState() {
    super.initState();
    _pw1.addListener(_onPasswordFieldsChanged);
    _pw2.addListener(_onPasswordFieldsChanged);
  }

  void _onPasswordFieldsChanged() {
    if (_step == _ForgotStep.password && mounted) setState(() {});
  }

  @override
  void dispose() {
    _pw1.removeListener(_onPasswordFieldsChanged);
    _pw2.removeListener(_onPasswordFieldsChanged);
    _resendTimer?.cancel();
    _otpExpiryTimer?.cancel();
    _email.dispose();
    _otp.dispose();
    _pw1.dispose();
    _pw2.dispose();
    super.dispose();
  }

  void _armResendCountdown() {
    _resendTimer?.cancel();
    setState(() => _resendSeconds = 60);
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      if (_resendSeconds <= 1) {
        t.cancel();
        setState(() => _resendSeconds = 0);
      } else {
        setState(() => _resendSeconds--);
      }
    });
  }

  void _startOtpExpiryTicker() {
    _otpExpiryTimer?.cancel();
    if (_otpExpiresAt == null) return;
    _otpExpiryTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (_step != _ForgotStep.otp) {
        _otpExpiryTimer?.cancel();
        return;
      }
      setState(() {});
      final exp = _otpExpiresAt;
      if (exp != null && DateTime.now().isAfter(exp)) {
        _otpExpiryTimer?.cancel();
      }
    });
  }

  void _cancelOtpExpiryTicker() {
    _otpExpiryTimer?.cancel();
    _otpExpiryTimer = null;
  }

  String _otpExpiryLine(AppLocalizations l) {
    final exp = _otpExpiresAt;
    if (exp == null) return '';
    final left = exp.difference(DateTime.now());
    if (left.inSeconds <= 0) {
      return l.authRecoveryOtpExpired;
    }
    final totalSec = left.inSeconds;
    final mm = totalSec ~/ 60;
    final ss = totalSec % 60;
    final time = '${mm.toString().padLeft(2, '0')}:${ss.toString().padLeft(2, '0')}';
    return l.authRecoveryOtpExpiresIn(time);
  }

  bool _otpTimeExpired() {
    final exp = _otpExpiresAt;
    if (exp == null) return false;
    return !exp.isAfter(DateTime.now());
  }

  Future<void> _sendOrResendCode() async {
    final l = context.l10n;
    final email = _email.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      kpmsSnack(context, l.validationEmailInvalid, isError: true);
      return;
    }

    final block = PasswordRecoveryRateLimiter.sendBlockedRemaining(email);
    if (block != null) {
      final secs = block.inSeconds.clamp(1, 3600);
      kpmsSnack(context, l.authRecoveryResendIn(secs), isError: false);
      return;
    }

    final resend = _step == _ForgotStep.otp;
    if (resend) {
      setState(() => _resendBusy = true);
    } else {
      setState(() => _busy = true);
    }
    try {
      final exp = await ref.read(authRepositoryProvider).sendPasswordResetEmail(email);
      PasswordRecoveryRateLimiter.recordSend(email);
      PasswordRecoveryRateLimiter.clearVerifyFailures(email);
      if (!mounted) return;
      setState(() {
        _step = _ForgotStep.otp;
        _otp.clear();
        _challengeToken = null;
        _otpExpiresAt = exp;
      });
      _cancelOtpExpiryTicker();
      _startOtpExpiryTicker();
      _armResendCountdown();
      kpmsSnackSuccess(context, l.authForgotResetSent);
    } catch (e) {
      if (mounted) kpmsSnackError(context, e);
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _resendBusy = false;
        });
      }
    }
  }

  Future<void> _verifyOtp() async {
    final l = context.l10n;
    final email = _email.text.trim();
    final code = _otp.text.trim();
    if (code.length != 6) {
      kpmsSnack(context, l.authRecoveryCodeIncomplete, isError: true);
      return;
    }
    if (_otpTimeExpired()) {
      kpmsSnack(context, l.authRecoveryOtpExpired, isError: true);
      return;
    }
    if (PasswordRecoveryRateLimiter.isVerifyLocked(email)) {
      final until = PasswordRecoveryRateLimiter.verifyLockUntil(email);
      final mins = until != null ? until.difference(DateTime.now()).inMinutes.clamp(1, 120) : 15;
      kpmsSnack(context, l.authRecoveryVerifyLockedMinutes(mins), isError: true);
      return;
    }
    if (!PasswordRecoveryRateLimiter.canAttemptVerify(email)) {
      kpmsSnack(context, l.authRecoveryTooManyVerify, isError: true);
      return;
    }

    setState(() => _busy = true);
    try {
      final challenge = await ref.read(authRepositoryProvider).verifyPasswordRecoveryOtp(email: email, token: code);
      PasswordRecoveryRateLimiter.clearVerifyFailures(email);
      if (!mounted) return;
      setState(() {
        _challengeToken = challenge;
        _step = _ForgotStep.password;
        _pw1.clear();
        _pw2.clear();
      });
    } catch (e) {
      final msg = e.toString();
      if (msg.contains('verify_locked')) {
        PasswordRecoveryRateLimiter.applyServerVerifyLock(email);
      } else if (msg.contains('invalid_code') || msg.contains('expired_code')) {
        PasswordRecoveryRateLimiter.recordVerifyFailure(email);
      }
      if (mounted) kpmsSnackError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _showSuccessThenNavigate(AppLocalizations l) async {
    if (!mounted) return;
    final barrierLabel = MaterialLocalizations.of(context).modalBarrierDismissLabel;
    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierLabel: barrierLabel,
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 420),
      pageBuilder: (ctx, animation, secondaryAnimation) {
        Future.delayed(const Duration(milliseconds: 1750), () {
          if (ctx.mounted) Navigator.of(ctx).pop();
        });
        final scheme = Theme.of(ctx).colorScheme;
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: const Duration(milliseconds: 480),
                curve: Curves.easeOutBack,
                builder: (context, v, child) => Transform.scale(scale: v, child: child),
                child: Icon(Icons.check_circle_rounded, size: 72, color: scheme.primary),
              ),
              const SizedBox(height: 16),
              Text(
                l.resetPasswordSuccessTitle,
                textAlign: TextAlign.center,
                style: Theme.of(ctx).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Text(
                l.resetPasswordDone,
                textAlign: TextAlign.center,
                style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant, height: 1.35),
              ),
            ],
          ),
        );
      },
      transitionBuilder: (ctx, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.9, end: 1).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
            child: child,
          ),
        );
      },
    );
    if (!mounted) return;
    context.go(AppRoutes.login);
  }

  Future<void> _savePassword() async {
    final l = context.l10n;
    final a = _pw1.text;
    final b = _pw2.text;
    if (!KpmsPasswordPolicy.meetsPharmacySignupRules(a)) {
      kpmsSnack(context, l.validationPasswordSignupRules, isError: true);
      return;
    }
    if (a != b) {
      kpmsSnack(context, l.validationPasswordMismatch, isError: true);
      return;
    }

    final challenge = _challengeToken;
    if (challenge == null || challenge.isEmpty) {
      kpmsSnackError(context, Exception('invalid_or_expired_challenge'));
      return;
    }

    setState(() => _busy = true);
    try {
      await ref.read(authRepositoryProvider).completePasswordResetWithChallenge(
            email: _email.text.trim(),
            challengeToken: challenge,
            newPassword: a,
          );
      PasswordRecoveryRateLimiter.resetSession(_email.text.trim());
      if (!mounted) return;
      setState(() => _challengeToken = null);
      await _showSuccessThenNavigate(l);
    } catch (e) {
      if (mounted) kpmsSnackError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _useDifferentEmail() async {
    if (!mounted) return;
    setState(() {
      _step = _ForgotStep.email;
      _otp.clear();
      _pw1.clear();
      _pw2.clear();
      _challengeToken = null;
      _otpExpiresAt = null;
    });
    _cancelOtpExpiryTicker();
  }

  void _handleBack() {
    switch (_step) {
      case _ForgotStep.email:
        if (context.canPop()) {
          context.pop();
        } else {
          context.go(AppRoutes.login);
        }
        break;
      case _ForgotStep.otp:
        _cancelOtpExpiryTicker();
        setState(() {
          _step = _ForgotStep.email;
          _otpExpiresAt = null;
          _challengeToken = null;
        });
        break;
      case _ForgotStep.password:
        setState(() {
          _step = _ForgotStep.otp;
          _challengeToken = null;
          _pw1.clear();
          _pw2.clear();
        });
        break;
    }
  }

  Widget _passwordStrengthRow(AppLocalizations l, ColorScheme scheme) {
    final score = KpmsPasswordPolicy.strengthScore(_pw1.text);
    final labels = [l.passwordStrengthWeak, l.passwordStrengthFair, l.passwordStrengthGood, l.passwordStrengthStrong];
    final idx = (score - 1).clamp(0, 3);
    final label = _pw1.text.isEmpty ? '' : labels[idx];
    final colors = [scheme.error, scheme.tertiary, scheme.secondary, scheme.primary];
    final activeColor = _pw1.text.isEmpty ? scheme.outlineVariant : colors[idx];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l.passwordStrengthLabel, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: scheme.onSurfaceVariant)),
        const SizedBox(height: 8),
        Row(
          children: List.generate(4, (i) {
            final filled = score > i && _pw1.text.isNotEmpty;
            return Expanded(
              child: Padding(
                padding: EdgeInsetsDirectional.only(end: i < 3 ? 6 : 0),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  height: 6,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                    color: filled ? activeColor : scheme.surfaceContainerHighest,
                  ),
                ),
              ),
            );
          }),
        ),
        if (label.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: activeColor)),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l = context.l10n;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const DecoratedBox(decoration: BoxDecoration(gradient: AppColors.brandGradient)),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + bottomInset),
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: IconButton.filledTonal(
                          onPressed: _busy ? null : _handleBack,
                          icon: const Icon(Icons.arrow_back_rounded),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        l.authForgotTitle,
                        style: theme.textTheme.headlineSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        l.authForgotSubtitle,
                        style: theme.textTheme.bodySmall?.copyWith(color: Colors.white70, height: 1.45),
                      ),
                      const SizedBox(height: 24),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 320),
                        switchInCurve: Curves.easeOutCubic,
                        switchOutCurve: Curves.easeInCubic,
                        transitionBuilder: (child, anim) => FadeTransition(
                          opacity: anim,
                          child: SlideTransition(
                            position: Tween<Offset>(begin: const Offset(0, 0.04), end: Offset.zero).animate(anim),
                            child: child,
                          ),
                        ),
                        child: KeyedSubtree(
                          key: ValueKey<_ForgotStep>(_step),
                          child: GlassCard(
                            borderRadius: 22,
                            padding: const EdgeInsets.fromLTRB(22, 22, 22, 20),
                            child: _stepBody(theme, scheme, l),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextButton(
                        onPressed: _busy ? null : () => context.go(AppRoutes.login),
                        child: Text(l.authVerifyBackSignIn, style: TextStyle(color: Colors.white.withValues(alpha: 0.92))),
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

  Widget _stepBody(ThemeData theme, ColorScheme scheme, AppLocalizations l) {
    switch (_step) {
      case _ForgotStep.email:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              textInputAction: TextInputAction.done,
              decoration: InputDecoration(
                labelText: l.commonEmail,
                prefixIcon: Icon(Icons.mail_outline_rounded, color: scheme.onSurfaceVariant),
              ),
            ),
            const SizedBox(height: 22),
            FilledButton(
              onPressed: _busy ? null : _sendOrResendCode,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: _busy
                  ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Text(l.authForgotSendLink, style: const TextStyle(fontWeight: FontWeight.w700)),
            ),
          ],
        );
      case _ForgotStep.otp:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l.authRecoveryVerifyTitle,
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(
              _email.text.trim(),
              style: theme.textTheme.bodyMedium?.copyWith(color: scheme.primary, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 10),
            Text(
              l.authRecoveryEmailHint,
              style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant, height: 1.35),
            ),
            if (_otpExpiresAt != null) ...[
              const SizedBox(height: 10),
              Text(
                _otpExpiryLine(l),
                style: theme.textTheme.labelLarge?.copyWith(
                  color: _otpTimeExpired() ? scheme.error : scheme.secondary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
            const SizedBox(height: 18),
            KpmsOtpInput(
              controller: _otp,
              enabled: !_busy,
              autofocus: true,
              pasteLabel: l.authOtpPaste,
              onCompleted: (_) {
                if (!_busy) _verifyOtp();
              },
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _busy ? null : _verifyOtp,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: _busy
                  ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Text(l.authRecoveryVerifyCta, style: const TextStyle(fontWeight: FontWeight.w700)),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: (_busy || _resendBusy || _resendSeconds > 0) ? null : _sendOrResendCode,
              child: _resendBusy
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(
                      _resendSeconds > 0 ? l.authRecoveryResendAvailableIn(_resendSeconds) : l.authRecoveryResend,
                      textAlign: TextAlign.center,
                    ),
            ),
            TextButton(
              onPressed: _busy ? null : _useDifferentEmail,
              child: Text(l.authRecoveryEditEmail),
            ),
          ],
        );
      case _ForgotStep.password:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l.resetPasswordTitle,
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(
              l.resetPasswordSubtitle,
              style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant, height: 1.35),
            ),
            const SizedBox(height: 18),
            TextField(
              controller: _pw1,
              obscureText: _obscurePw1,
              autofillHints: const [AutofillHints.newPassword],
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                labelText: l.changePasswordNew,
                prefixIcon: Icon(Icons.lock_outline_rounded, color: scheme.onSurfaceVariant),
                suffixIcon: IconButton(
                  tooltip: _obscurePw1 ? 'Show' : 'Hide',
                  onPressed: () => setState(() => _obscurePw1 = !_obscurePw1),
                  icon: Icon(_obscurePw1 ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                ),
              ),
            ),
            const SizedBox(height: 12),
            _passwordStrengthRow(l, scheme),
            const SizedBox(height: 14),
            TextField(
              controller: _pw2,
              obscureText: _obscurePw2,
              autofillHints: const [AutofillHints.newPassword],
              textInputAction: TextInputAction.done,
              decoration: InputDecoration(
                labelText: l.changePasswordConfirm,
                prefixIcon: Icon(Icons.lock_outline_rounded, color: scheme.onSurfaceVariant),
                suffixIcon: IconButton(
                  tooltip: _obscurePw2 ? 'Show' : 'Hide',
                  onPressed: () => setState(() => _obscurePw2 = !_obscurePw2),
                  icon: Icon(_obscurePw2 ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                ),
              ),
              onSubmitted: (_) {
                if (!_busy) _savePassword();
              },
            ),
            if (_pw2.text.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    _pw1.text == _pw2.text ? Icons.check_circle_rounded : Icons.error_outline_rounded,
                    size: 18,
                    color: _pw1.text == _pw2.text ? scheme.primary : scheme.error,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _pw1.text == _pw2.text ? l.passwordConfirmMatches : l.passwordConfirmDoesNotMatch,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: _pw1.text == _pw2.text ? scheme.primary : scheme.error,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 8),
            Text(
              l.validationPasswordSignupRules,
              style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
            ),
            const SizedBox(height: 18),
            FilledButton(
              onPressed: _busy ? null : _savePassword,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: _busy
                  ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Text(l.resetPasswordSubmit, style: const TextStyle(fontWeight: FontWeight.w700)),
            ),
          ],
        );
    }
  }
}
