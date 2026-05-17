import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/audit/pharmacy_audit_service.dart';
import '../../../core/auth/kpms_permission_gate.dart';
import '../../../core/auth/kpms_role_presets.dart';
import '../../../core/auth/permission_providers.dart';
import '../../../core/staff/kpms_staff_rbac_log.dart';
import '../../../core/supabase/supabase_bootstrap.dart';
import '../../../core/tenant/kpms_active_tenant_provider.dart';
import '../../../core/utils/kpms_feedback.dart';
import '../../../core/widgets/kpms_page_shell.dart';
import '../../notifications/data/pharmacy_notification_repository.dart';
import '../../notifications/domain/pharmacy_notification_models.dart';
import '../application/staff_providers.dart';
import '../domain/staff_member.dart';
import 'staff_permissions_editor.dart';

class StaffEditScreen extends ConsumerStatefulWidget {
  const StaffEditScreen({super.key, required this.staffId, this.initial});

  final String staffId;
  final StaffMember? initial;

  @override
  ConsumerState<StaffEditScreen> createState() => _StaffEditScreenState();
}

class _StaffEditScreenState extends ConsumerState<StaffEditScreen> {
  late TextEditingController _name;
  late TextEditingController _phone;
  late String _role;
  late String _status;
  late Map<String, dynamic> _permissions;
  StaffMember? _loaded;
  bool _loading = true;
  bool _saving = false;
  bool _forceBusy = false;

  @override
  void initState() {
    super.initState();
    if (widget.initial != null) {
      _applyMember(widget.initial!);
      _loading = false;
    } else {
      _bootstrap();
    }
  }

  Future<void> _bootstrap() async {
    final row = await ref.read(staffRepositoryProvider).fetchStaffMember(widget.staffId);
    if (!mounted) return;
    if (row == null) {
      setState(() => _loading = false);
      return;
    }
    setState(() {
      _applyMember(row);
      _loaded = row;
      _loading = false;
    });
  }

  void _applyMember(StaffMember m) {
    _name = TextEditingController(text: m.fullName == '—' ? '' : m.fullName);
    _phone = TextEditingController(text: m.phone ?? '');
    _role = m.role;
    _status = m.staffStatus;
    _permissions = Map<String, dynamic>.from(m.permissions);
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  StaffMember? get _member => widget.initial ?? _loaded;

  Future<void> _forceLogout() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign out this user?'),
        content: const Text(
          'They will be signed out on all devices after their next permission check, '
          'and active device registrations are revoked.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Force sign out')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _forceBusy = true);
    try {
      await ref.read(staffRepositoryProvider).forceLogoutStaffMember(staffId: widget.staffId);
      KpmsStaffRbacLog.forcedLogout(detail: 'staff_id=${widget.staffId}');
      ref.invalidate(tenantStaffListProvider);
      if (mounted) kpmsSnack(context, 'Forced sign-out queued');
    } catch (e) {
      if (mounted) kpmsSnack(context, '$e', isError: true);
    } finally {
      if (mounted) setState(() => _forceBusy = false);
    }
  }

  Future<void> _save() async {
    final member = _member;
    if (member == null) return;
    setState(() => _saving = true);
    try {
      final prevRole = member.role;
      await ref.read(staffRepositoryProvider).updateStaffProfile(
            staffId: widget.staffId,
            fullName: _name.text.trim(),
            phone: _phone.text.trim(),
            staffStatus: _status,
            permissions: _permissions,
            role: member.role == 'pharmacy_owner' ? null : _role,
          );
      ref.invalidate(tenantStaffListProvider);
      KpmsPermissionGate.invalidate();
      final tid = ref.read(kpmsActiveTenantIdProvider).valueOrNull;
      final actor = ref.read(supabaseAuthUserIdProvider).valueOrNull;
      if (tid != null && actor != null) {
        KpmsStaffRbacLog.roleAssigned(staffId: widget.staffId, role: _role);
        KpmsStaffRbacLog.permissionUpdated(staffId: widget.staffId);
        unawaited(
          PharmacyAuditService.record(
            tenantId: tid,
            action: 'staff_profile_updated',
            entityType: 'staff_profile',
            entityRef: widget.staffId,
            actorId: actor,
            previousData: {'role': prevRole},
            nextData: {'role': _role, 'staff_status': _status},
          ),
        );
        unawaited(
          PharmacyNotificationRepository.upsertOperational(
            tenantId: tid,
            userId: actor,
            kind: KpmsNotificationKind.staffPermissionUpdated,
            title: 'Staff access updated',
            body: member.fullName,
            dedupeKey: 'staff_perm:${widget.staffId}',
            priority: 'normal',
            payload: {'staff_id': widget.staffId, 'role': _role},
          ),
        );
      }
      if (!mounted) return;
      kpmsSnack(context, 'Staff profile updated');
      context.pop();
    } catch (e) {
      if (mounted) kpmsSnack(context, 'Update failed: $e', isError: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final perm = ref.watch(kpmsPermissionContextProvider).valueOrNull;
    final uid = SupabaseBootstrap.clientOrNull?.auth.currentUser?.id;

    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final member = _member;
    if (member == null) {
      return KpmsPageShell(
        title: 'Staff',
        body: Center(child: Text('User not found', style: theme.textTheme.bodyLarge)),
      );
    }

    final roleLocked = member.role == 'pharmacy_owner';
    final canForceOut =
        perm != null && perm.canManageStaffDirectory && uid != null && widget.staffId != uid && !roleLocked;

    return KpmsPageShell(
      title: 'Edit staff',
      subtitle: member.fullName,
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          0,
          8,
          0,
          120 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        children: [
          TextField(
            controller: _name,
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
          if (roleLocked)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('Role', style: theme.textTheme.labelLarge),
              subtitle: Text('Pharmacy owner', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            )
          else
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
                    if (!KpmsRolePresets.enterpriseRoleOptions.any((o) => o.dbRole == _role))
                      DropdownMenuItem(value: _role, child: Text('$_role (legacy)')),
                    for (final o in KpmsRolePresets.enterpriseRoleOptions)
                      DropdownMenuItem(value: o.dbRole, child: Text(o.label)),
                  ],
                  onChanged: (v) {
                    if (v != null) {
                      setState(() {
                        _role = v;
                        KpmsRolePresets.applyRoleTemplate(v, (m) => _permissions = m);
                      });
                    }
                  },
                ),
              ),
            ),
          const SizedBox(height: 14),
          InputDecorator(
            decoration: const InputDecoration(
              labelText: 'Status',
              border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(16))),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                isExpanded: true,
                value: _status,
                items: const [
                  DropdownMenuItem(value: 'active', child: Text('Active')),
                  DropdownMenuItem(value: 'inactive', child: Text('Inactive')),
                ],
                onChanged: (v) {
                  if (v != null) setState(() => _status = v);
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
          if (canForceOut) ...[
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: _forceBusy ? null : _forceLogout,
              icon: _forceBusy
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.logout_rounded),
              label: const Text('Force sign out everywhere'),
            ),
          ],
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: Text(_saving ? 'Saving…' : 'Save changes'),
          ),
        ],
      ),
    );
  }
}
