import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/application/auth_providers.dart';
import '../../l10n/app_localizations.dart';
import '../auth/kpms_permission_gate.dart';
import '../auth/permission_providers.dart';
import '../supabase/supabase_bootstrap.dart';
import '../utils/kpms_feedback.dart';
import 'kpms_responsive_dialog.dart';

/// Change password for the current session (signed-in user).
Future<void> showKpmsChangePasswordDialog(BuildContext parentContext) {
  return showKpmsResponsiveDialog<void>(
    context: parentContext,
    builder: (ctx) => _KpmsChangePasswordDialog(parentContext: parentContext),
  );
}

class _KpmsChangePasswordDialog extends ConsumerStatefulWidget {
  const _KpmsChangePasswordDialog({required this.parentContext});

  final BuildContext parentContext;

  @override
  ConsumerState<_KpmsChangePasswordDialog> createState() => _KpmsChangePasswordDialogState();
}

class _KpmsChangePasswordDialogState extends ConsumerState<_KpmsChangePasswordDialog> {
  late final TextEditingController _newPw;
  late final TextEditingController _confirm;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _newPw = TextEditingController();
    _confirm = TextEditingController();
  }

  @override
  void dispose() {
    _newPw.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final l = AppLocalizations.of(context);
    final a = _newPw.text;
    final b = _confirm.text;
    if (a.length < 6) {
      kpmsSnack(context, l.validationPasswordLength, isError: true);
      return;
    }
    if (a != b) {
      kpmsSnack(context, l.validationPasswordMismatch, isError: true);
      return;
    }
    setState(() => _saving = true);
    final parent = widget.parentContext;
    try {
      await ref.read(authRepositoryProvider).updatePassword(a);
      final client = SupabaseBootstrap.clientOrNull;
      final uid = client?.auth.currentUser?.id;
      if (client != null && uid != null) {
        try {
          await client.from('profiles').update({'must_change_password': false}).eq('id', uid);
        } catch (_) {}
        KpmsPermissionGate.invalidate();
        ref.invalidate(kpmsPermissionContextProvider);
      }
      if (!mounted || !parent.mounted) return;
      FocusManager.instance.primaryFocus?.unfocus();
      Navigator.pop(context);
      if (parent.mounted) kpmsSnack(parent, l.snackPasswordUpdated);
    } catch (e) {
      if (mounted) kpmsSnack(context, '$e', isError: true);
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l.changePasswordTitle),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _newPw,
              obscureText: true,
              decoration: InputDecoration(labelText: l.changePasswordNew, border: const OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _confirm,
              obscureText: true,
              decoration: InputDecoration(labelText: l.changePasswordConfirm, border: const OutlineInputBorder()),
              onSubmitted: (_) {
                if (!_saving) _submit();
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: _saving ? null : () => Navigator.pop(context), child: Text(l.commonCancel)),
        FilledButton(
          onPressed: _saving ? null : _submit,
          child: _saving
              ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : Text(l.commonUpdate),
        ),
      ],
    );
  }
}
