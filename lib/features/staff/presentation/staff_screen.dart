import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/permission_providers.dart';
import '../../../core/constants/app_routes.dart';
import '../../../core/supabase/supabase_bootstrap.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/kpms_feedback.dart';
import '../../../core/widgets/kpms_empty_state.dart';
import '../../../core/widgets/kpms_page_shell.dart';
import '../application/staff_providers.dart';

/// Tenant staff directory — create accounts, profiles, permissions, lifecycle.
class StaffScreen extends ConsumerWidget {
  const StaffScreen({super.key});

  static String _initials(String name) {
    final p = name.trim().split(RegExp(r'\s+')).where((e) => e.isNotEmpty).take(2).toList();
    if (p.isEmpty) return '?';
    return p.map((e) => e[0].toUpperCase()).join();
  }

  static String _formatLastLogin(DateTime? t) {
    if (t == null) return 'Never';
    final l = t.toLocal();
    final d = '${l.year}-${l.month.toString().padLeft(2, '0')}-${l.day.toString().padLeft(2, '0')}';
    final hm = '${l.hour.toString().padLeft(2, '0')}:${l.minute.toString().padLeft(2, '0')}';
    return '$d $hm';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final perm = ref.watch(kpmsPermissionContextProvider);
    final listAsync = ref.watch(tenantStaffListProvider);
    final myId = SupabaseBootstrap.clientOrNull?.auth.currentUser?.id;

    return perm.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => KpmsPageShell(title: 'Staff', body: const Text('Could not load access.')),
      data: (p) {
        final canInvite = p.canManageStaffDirectory;
        final canEditAny = p.canManageStaffDirectory;

        return KpmsPageShell(
          title: 'Staff',
          subtitle: 'Accounts · roles · permissions',
          floatingActionButton: canInvite
              ? FloatingActionButton.extended(
                  onPressed: () => context.push(AppRoutes.staffCreate),
                  icon: const Icon(Icons.person_add_alt_1_rounded),
                  label: const Text('Create staff'),
                )
              : null,
          body: RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(tenantStaffListProvider);
              await ref.read(tenantStaffListProvider.future);
            },
            child: listAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(24),
                children: [
                  Text('Could not load team: $e', style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.error)),
                ],
              ),
              data: (members) {
                if (members.isEmpty) {
                  return ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      SizedBox(height: MediaQuery.sizeOf(context).height * 0.12),
                      KpmsEmptyState(
                        icon: Icons.groups_outlined,
                        title: 'No staff yet',
                        message: canInvite
                            ? 'Create staff with email and password — they sign in immediately (no invitation link).'
                            : 'Your pharmacy directory will appear here.',
                        actionLabel: canInvite ? 'Create staff' : null,
                        onAction: canInvite ? () => context.push(AppRoutes.staffCreate) : null,
                      ),
                    ],
                  );
                }
                return ListView.separated(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(0, 4, 0, 120),
                  itemCount: members.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, i) {
                    final m = members[i];
                    final isSelf = myId != null && m.id == myId;
                    final active = m.staffStatus.toLowerCase() == 'active';
                    return Material(
                      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                        side: BorderSide(color: theme.colorScheme.outline.withValues(alpha: 0.16)),
                      ),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: canInvite ? () => context.push(AppRoutes.staffProfile(m.id)) : null,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(14, 14, 6, 14),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              CircleAvatar(
                                backgroundColor: AppColors.primary.withValues(alpha: 0.14),
                                foregroundColor: AppColors.primary,
                                child: Text(_initials(m.fullName), style: const TextStyle(fontWeight: FontWeight.w800)),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            m.fullName,
                                            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                                          ),
                                        ),
                                        if (isSelf)
                                          Padding(
                                            padding: const EdgeInsets.only(right: 8),
                                            child: Text(
                                              'You',
                                              style: theme.textTheme.labelSmall?.copyWith(
                                                fontWeight: FontWeight.w700,
                                                color: theme.colorScheme.primary,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${m.role} · ${active ? 'Active' : 'Inactive'}',
                                      style: theme.textTheme.bodySmall?.copyWith(
                                        color: theme.colorScheme.onSurface.withValues(alpha: 0.68),
                                      ),
                                    ),
                                    if (m.phone != null && m.phone!.isNotEmpty) ...[
                                      const SizedBox(height: 2),
                                      Text(m.phone!, style: theme.textTheme.bodySmall),
                                    ],
                                    if (m.email != null && m.email!.isNotEmpty) ...[
                                      const SizedBox(height: 2),
                                      Text(m.email!, style: theme.textTheme.bodySmall),
                                    ],
                                    const SizedBox(height: 6),
                                    Text(
                                      'Last sign-in · ${_formatLastLogin(m.lastSignInAt)}',
                                      style: theme.textTheme.labelSmall?.copyWith(
                                        color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      'Permissions · ${m.permissionsSummary}',
                                      style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600),
                                    ),
                                  ],
                                ),
                              ),
                              if (canEditAny && !isSelf)
                                PopupMenuButton<String>(
                                  icon: const Icon(Icons.more_vert_rounded),
                                  onSelected: (action) async {
                                    if (action == 'edit') {
                                      if (!context.mounted) return;
                                      context.push(AppRoutes.staffEdit(m.id), extra: m);
                                    }
                                    if (action == 'reset') {
                                      final emailCtrl = TextEditingController(text: m.email ?? '');
                                      final ok = await showDialog<bool>(
                                        context: context,
                                        builder: (ctx) => AlertDialog(
                                          title: const Text('Password reset'),
                                          content: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            crossAxisAlignment: CrossAxisAlignment.stretch,
                                            children: [
                                              const Text(
                                                'Supabase will email a reset link. Enter the address this person uses to sign in.',
                                              ),
                                              const SizedBox(height: 12),
                                              TextField(
                                                controller: emailCtrl,
                                                keyboardType: TextInputType.emailAddress,
                                                decoration: const InputDecoration(
                                                  labelText: 'Email',
                                                  border: OutlineInputBorder(),
                                                ),
                                              ),
                                            ],
                                          ),
                                          actions: [
                                            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                                            FilledButton(
                                              onPressed: () => Navigator.pop(ctx, true),
                                              child: const Text('Send'),
                                            ),
                                          ],
                                        ),
                                      );
                                      if (ok == true && context.mounted) {
                                        final em = emailCtrl.text.trim();
                                        emailCtrl.dispose();
                                        if (!em.contains('@')) {
                                          kpmsSnack(context, 'Enter a valid email', isError: true);
                                          return;
                                        }
                                        try {
                                          await ref.read(staffRepositoryProvider).sendPasswordResetEmail(em);
                                          if (context.mounted) {
                                            kpmsSnack(context, 'If the account exists, a reset email was sent.');
                                          }
                                        } catch (e) {
                                          if (context.mounted) {
                                            kpmsSnackError(context, e);
                                          }
                                        }
                                      } else {
                                        emailCtrl.dispose();
                                      }
                                    }
                                    if (action == 'disable') {
                                      if (!context.mounted) return;
                                      final sure = await showDialog<bool>(
                                        context: context,
                                        builder: (ctx) => AlertDialog(
                                          title: const Text('Disable account?'),
                                          content: Text('${m.fullName} will be signed out on next request and cannot open the console.'),
                                          actions: [
                                            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                                            FilledButton(
                                              onPressed: () => Navigator.pop(ctx, true),
                                              child: const Text('Disable'),
                                            ),
                                          ],
                                        ),
                                      );
                                      if (sure == true && context.mounted) {
                                        try {
                                          await ref.read(staffRepositoryProvider).updateStaffProfile(
                                                staffId: m.id,
                                                staffStatus: 'inactive',
                                              );
                                          ref.invalidate(tenantStaffListProvider);
                                          if (!context.mounted) return;
                                          kpmsSnack(context, 'Account disabled');
                                        } catch (e) {
                                          if (!context.mounted) return;
                                          kpmsSnack(context, 'Failed: $e', isError: true);
                                        }
                                      }
                                    }
                                    if (action == 'delete') {
                                      if (!context.mounted) return;
                                      final sure = await showDialog<bool>(
                                        context: context,
                                        builder: (ctx) => AlertDialog(
                                          title: const Text('Delete staff account?'),
                                          content: Text(
                                            'Permanently remove ${m.fullName} from auth and this pharmacy. '
                                            'Deploy the delete-tenant-staff Edge Function for this to succeed.',
                                          ),
                                          actions: [
                                            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                                            FilledButton(
                                              style: FilledButton.styleFrom(backgroundColor: Theme.of(ctx).colorScheme.error),
                                              onPressed: () => Navigator.pop(ctx, true),
                                              child: const Text('Delete'),
                                            ),
                                          ],
                                        ),
                                      );
                                      if (sure == true && context.mounted) {
                                        try {
                                          await ref.read(staffRepositoryProvider).deleteStaffAccount(m.id);
                                          ref.invalidate(tenantStaffListProvider);
                                          if (!context.mounted) return;
                                          kpmsSnack(context, 'Staff account removed');
                                        } catch (e) {
                                          if (!context.mounted) return;
                                          kpmsSnack(context, 'Delete failed: $e', isError: true);
                                        }
                                      }
                                    }
                                  },
                                  itemBuilder: (ctx) => [
                                    const PopupMenuItem(value: 'edit', child: Text('Edit & permissions')),
                                    const PopupMenuItem(value: 'reset', child: Text('Email password reset')),
                                    PopupMenuItem(
                                      value: 'disable',
                                      enabled: active,
                                      child: Text(active ? 'Disable account' : 'Already inactive'),
                                    ),
                                    const PopupMenuItem(value: 'delete', child: Text('Delete account')),
                                  ],
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        );
      },
    );
  }
}
