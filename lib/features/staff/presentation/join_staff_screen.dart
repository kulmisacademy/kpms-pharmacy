import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/auth/kpms_permission_gate.dart';
import '../../../core/supabase/supabase_bootstrap.dart';
import '../../../core/utils/kpms_feedback.dart';
import '../application/staff_providers.dart';

/// Accept invitation: sign up with invited email, then attach to tenant.
class JoinStaffScreen extends ConsumerStatefulWidget {
  const JoinStaffScreen({super.key, this.initialToken});

  final String? initialToken;

  @override
  ConsumerState<JoinStaffScreen> createState() => _JoinStaffScreenState();
}

class _JoinStaffScreenState extends ConsumerState<JoinStaffScreen> {
  final _password = TextEditingController();
  String? _email;
  String? _fullNameHint;
  String? _token;
  bool _loadingPeek = true;
  bool _busy = false;
  String? _peekError;

  @override
  void initState() {
    super.initState();
    _token = widget.initialToken?.trim();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final q = GoRouterState.of(context).uri.queryParameters['token']?.trim();
    if (q != null && q.isNotEmpty) _token = q;
    _runPeek();
  }

  Future<void> _runPeek() async {
    final t = _token;
    if (t == null || t.isEmpty) {
      setState(() {
        _loadingPeek = false;
        _peekError = 'Missing invitation token. Open the full link from your admin.';
      });
      return;
    }
    setState(() {
      _loadingPeek = true;
      _peekError = null;
    });
    final data = await ref.read(staffRepositoryProvider).peekInvitation(t);
    if (!mounted) return;
    if (data == null) {
      setState(() {
        _loadingPeek = false;
        _peekError = 'This invitation is invalid or has expired.';
      });
      return;
    }
    setState(() {
      _loadingPeek = false;
      _email = data.email;
      _fullNameHint = data.fullName;
    });
  }

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  Future<void> _goToWorkspace() async {
    final client = SupabaseBootstrap.clientOrNull;
    final uid = client?.auth.currentUser?.id;
    if (client == null || uid == null || !mounted) return;
    final perm = await KpmsPermissionGate.resolve(client, uid);
    if (!mounted) return;
    context.go(perm.defaultLandingRoute);
  }

  Future<void> _claimExistingSession() async {
    final t = _token;
    if (t == null || t.isEmpty) return;
    setState(() => _busy = true);
    try {
      await ref.read(staffRepositoryProvider).claimInvitation(t);
      KpmsPermissionGate.invalidate();
      if (!mounted) return;
      kpmsSnack(context, 'Welcome — your workspace is ready.');
      await _goToWorkspace();
    } catch (e) {
      if (mounted) kpmsSnack(context, 'Could not complete join: $e', isError: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _signUpAndClaim() async {
    final t = _token;
    final email = _email;
    if (t == null || email == null) return;
    final pw = _password.text;
    if (pw.length < 8) {
      kpmsSnack(context, 'Use at least 8 characters for the password.', isError: true);
      return;
    }
    final client = SupabaseBootstrap.clientOrNull;
    if (client == null) {
      kpmsSnack(context, 'App is not configured.', isError: true);
      return;
    }
    setState(() => _busy = true);
    try {
      final res = await client.auth.signUp(email: email, password: pw);
      if (res.session == null) {
        if (mounted) {
          kpmsSnack(
            context,
            'Check your email to confirm your account, then open this link again to finish.',
          );
        }
        return;
      }
      await ref.read(staffRepositoryProvider).claimInvitation(t);
      KpmsPermissionGate.invalidate();
      if (!mounted) return;
      kpmsSnack(context, 'Account created and linked to your pharmacy.');
      await _goToWorkspace();
    } on AuthException catch (e) {
      if (mounted) kpmsSnack(context, e.message, isError: true);
    } catch (e) {
      if (mounted) kpmsSnack(context, 'Sign-up failed: $e', isError: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final client = SupabaseBootstrap.clientOrNull;
    final user = client?.auth.currentUser;
    final sessionEmail = user?.email?.toLowerCase();
    final invitedEmail = _email?.toLowerCase();

    return Scaffold(
      appBar: AppBar(title: const Text('Join your pharmacy')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              if (_loadingPeek)
                const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_peekError != null)
                Text(_peekError!, style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.error))
              else ...[
                Text(
                  _fullNameHint != null && _fullNameHint!.isNotEmpty
                      ? 'You were invited as ${_fullNameHint!}.'
                      : 'You were invited to join a pharmacy team.',
                  style: theme.textTheme.bodyLarge,
                ),
                const SizedBox(height: 12),
                Text('Email', style: theme.textTheme.labelLarge),
                const SizedBox(height: 4),
                SelectableText(_email ?? '—', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 24),
                if (user != null && sessionEmail != null && invitedEmail != null && sessionEmail == invitedEmail) ...[
                  FilledButton(
                    onPressed: _busy ? null : _claimExistingSession,
                    child: Text(_busy ? 'Working…' : 'Complete join'),
                  ),
                ] else if (user != null && sessionEmail != invitedEmail) ...[
                  Text(
                    'You are signed in as $sessionEmail. Sign out and use the invited email, or open this link in a private window.',
                    style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.error),
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton(
                    onPressed: _busy
                        ? null
                        : () async {
                            await client?.auth.signOut();
                            KpmsPermissionGate.invalidate();
                            if (mounted) setState(() {});
                          },
                    child: const Text('Sign out'),
                  ),
                ] else ...[
                  TextField(
                    controller: _password,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Create password',
                      border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(16))),
                    ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: _busy ? null : _signUpAndClaim,
                    child: Text(_busy ? 'Creating account…' : 'Create account & join'),
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}
