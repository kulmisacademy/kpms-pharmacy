import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/navigation/kpms_breakpoints.dart';
import '../../../core/widgets/kpms_platform_admin_shell.dart';
import '../application/platform_admin_providers.dart';

class SuperAdminUsersScreen extends ConsumerWidget {
  const SuperAdminUsersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(superAdminUsersProvider);
    return KpmsPlatformAdminShell(
      title: 'Users',
      subtitle: 'Cross-tenant directory',
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh_rounded),
          onPressed: () => ref.invalidate(superAdminUsersProvider),
        ),
      ],
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (rows) => ListView.separated(
          padding: KpmsBreakpoints.pageScrollPadding(context),
          itemCount: rows.length,
          separatorBuilder: (context, index) => const SizedBox(height: 8),
          itemBuilder: (context, i) {
            final r = rows[i];
            return Card(
              child: ListTile(
                title: Text(r['full_name']?.toString() ?? r['account_email']?.toString() ?? 'User'),
                subtitle: Text(
                  '${r['role'] ?? ''} · ${r['pharmacy_name'] ?? 'No pharmacy'}\n${r['account_email'] ?? ''}',
                ),
                isThreeLine: true,
                trailing: Chip(
                  label: Text(r['staff_status']?.toString() ?? ''),
                  visualDensity: VisualDensity.compact,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
