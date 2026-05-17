import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/navigation/kpms_breakpoints.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/kpms_page_shell.dart';
import '../application/pharmacy_notifications_providers.dart';
import '../domain/pharmacy_notification_models.dart';

/// Enterprise notification inbox — grouped by category, tenant-backed.
class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  final ScrollController _scroll = ScrollController();

  static String _priorityLabel(String p) => switch (p) {
        'critical' => 'Critical',
        'high' => 'High',
        'low' => 'Low',
        _ => 'Normal',
      };

  static Color _priorityColor(String p) => switch (p) {
        'critical' => Colors.red.shade700,
        'high' => Colors.orange.shade800,
        'low' => Colors.blueGrey,
        _ => AppColors.primary,
      };

  static String _fmt(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')} '
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
  }

  void _onScroll() {
    if (!_scroll.hasClients) return;
    final pos = _scroll.position;
    if (pos.maxScrollExtent - pos.pixels < 220) {
      ref.read(pharmacyNotificationFeedProvider.notifier).loadMore();
    }
  }

  @override
  void dispose() {
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(pharmacyNotificationFeedProvider);
    final unreadBadge = ref.watch(pharmacyNotificationUnreadCountSyncProvider);
    final theme = Theme.of(context);

    return KpmsPageShell(
      title: 'Notifications',
      subtitle: 'Operational alerts · realtime · push-ready',
      actions: [
        if (unreadBadge > 0)
          TextButton(
            onPressed: () => ref.read(pharmacyNotificationFeedProvider.notifier).markAllUnreadRead(),
            child: const Text('Mark all read'),
          ),
      ],
      body: Padding(
        padding: KpmsBreakpoints.pageBodyInsets(context),
        child: async.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Could not load: $e')),
          data: (model) {
            final items = model.items;
            if (items.isEmpty) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.notifications_off_outlined, size: 48, color: theme.hintColor),
                    const SizedBox(height: 12),
                    Text(
                      'No alerts yet',
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Low stock, expiry, debts, sync, and subscription notices appear here.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor, height: 1.4),
                    ),
                  ],
                ),
              );
            }
            final groups = <String, List<PharmacyNotificationItem>>{};
            for (final i in items) {
              groups.putIfAbsent(KpmsNotificationKind.groupLabel(i.kind), () => []).add(i);
            }
            final keys = groups.keys.toList()..sort();
            final tail = model.isLoadingMore ? 1 : 0;

            return RefreshIndicator(
              onRefresh: () => ref.read(pharmacyNotificationFeedProvider.notifier).refresh(),
              child: ListView.builder(
                controller: _scroll,
                physics: const AlwaysScrollableScrollPhysics(),
                itemCount: keys.length + tail,
                itemBuilder: (context, gi) {
                  if (gi >= keys.length) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Center(child: LinearProgressIndicator(minHeight: 3)),
                    );
                  }
                  final g = keys[gi];
                  final rows = groups[g]!..sort((a, b) => b.createdAt.compareTo(a.createdAt));
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
                        child: Text(
                          g,
                          style: theme.textTheme.labelLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: theme.hintColor,
                          ),
                        ),
                      ),
                      ...rows.map(
                        (n) => Card(
                          margin: const EdgeInsets.only(bottom: 10),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: BorderSide(
                              color: theme.colorScheme.outline.withValues(alpha: n.isUnread ? 0.35 : 0.18),
                            ),
                          ),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () {
                              if (n.isUnread) {
                                ref.read(pharmacyNotificationFeedProvider.notifier).markRead(n.id);
                              }
                            },
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: _priorityColor(n.priority).withValues(alpha: 0.12),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          _priorityLabel(n.priority),
                                          style: theme.textTheme.labelSmall?.copyWith(
                                            color: _priorityColor(n.priority),
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ),
                                      const Spacer(),
                                      Text(
                                        _fmt(n.createdAt),
                                        style: theme.textTheme.labelSmall?.copyWith(color: theme.hintColor),
                                      ),
                                      if (n.isUnread) ...[
                                        const SizedBox(width: 8),
                                        Icon(Icons.circle, size: 8, color: AppColors.primary),
                                      ],
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    n.title,
                                    style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                                  ),
                                  if (n.body.isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      n.body,
                                      style: theme.textTheme.bodySmall?.copyWith(height: 1.35),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }
}
