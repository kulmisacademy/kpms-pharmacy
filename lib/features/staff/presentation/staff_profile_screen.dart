import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_routes.dart';
import '../../../core/supabase/supabase_bootstrap.dart';
import '../../../core/widgets/kpms_page_shell.dart';
import '../../sales/application/sales_ledger_notifier.dart';
import '../application/staff_providers.dart';
import '../domain/staff_member.dart';

final _staffProfileProvider = FutureProvider.family<StaffMember?, String>((ref, staffId) async {
  return ref.read(staffRepositoryProvider).fetchStaffMember(staffId);
});

final _staffActivityProvider = FutureProvider.family<List<Map<String, dynamic>>, String>((ref, staffId) async {
  return ref.read(staffRepositoryProvider).listStaffActivity(staffId);
});

/// Full staff profile, sales stats, recent invoices, activity log.
class StaffProfileScreen extends ConsumerWidget {
  const StaffProfileScreen({super.key, required this.staffId});

  final String staffId;

  static String _fmt(DateTime t) {
    final l = t.toLocal();
    final d = '${l.year}-${l.month.toString().padLeft(2, '0')}-${l.day.toString().padLeft(2, '0')}';
    final hm = '${l.hour.toString().padLeft(2, '0')}:${l.minute.toString().padLeft(2, '0')}';
    return '$d $hm';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final memberAsync = ref.watch(_staffProfileProvider(staffId));
    final activityAsync = ref.watch(_staffActivityProvider(staffId));
    final ledger = ref.watch(salesLedgerProvider);
    final myId = SupabaseBootstrap.clientOrNull?.auth.currentUser?.id;
    final canManage = myId != null && myId != staffId;

    return KpmsPageShell(
      title: 'Staff profile',
      subtitle: 'Performance · access · activity',
      actions: [
        if (canManage)
          TextButton(
            onPressed: () => context.push(AppRoutes.staffEdit(staffId)),
            child: const Text('Edit'),
          ),
      ],
      body: memberAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (m) {
          if (m == null) {
            return const Center(child: Text('Staff member not found.'));
          }
          final salesInv = ledger.invoices.where((i) => i.cashierUserId == staffId).toList();
          salesInv.sort((a, b) => b.issuedAt.compareTo(a.issuedAt));
          final totalSales = salesInv.fold<double>(0, (s, i) => s + i.total);

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
            children: [
              Text(m.fullName, style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              Text('${m.role} · ${m.staffStatus}', style: theme.textTheme.bodyMedium?.copyWith(color: theme.hintColor)),
              if (m.email != null && m.email!.isNotEmpty) ...[
                const SizedBox(height: 8),
                SelectableText(m.email!, style: theme.textTheme.bodyLarge),
              ],
              if (m.phone != null && m.phone!.isNotEmpty) Text(m.phone!, style: theme.textTheme.bodyMedium),
              const SizedBox(height: 8),
              Text('Permissions · ${m.permissionsSummary}', style: theme.textTheme.labelLarge),
              const SizedBox(height: 8),
              Text(
                'Last sign-in · ${m.lastSignInAt != null ? StaffProfileScreen._fmt(m.lastSignInAt!) : 'Never'}',
                style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
              ),
              const SizedBox(height: 24),
              _StatRow(label: 'Sales invoices (this device)', value: '${salesInv.length}'),
              _StatRow(label: 'Total sold (sum)', value: r'$' + totalSales.toStringAsFixed(2)),
              const SizedBox(height: 24),
              Text('Recent invoices', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              if (salesInv.isEmpty)
                Text('No completed sales attributed to this user on this device.', style: theme.textTheme.bodySmall)
              else
                ...salesInv.take(12).map(
                      (i) => ListTile(
                        dense: true,
                        title: Text(i.invoiceNumber, style: const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text('${StaffProfileScreen._fmt(i.issuedAt)} · ${i.customerName}'),
                        trailing: Text(r'$' + i.total.toStringAsFixed(2)),
                      ),
                    ),
              const SizedBox(height: 24),
              Text('Activity (server)', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              activityAsync.when(
                loading: () => const LinearProgressIndicator(),
                error: (e, _) => const Text('Could not load activity.'),
                data: (rows) {
                  if (rows.isEmpty) {
                    return Text(
                      'No logged activity yet. Completing sales records events when the activity migration is live.',
                      style: theme.textTheme.bodySmall,
                    );
                  }
                  return Column(
                    children: [
                      for (final r in rows)
                        ListTile(
                          dense: true,
                          title: Text('${r['action']}', style: const TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: Text(
                            '${r['entity_type'] ?? '—'} ${r['entity_ref'] ?? ''}\n${StaffProfileScreen._fmt(DateTime.tryParse('${r['created_at']}') ?? DateTime.now())}',
                          ),
                        ),
                    ],
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(child: Text(label, style: theme.textTheme.bodyMedium)),
          Text(value, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}
