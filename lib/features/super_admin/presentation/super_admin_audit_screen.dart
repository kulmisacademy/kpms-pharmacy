import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/logging/kpms_superadmin_platform_log.dart';
import '../../../core/navigation/kpms_breakpoints.dart';
import '../../../core/widgets/kpms_platform_admin_shell.dart';
import '../application/platform_admin_providers.dart';

class SuperAdminAuditScreen extends ConsumerStatefulWidget {
  const SuperAdminAuditScreen({super.key});

  @override
  ConsumerState<SuperAdminAuditScreen> createState() => _SuperAdminAuditScreenState();
}

class _SuperAdminAuditScreenState extends ConsumerState<SuperAdminAuditScreen> {
  final _action = TextEditingController();
  final _query = TextEditingController();
  int _days = 30;

  @override
  void dispose() {
    _action.dispose();
    _query.dispose();
    super.dispose();
  }

  void _apply() {
    ref.read(superAdminAuditFilterProvider.notifier).state = (_action.text.trim(), _query.text.trim(), _days);
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(superAdminAuditProvider);
    final theme = Theme.of(context);
    return KpmsPlatformAdminShell(
      title: 'Audit log',
      subtitle: 'Super Admin actions · searchable',
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh_rounded),
          onPressed: () => ref.invalidate(superAdminAuditProvider),
        ),
      ],
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: KpmsBreakpoints.pageBodyInsets(context),
            child: LayoutBuilder(
              builder: (context, c) {
                final narrow = c.maxWidth < 720;
                final a = TextField(
                  controller: _action,
                  decoration: const InputDecoration(
                    labelText: 'Action contains',
                    border: OutlineInputBorder(),
                  ),
                  onSubmitted: (_) => _apply(),
                );
                final q = TextField(
                  controller: _query,
                  decoration: const InputDecoration(
                    labelText: 'Search actor / metadata',
                    border: OutlineInputBorder(),
                  ),
                  onSubmitted: (_) => _apply(),
                );
                final days = DropdownButtonFormField<int>(
                  key: ValueKey(_days),
                  initialValue: _days,
                  decoration: const InputDecoration(labelText: 'Date range', border: OutlineInputBorder()),
                  items: const [
                    DropdownMenuItem(value: 7, child: Text('Last 7 days')),
                    DropdownMenuItem(value: 30, child: Text('Last 30 days')),
                    DropdownMenuItem(value: 90, child: Text('Last 90 days')),
                    DropdownMenuItem(value: 0, child: Text('All loaded')),
                  ],
                  onChanged: (v) => setState(() => _days = v ?? 30),
                );
                if (narrow) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      a,
                      const SizedBox(height: 8),
                      q,
                      const SizedBox(height: 8),
                      days,
                      const SizedBox(height: 8),
                      FilledButton.tonalIcon(
                        onPressed: _apply,
                        icon: const Icon(Icons.search_rounded),
                        label: const Text('Apply'),
                      ),
                    ],
                  );
                }
                return Row(
                  children: [
                    Expanded(child: a),
                    const SizedBox(width: 10),
                    Expanded(child: q),
                    const SizedBox(width: 10),
                    SizedBox(width: 160, child: days),
                    const SizedBox(width: 10),
                    FilledButton.tonalIcon(
                      onPressed: _apply,
                      icon: const Icon(Icons.search_rounded),
                      label: const Text('Apply'),
                    ),
                  ],
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: async.maybeWhen(
                  data: (rows) => rows.isEmpty
                      ? null
                      : () {
                          final b = StringBuffer();
                          b.writeln('action,created_at,actor_email,entity_type,entity_id');
                          for (final r in rows) {
                            final line = [
                              '"${(r['action'] ?? '').toString().replaceAll('"', '""')}"',
                              '"${(r['created_at'] ?? '').toString().replaceAll('"', '""')}"',
                              '"${(r['actor_email'] ?? '').toString().replaceAll('"', '""')}"',
                              '"${(r['entity_type'] ?? '').toString().replaceAll('"', '""')}"',
                              '"${(r['entity_id'] ?? '').toString().replaceAll('"', '""')}"',
                            ].join(',');
                            b.writeln(line);
                          }
                          Clipboard.setData(ClipboardData(text: b.toString()));
                          KpmsPlatformLog.auditExported(rows: rows.length);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Copied ${rows.length} rows as CSV')),
                          );
                        },
                  orElse: () => null,
                ),
                icon: const Icon(Icons.copy_outlined),
                label: const Text('Export CSV (copy)'),
              ),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: async.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('$e')),
              data: (rows) => ListView.separated(
                padding: KpmsBreakpoints.pageScrollPadding(context),
                itemCount: rows.length,
                separatorBuilder: (context, index) => const Divider(height: 1),
                itemBuilder: (context, i) {
                  final r = rows[i];
                  return ListTile(
                    title: Text(r['action']?.toString() ?? '', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                    subtitle: Text(
                      '${r['created_at'] ?? ''}\n${r['actor_email'] ?? ''} · ${r['entity_type'] ?? ''} ${r['entity_id'] ?? ''}',
                      style: theme.textTheme.bodySmall,
                    ),
                    isThreeLine: true,
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
