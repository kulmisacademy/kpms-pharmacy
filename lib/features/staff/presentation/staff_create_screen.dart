import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/kpms_role_presets.dart';
import '../../../core/auth/staff_feature_access.dart';
import '../../../core/utils/kpms_feedback.dart';
import '../../../core/widgets/kpms_page_shell.dart';
import '../application/staff_providers.dart';
import 'staff_permissions_editor.dart';

/// Admin creates a staff account with email/password (Edge Function `create-tenant-staff`).
class StaffCreateScreen extends ConsumerStatefulWidget {
  const StaffCreateScreen({super.key});

  @override
  ConsumerState<StaffCreateScreen> createState() => _StaffCreateScreenState();
}

class _StaffCreateScreenState extends ConsumerState<StaffCreateScreen> {
  final _email = TextEditingController();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _pw = TextEditingController();
  final _pw2 = TextEditingController();
  String _role = 'staff';
  late Map<String, dynamic> _permissions = Map<String, dynamic>.from(StaffPermissionKeys.defaultSalesStaffTemplate());
  bool _busy = false;
  bool _obscure = true;

  void _applyRoleTemplate(String role) {
    KpmsRolePresets.applyRoleTemplate(role, (m) => _permissions = m);
  }

  @override
  void dispose() {
    _email.dispose();
    _name.dispose();
    _phone.dispose();
    _pw.dispose();
    _pw2.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _email.text.trim();
    if (!email.contains('@')) {
      kpmsSnack(context, 'Enter a valid work email', isError: true);
      return;
    }
    final p1 = _pw.text;
    final p2 = _pw2.text;
    if (p1.length < 8) {
      kpmsSnack(context, 'Password must be at least 8 characters', isError: true);
      return;
    }
    if (p1 != p2) {
      kpmsSnack(context, 'Passwords do not match', isError: true);
      return;
    }
    setState(() => _busy = true);
    try {
      await ref.read(staffRepositoryProvider).createStaffAccount(
            email: email,
            password: p1,
            fullName: _name.text.trim(),
            phone: _phone.text.trim(),
            role: _role,
            permissions: _permissions,
          );
      ref.invalidate(tenantStaffListProvider);
      if (!mounted) return;
      kpmsSnack(context, 'Staff account created — they can sign in with this email and password.');
      context.pop();
    } catch (e) {
      if (mounted) {
        kpmsSnack(
          context,
          'Could not create staff. Deploy Edge Functions `create-tenant-staff` / `delete-tenant-staff` and retry. Details: $e',
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return KpmsPageShell(
      title: 'Create staff',
      subtitle: 'Email · password · role · permissions',
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          0,
          8,
          0,
          120 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        children: [
          Text(
            'Creates a Supabase Auth user linked to your pharmacy. No invitation email is required.',
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
              labelText: 'Work email (sign-in)',
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
              labelText: 'Phone',
              border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(16))),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _pw,
            obscureText: _obscure,
            decoration: InputDecoration(
              labelText: 'Password (min 8)',
              border: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(16))),
              suffixIcon: IconButton(
                onPressed: () => setState(() => _obscure = !_obscure),
                icon: Icon(_obscure ? Icons.visibility_rounded : Icons.visibility_off_rounded),
              ),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _pw2,
            obscureText: _obscure,
            decoration: const InputDecoration(
              labelText: 'Confirm password',
              border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(16))),
            ),
          ),
          const SizedBox(height: 18),
          Text('Role', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          InputDecorator(
            decoration: const InputDecoration(
              labelText: 'Role template',
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
                    _applyRoleTemplate(v);
                  });
                },
              ),
            ),
          ),
          const SizedBox(height: 20),
          StaffPermissionsEditor(
            value: _permissions,
            onChanged: (p) => setState(() => _permissions = p),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _busy ? null : _submit,
            child: _busy ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Create account'),
          ),
        ],
      ),
    );
  }
}
