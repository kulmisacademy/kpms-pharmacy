import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/navigation/kpms_breakpoints.dart';
import '../../../core/utils/kpms_feedback.dart';
import '../../../core/widgets/kpms_platform_admin_shell.dart';

/// PRD §4.1 — Support tickets from tenants.
class SuperAdminSupportScreen extends ConsumerWidget {
  const SuperAdminSupportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final tickets = [
      ('TCK-204', 'Billing question', 'Open', 'High'),
      ('TCK-198', 'Cannot upload Rx', 'Waiting', 'Normal'),
    ];

    return KpmsPlatformAdminShell(
      title: 'Support tickets',
      subtitle: 'Help desk queue',
      body: ListView.separated(
        padding: KpmsBreakpoints.pageScrollPadding(context),
        itemCount: tickets.length,
        separatorBuilder: (context, index) => const SizedBox(height: 10),
        itemBuilder: (context, i) {
          final t = tickets[i];
          return Card(
            child: ListTile(
              title: Text(t.$1, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
              subtitle: Text('${t.$2}\nPriority ${t.$4}', style: theme.textTheme.bodySmall),
              isThreeLine: true,
              trailing: Chip(label: Text(t.$3), visualDensity: VisualDensity.compact),
              onTap: () {
                showDialog<void>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: Text(t.$1),
                    content: Text('${t.$2}\nStatus: ${t.$3} · Priority ${t.$4}'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
                      FilledButton(
                        onPressed: () {
                          Navigator.pop(ctx);
                          kpmsSnack(context, 'Reply composer opens here.');
                        },
                        child: const Text('Reply'),
                      ),
                    ],
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
