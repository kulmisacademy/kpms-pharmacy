import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/navigation/kpms_breakpoints.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/kpms_platform_admin_shell.dart';
import '../application/platform_admin_providers.dart';

/// Operator view: lightweight platform health from `super_admin_platform_health` + KPI context.
class SuperAdminMonitoringScreen extends ConsumerWidget {
  const SuperAdminMonitoringScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(superAdminPlatformHealthProvider);
    final stats = ref.watch(superAdminDashboardStatsProvider);
    final theme = Theme.of(context);

    return KpmsPlatformAdminShell(
      title: 'Platform health',
      subtitle: 'Realtime, push, and sync signals (operator RPCs)',
      actions: [
        IconButton(
          tooltip: 'Refresh',
          onPressed: () {
            ref.invalidate(superAdminPlatformHealthProvider);
            ref.invalidate(superAdminDashboardStatsProvider);
          },
          icon: const Icon(Icons.refresh_rounded),
        ),
      ],
      body: ListView(
        padding: KpmsBreakpoints.pageScrollPadding(context),
        children: [
          async.when(
            loading: () => const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator())),
            error: (e, _) => Text('$e', style: TextStyle(color: theme.colorScheme.error)),
            data: (h) => GlassCard(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Live checks', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 12),
                  _kv(theme, 'Realtime', '${h['realtime_ok'] ?? '—'}'),
                  _kv(theme, 'Push (FCM) hub', '${h['push_fcm_ok'] ?? '—'}'),
                  _kv(theme, 'Sync-related audit hits (24h)', '${h['failed_api_window_24h'] ?? '—'}'),
                  _kv(theme, 'Slow query hint', '${h['slow_query_hint'] ?? '—'}'),
                  _kv(theme, 'Checked at', '${h['checked_at'] ?? '—'}'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          stats.when(
            loading: () => const SizedBox.shrink(),
            error: (_, _) => const SizedBox.shrink(),
            data: (s) => GlassCard(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Correlated volume', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 12),
                  _kv(theme, 'Sales transactions (30d)', '${s['sales_transactions_30d'] ?? '—'}'),
                  _kv(theme, 'DAU estimate', '${s['daily_active_users_est'] ?? '—'}'),
                  _kv(theme, 'Sync health score', '${s['sync_health_score'] ?? '—'}'),
                  _kv(theme, 'Notification delivery %', '${s['notification_delivery_pct'] ?? '—'}'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Wire external APM (Sentry/Datadog) for deep traces. Client emits [kpms.performance] and [kpms.platform] logs.',
            style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor, height: 1.4),
          ),
        ],
      ),
    );
  }

  static Widget _kv(ThemeData theme, String k, String v) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 220,
            child: Text(k, style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600)),
          ),
          Expanded(child: Text(v, style: theme.textTheme.bodyMedium)),
        ],
      ),
    );
  }
}
