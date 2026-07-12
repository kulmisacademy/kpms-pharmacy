import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import 'kpms_app_lock_controller.dart';
import 'kpms_app_lock_store.dart';

/// Entry point from Settings → App lock PIN.
Future<void> showKpmsAppLockManager(BuildContext context, WidgetRef ref) async {
  final has = await KpmsAppLockStore.hasPin();
  if (!context.mounted) return;
  final l = AppLocalizations.of(context);

  if (!has) {
    await _runSetFlow(context, ref);
    return;
  }

  final choice = await showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    builder: (ctx) {
      final theme = Theme.of(ctx);
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.password_rounded, color: theme.colorScheme.primary),
              title: Text(l.appLockChange),
              onTap: () => Navigator.pop(ctx, 'change'),
            ),
            ListTile(
              leading: Icon(Icons.no_encryption_gmailerrorred_rounded, color: theme.colorScheme.error),
              title: Text(l.appLockRemove),
              onTap: () => Navigator.pop(ctx, 'remove'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      );
    },
  );

  if (choice == 'change') {
    if (!context.mounted) return;
    final current = await _promptPin(context, AppLocalizations.of(context).appLockEnterTitle);
    if (current == null) return;
    final ok = await KpmsAppLockStore.verify(current);
    if (!context.mounted) return;
    if (!ok) {
      _snack(context, AppLocalizations.of(context).appLockWrong, isError: true);
      return;
    }
    await _runSetFlow(context, ref);
  } else if (choice == 'remove') {
    if (!context.mounted) return;
    final current = await _promptPin(context, AppLocalizations.of(context).appLockEnterTitle);
    if (current == null) return;
    final ok = await KpmsAppLockStore.verify(current);
    if (!context.mounted) return;
    if (!ok) {
      _snack(context, AppLocalizations.of(context).appLockWrong, isError: true);
      return;
    }
    await ref.read(kpmsAppLockProvider.notifier).disablePin();
    if (!context.mounted) return;
    _snack(context, AppLocalizations.of(context).appLockRemoved);
  }
}

Future<void> _runSetFlow(BuildContext context, WidgetRef ref) async {
  final l = AppLocalizations.of(context);
  final first = await _promptPin(context, l.appLockSetTitle, subtitle: l.appLockSetSubtitle);
  if (first == null) return;
  if (!context.mounted) return;
  final second = await _promptPin(context, l.appLockConfirmTitle);
  if (second == null) return;
  if (!context.mounted) return;
  if (first != second) {
    _snack(context, l.appLockMismatch, isError: true);
    return;
  }
  await KpmsAppLockStore.setPin(first);
  await ref.read(kpmsAppLockProvider.notifier).refreshHasPin();
  if (!context.mounted) return;
  _snack(context, l.appLockSetDone);
}

void _snack(BuildContext context, String msg, {bool isError = false}) {
  final scheme = Theme.of(context).colorScheme;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(msg),
      backgroundColor: isError ? scheme.error : null,
      behavior: SnackBarBehavior.floating,
    ),
  );
}

/// Modal numeric PIN prompt. Returns the entered 4–6 digit PIN, or null if cancelled.
Future<String?> _promptPin(BuildContext context, String title, {String? subtitle}) {
  return showDialog<String>(
    context: context,
    builder: (ctx) => _PinPromptDialog(title: title, subtitle: subtitle),
  );
}

class _PinPromptDialog extends StatefulWidget {
  const _PinPromptDialog({required this.title, this.subtitle});

  final String title;
  final String? subtitle;

  @override
  State<_PinPromptDialog> createState() => _PinPromptDialogState();
}

class _PinPromptDialogState extends State<_PinPromptDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _valid {
    final t = _controller.text;
    return t.length >= 4 && t.length <= 6;
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.subtitle != null) ...[
            Text(widget.subtitle!, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 12),
          ],
          TextField(
            controller: _controller,
            autofocus: true,
            keyboardType: TextInputType.number,
            obscureText: true,
            maxLength: 6,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(counterText: ''),
            onChanged: (_) => setState(() {}),
            onSubmitted: (_) {
              if (_valid) Navigator.pop(context, _controller.text);
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l.commonCancel),
        ),
        FilledButton(
          onPressed: _valid ? () => Navigator.pop(context, _controller.text) : null,
          child: Text(l.commonSave),
        ),
      ],
    );
  }
}
