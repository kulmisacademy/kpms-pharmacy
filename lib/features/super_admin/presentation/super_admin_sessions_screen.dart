import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_routes.dart';
import '../../../core/widgets/kpms_platform_admin_shell.dart';
import '../application/platform_admin_providers.dart';
import 'widgets/pharmacy_admin_actions.dart';
import 'widgets/platform_admin_ui.dart';

/// Active sessions view — derived from cross-tenant profiles (`last_sign_in_at`).
class SuperAdminSessionsScreen extends ConsumerWidget {
  const SuperAdminSessionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(superAdminUsersProvider);
    return KpmsPlatformAdminShell(
      title: 'Sessions',
      subtitle: 'Recent sign-ins across tenants',
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh_rounded),
          onPressed: () => ref.invalidate(superAdminUsersProvider),
        ),
      ],
      body: async.when(
        loading: () => const PlatformSkeletonList(),
        error: (e, _) => Center(child: Text('$e')),
        data: (rows) {
          final recent = [...rows]
            ..sort((a, b) {
              final ta = a['last_sign_in_at']?.toString() ?? '';
              final tb = b['last_sign_in_at']?.toString() ?? '';
              return tb.compareTo(ta);
            });
          final active = recent.where((r) {
            final t = DateTime.tryParse(r['last_sign_in_at']?.toString() ?? '');
            if (t == null) return false;
            return DateTime.now().difference(t.toUtc()).inHours < 24;
          }).toList();

          return ListView(
            padding: const EdgeInsets.only(bottom: PlatformAdminSpacing.xl),
            children: [
              PlatformSectionHeader(
                title: 'Active in last 24h',
                subtitle: '${active.length} users',
              ),
              if (active.isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: Text('No recent sign-ins in the last 24 hours.'),
                  ),
                )
              else
                ...active.take(40).map((r) => _SessionTile(row: r)),
              const SizedBox(height: PlatformAdminSpacing.lg),
              PlatformSectionHeader(title: 'All profiles', subtitle: 'Sorted by last sign-in'),
              ...recent.take(80).map((r) => _SessionTile(row: r)),
            ],
          );
        },
      ),
    );
  }
}

class _SessionTile extends ConsumerWidget {
  const _SessionTile({required this.row});

  final Map<String, dynamic> row;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tenantId = row['tenant_id']?.toString();
    return Card(
      margin: const EdgeInsets.only(bottom: PlatformAdminSpacing.sm),
      child: ListTile(
        title: Text(row['full_name']?.toString() ?? row['account_email']?.toString() ?? 'User'),
        subtitle: Text(
          '${row['role']} · ${row['pharmacy_name'] ?? 'Platform'}\nLast sign-in: ${row['last_sign_in_at'] ?? '—'}',
        ),
        isThreeLine: true,
        trailing: tenantId == null || tenantId.isEmpty
            ? null
            : PopupMenuButton<String>(
                onSelected: (v) async {
                  if (v == 'force') {
                    await PharmacyAdminActions.forceLogout(context, ref, tenantId);
                  } else if (v == 'pharmacy') {
                    if (context.mounted) context.push(AppRoutes.superAdminPharmacyDetail(tenantId));
                  }
                },
                itemBuilder: (ctx) => const [
                  PopupMenuItem(value: 'pharmacy', child: Text('Open pharmacy')),
                  PopupMenuItem(value: 'force', child: Text('Force logout tenant')),
                ],
              ),
      ),
    );
  }
}
