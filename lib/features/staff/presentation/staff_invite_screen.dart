import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/kpms_role_presets.dart';
import '../../../core/auth/staff_feature_access.dart';
import '../../../core/constants/app_routes.dart';
import '../../../core/utils/kpms_feedback.dart';
import '../../../core/widgets/kpms_page_shell.dart';
import '../application/staff_providers.dart';
import 'staff_permissions_editor.dart';

/// Pharmacy admin flow: configure permissions then copy a secure join link (token).
class StaffInviteScreen extends ConsumerStatefulWidget {
  const StaffInviteScreen({super.key});

  @override
  ConsumerState<StaffInviteScreen> createState() => _StaffInviteScreenState();
}

class _StaffInviteScreenState extends ConsumerState<StaffInviteScreen> {
  final _email = TextEditingController();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  String _role = 'staff';
  late Map<String, dynamic> _permissions = StaffPermissionKeys.defaultSalesStaffTemplate();
  bool _busy = false;

  @override
  void dispose() {
    _email.dispose();
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _email.text.trim();
    if (!email.contains('@')) {
      kpmsSnack(context, 'Enter a valid work email', isError: true);
      return;
    }
    setState(() => _busy = true);
    try {
      final token = await ref.read(staffRepositoryProvider).createInvitation(
            email: email,
            fullName: _name.text.trim(),
            phone: _phone.text.trim(),
            role: _role,
            permissions: _permissions,
          );
      ref.invalidate(tenantStaffListProvider);
      if (!mounted) return;
      final link = Uri.base.replace(path: AppRoutes.joinStaff, queryParameters: {'token': token}).toString();
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Invitation ready'),
          content: SelectableText(link, style: Theme.of(ctx).textTheme.bodySmall),
          actions: [
            TextButton(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: link));
                if (ctx.mounted) Navigator.pop(ctx);
                if (!mounted) return;
                kpmsSnack(context, 'Link copied to clipboard');
              },
              child: const Text('Copy link'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Done'),
            ),
          ],
        ),
      );
      if (mounted) context.pop();
    } catch (e) {
      if (mounted) kpmsSnack(context, 'Could not create invitation: $e', isError: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return KpmsPageShell(
      title: 'Invite staff',
      subtitle: 'Permissions · secure join link',
      body: ListView(
        padding: const EdgeInsets.fromLTRB(0, 8, 0, 120),
        children: [
          Text(
            'They create their own password using the link. The link expires in 14 days.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.72),
            ),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
            decoration: const InputDecoration(
              labelText: 'Work email',
              border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(16))),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _name,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Full name',
              border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(16))),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _phone,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'Phone number',
              border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(16))),
            ),
          ),
          const SizedBox(height: 14),
          InputDecorator(
            decoration: const InputDecoration(
              labelText: 'Role',
              border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(16))),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                isExpanded: true,
                value: _role,
                items: [
                  for (final o in KpmsRolePresets.enterpriseRoleOptions)
                    DropdownMenuItem(value: o.dbRole, child: Text(o.label)),
                ],
                onChanged: (v) {
                  if (v == null) return;
                  setState(() {
                    _role = v;
                    KpmsRolePresets.applyRoleTemplate(v, (m) => _permissions = m);
                  });
                },
              ),
            ),
          ),
          const SizedBox(height: 22),
          Text('Permissions', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          StaffPermissionsEditor(
            value: _permissions,
            onChanged: (m) => setState(() => _permissions = m),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _busy ? null : _submit,
            icon: _busy
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.link_rounded),
            label: Text(_busy ? 'Creating…' : 'Create invitation link'),
          ),
        ],
      ),
    );
  }
}
