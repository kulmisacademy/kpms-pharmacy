import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/constants/app_routes.dart';
import '../../../core/navigation/kpms_breakpoints.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/kpms_platform_admin_shell.dart';
import '../application/platform_admin_providers.dart';

List<Map<String, dynamic>> _dashboardTrendList(dynamic v) {
  if (v is List) {
    return v.map((e) => Map<String, dynamic>.from(e as Map)).toList(growable: false);
  }
  return const [];
}

String _shortMonthLabel(String? yyyyMm) {
  if (yyyyMm == null || yyyyMm.length < 7) return '';
  final y = yyyyMm.substring(2, 4);
  final m = yyyyMm.substring(5, 7);
  return '$m/$y';
}

/// Super Admin dashboard — live KPIs from `super_admin_dashboard_stats` and pharmacy directory.
class SuperAdminDashboardScreen extends ConsumerWidget {
  const SuperAdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final stats = ref.watch(superAdminDashboardStatsProvider);
    final pharms = ref.watch(superAdminPharmaciesProvider);

    final s = stats.valueOrNull ?? {};
    final rows = pharms.valueOrNull ?? [];
    final revenueTrend = _dashboardTrendList(s['revenue_trend']);
    final growthTrend = _dashboardTrendList(s['growth_trend']);
    final topByActivity = _dashboardTrendList(s['top_pharmacies']);

    final total = '${s['total_pharmacies'] ?? '—'}';
    final activePh = '${s['active_pharmacies'] ?? '—'}';
    final activeSub = '${s['active_subscriptions'] ?? '—'}';
    final mrrCents = (s['estimated_mrr_cents'] as num?)?.toInt();
    final mrr = mrrCents != null ? '\$${(mrrCents / 100).toStringAsFixed(0)}' : '—';
    final suspended = '${s['suspended_pharmacies'] ?? '—'}';
    final reg7 = '${s['new_registrations_7d'] ?? '—'}';
    final audit24 = '${s['platform_actions_24h'] ?? '—'}';
    final dau = '${s['daily_active_users_est'] ?? '—'}';
    final salesVol = '${s['sales_transactions_30d'] ?? '—'}';
    final syncScore = (s['sync_health_score'] as num?)?.toInt();
    final notifPct = (s['notification_delivery_pct'] as num?)?.toInt();
    final syncLabel = syncScore != null ? '$syncScore%' : '—';
    final pushLabel = notifPct != null ? '$notifPct%' : '—';

    final expiring = rows.where((r) {
      final d = r['remaining_days'];
      if (d is! num) return false;
      return d >= 0 && d <= 14;
    }).toList();

    final recent = [...rows]..sort((a, b) {
        final ta = a['created_at']?.toString() ?? '';
        final tb = b['created_at']?.toString() ?? '';
        return tb.compareTo(ta);
      });

    return KpmsPlatformAdminShell(
      title: 'Super Admin',
      subtitle: AppConstants.appFullName,
      actions: [
        IconButton(
          tooltip: 'Refresh',
          onPressed: () {
            ref.invalidate(superAdminDashboardStatsProvider);
            ref.invalidate(superAdminPharmaciesProvider);
          },
          icon: const Icon(Icons.refresh_rounded),
        ),
      ],
      body: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(0, 16, 0, 8),
            sliver: SliverToBoxAdapter(
              child: GlassCard(
                padding: const EdgeInsets.all(22),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Platform overview', style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                          const SizedBox(height: 6),
                          Text(
                            'Figures refresh from Supabase operator RPCs. Use Pharmacies for full directory and actions.',
                            style: textTheme.bodySmall?.copyWith(color: theme.hintColor, height: 1.45),
                          ),
                          if (stats.hasError || pharms.hasError) ...[
                            const SizedBox(height: 8),
                            Text(
                              '${stats.error ?? pharms.error}',
                              style: textTheme.bodySmall?.copyWith(color: theme.colorScheme.error),
                            ),
                          ],
                        ],
                      ),
                    ),
                    Icon(Icons.admin_panel_settings_outlined, size: 44, color: theme.colorScheme.primary),
                  ],
                ),
              ),
            ),
          ),
          SliverLayoutBuilder(
            builder: (context, constraints) {
              final w = constraints.crossAxisExtent;
              final cols = w >= 1100 ? 4 : w >= 760 ? 3 : 2;
              return SliverGrid(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: cols,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: w >= 1100 ? 1.42 : 1.28,
                ),
                delegate: SliverChildListDelegate.fixed([
                  _Metric(icon: Icons.apartment_outlined, label: 'Total pharmacies', value: total, color: AppColors.primary),
                  _Metric(icon: Icons.storefront_outlined, label: 'Active pharmacies', value: activePh, color: AppColors.secondary),
                  _Metric(icon: Icons.subscriptions_outlined, label: 'Active subscriptions', value: activeSub, color: AppColors.tertiary),
                  _Metric(icon: Icons.point_of_sale_outlined, label: 'Est. MRR (plans)', value: mrr, color: AppColors.secondary),
                  _Metric(icon: Icons.payments_outlined, label: 'Suspended', value: suspended, color: AppColors.primaryDark),
                  _Metric(icon: Icons.groups_outlined, label: 'Daily active users', value: dau, color: AppColors.navyMid),
                  _Metric(icon: Icons.show_chart_outlined, label: 'Sales (30d txns)', value: salesVol, color: AppColors.tertiary),
                  _Metric(icon: Icons.sync_outlined, label: 'Sync health (score)', value: syncLabel, color: AppColors.primary),
                  _Metric(icon: Icons.notifications_active_outlined, label: 'Push delivery', value: pushLabel, color: AppColors.neutral),
                  _Metric(icon: Icons.person_add_alt_1_outlined, label: 'New tenants (7d)', value: reg7, color: AppColors.navyMid),
                  _Metric(icon: Icons.event_busy_outlined, label: 'Expiring ≤14d', value: '${expiring.length}', color: const Color(0xFFF59E0B)),
                  _Metric(icon: Icons.history_edu_outlined, label: 'Platform audit (24h)', value: audit24, color: AppColors.neutral),
                ]),
              );
            },
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(0, 20, 0, 10),
            sliver: SliverToBoxAdapter(
              child: Text('Analytics', style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
            ),
          ),
          SliverLayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.crossAxisExtent >= 900;
              final chart = _PlatformRevenueChartCard(theme: theme, trend: revenueTrend);
              final health = _PlatformGrowthTrendChartCard(theme: theme, trend: growthTrend);
              if (wide) {
                return SliverToBoxAdapter(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 3, child: chart),
                      const SizedBox(width: 12),
                      Expanded(flex: 2, child: health),
                    ],
                  ),
                );
              }
              return SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    chart,
                    const SizedBox(height: 12),
                    health,
                  ],
                ),
              );
            },
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(0, 18, 0, 8),
            sliver: SliverToBoxAdapter(
              child: Text('Top pharmacies by activity', style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
            ),
          ),
          SliverToBoxAdapter(
            child: topByActivity.isEmpty
                ? Card(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                      child: Text(
                        'No sales activity in the last 30 days yet.',
                        style: theme.textTheme.bodyMedium?.copyWith(color: theme.hintColor, height: 1.45),
                      ),
                    ),
                  )
                : Card(
                    child: Column(
                      children: [
                        for (final r in topByActivity.take(10))
                          ListTile(
                            title: Text(r['pharmacy_name']?.toString() ?? '—'),
                            subtitle: Text('${r['sales_30d'] ?? 0} sales (30d)'),
                            trailing: const Icon(Icons.chevron_right_rounded),
                            onTap: () {
                              final id = r['tenant_id']?.toString();
                              if (id != null) context.push(AppRoutes.superAdminPharmacyDetail(id));
                            },
                          ),
                      ],
                    ),
                  ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(0, 22, 0, 10),
            sliver: SliverToBoxAdapter(
              child: Text('Operate platform', style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
            ),
          ),
          SliverToBoxAdapter(
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _AdminShortcut(icon: Icons.insights_outlined, label: 'Revenue', route: AppRoutes.superAdminRevenue),
                _AdminShortcut(icon: Icons.storefront_outlined, label: 'Pharmacies', route: AppRoutes.superAdminPharmacies),
                _AdminShortcut(icon: Icons.price_change_outlined, label: 'Plans', route: AppRoutes.superAdminPlans),
                _AdminShortcut(icon: Icons.verified_user_outlined, label: 'Approvals', route: AppRoutes.superAdminApprovals),
                _AdminShortcut(icon: Icons.groups_2_outlined, label: 'Users', route: AppRoutes.superAdminUsers),
                _AdminShortcut(icon: Icons.support_agent_outlined, label: 'Support', route: AppRoutes.superAdminSupport),
                _AdminShortcut(icon: Icons.campaign_outlined, label: 'Announce', route: AppRoutes.superAdminAnnouncements),
                _AdminShortcut(icon: Icons.history_edu_outlined, label: 'Audit', route: AppRoutes.superAdminAudit),
                _AdminShortcut(icon: Icons.devices_other_outlined, label: 'Sessions', route: AppRoutes.superAdminSessions),
                _AdminShortcut(icon: Icons.monitor_heart_outlined, label: 'Monitoring', route: AppRoutes.superAdminMonitoring),
                _AdminShortcut(icon: Icons.tune_outlined, label: 'Global settings', route: AppRoutes.superAdminGlobalSettings),
              ],
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(0, 24, 0, 8),
            sliver: SliverToBoxAdapter(
              child: Text('Recent registrations', style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
            ),
          ),
          SliverToBoxAdapter(
            child: pharms.isLoading
                ? const Card(child: Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator())))
                : recent.isEmpty
                    ? Card(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                          child: Text(
                            'No pharmacies loaded yet.',
                            style: theme.textTheme.bodyMedium?.copyWith(color: theme.hintColor, height: 1.45),
                          ),
                        ),
                      )
                    : Card(
                        child: Column(
                          children: [
                            for (var i = 0; i < recent.length && i < 8; i++)
                              ListTile(
                                title: Text(recent[i]['pharmacy_name']?.toString() ?? '—'),
                                subtitle: Text(
                                  '${recent[i]['plan_name'] ?? ''} · ${recent[i]['operational_status'] ?? ''}\n${recent[i]['created_at'] ?? ''}',
                                ),
                                isThreeLine: true,
                                trailing: const Icon(Icons.chevron_right_rounded),
                                onTap: () {
                                  final id = recent[i]['tenant_id']?.toString();
                                  if (id != null) context.push(AppRoutes.superAdminPharmacyDetail(id));
                                },
                              ),
                          ],
                        ),
                      ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(0, 16, 0, 8),
            sliver: SliverToBoxAdapter(
              child: Text('Expiring subscriptions', style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
            ),
          ),
          SliverToBoxAdapter(
            child: expiring.isEmpty
                ? Card(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                      child: Text(
                        'No subscriptions expiring in the next 14 days.',
                        style: theme.textTheme.bodyMedium?.copyWith(color: theme.hintColor, height: 1.45),
                      ),
                    ),
                  )
                : Card(
                    child: Column(
                      children: [
                        for (final r in expiring.take(10))
                          ListTile(
                            title: Text(r['pharmacy_name']?.toString() ?? '—'),
                            subtitle: Text('${r['remaining_days'] ?? ''} days · ${r['expires_at'] ?? ''}'),
                            trailing: const Icon(Icons.chevron_right_rounded),
                            onTap: () {
                              final id = r['tenant_id']?.toString();
                              if (id != null) context.push(AppRoutes.superAdminPharmacyDetail(id));
                            },
                          ),
                      ],
                    ),
                  ),
          ),
          SliverPadding(
            padding: KpmsBreakpoints.pageScrollPadding(context).copyWith(top: 16),
            sliver: SliverToBoxAdapter(
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                  child: Text(
                    'Operator actions are recorded in the audit log. Only platform super admins may call management RPCs.',
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor, height: 1.45),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlatformRevenueChartCard extends StatelessWidget {
  const _PlatformRevenueChartCard({required this.theme, required this.trend});

  final ThemeData theme;
  final List<Map<String, dynamic>> trend;

  @override
  Widget build(BuildContext context) {
    final spots = <FlSpot>[];
    var maxUsd = 0.0;
    for (var i = 0; i < trend.length; i++) {
      final cents = (trend[i]['cents'] as num?)?.toDouble() ?? 0;
      final usd = cents / 100;
      if (usd > maxUsd) maxUsd = usd;
      spots.add(FlSpot(i.toDouble(), usd));
    }
    final n = trend.length;
    final maxX = n <= 1 ? 1.0 : (n - 1).toDouble();
    final maxY = maxUsd <= 0 ? 1.0 : maxUsd * 1.12;

    if (trend.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          child: SizedBox(
            height: 220,
            child: Center(
              child: Text(
                'No revenue trend data yet.',
                style: theme.textTheme.bodyMedium?.copyWith(color: theme.hintColor),
              ),
            ),
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Revenue trend', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text('Monthly billing events (USD)', style: theme.textTheme.labelSmall?.copyWith(color: theme.hintColor)),
            const SizedBox(height: 12),
            SizedBox(
              height: 220,
              child: LineChart(
                LineChartData(
                  minX: 0,
                  maxX: maxX,
                  minY: 0,
                  maxY: maxY,
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: maxY > 0 ? (maxY / 4).clamp(1, 1e9) : 1,
                    getDrawingHorizontalLine: (v) => FlLine(
                      color: theme.colorScheme.outline.withValues(alpha: 0.15),
                      strokeWidth: 1,
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 36,
                        interval: maxY > 0 ? (maxY / 4).clamp(1, 1e9) : 1,
                        getTitlesWidget: (v, meta) => SideTitleWidget(
                          meta: meta,
                          child: Text(
                            v >= 1000 ? '${(v / 1000).toStringAsFixed(1)}k' : v.toStringAsFixed(0),
                            style: theme.textTheme.labelSmall?.copyWith(color: theme.hintColor),
                          ),
                        ),
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 22,
                        interval: 1,
                        getTitlesWidget: (v, meta) {
                          final i = v.round().clamp(0, n - 1);
                          final m = trend[i]['month']?.toString();
                          return SideTitleWidget(
                            meta: meta,
                            child: Text(
                              _shortMonthLabel(m),
                              style: theme.textTheme.labelSmall?.copyWith(color: theme.hintColor),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  lineBarsData: [
                    LineChartBarData(
                      isCurved: true,
                      color: AppColors.primary,
                      barWidth: 3,
                      dotData: FlDotData(
                        show: true,
                        getDotPainter: (spot, percent, bar, ix) => FlDotCirclePainter(
                          radius: 3,
                          color: AppColors.primary,
                          strokeWidth: 0,
                        ),
                      ),
                      belowBarData: BarAreaData(
                        show: true,
                        color: AppColors.primary.withValues(alpha: 0.12),
                      ),
                      spots: spots,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlatformGrowthTrendChartCard extends StatelessWidget {
  const _PlatformGrowthTrendChartCard({required this.theme, required this.trend});

  final ThemeData theme;
  final List<Map<String, dynamic>> trend;

  @override
  Widget build(BuildContext context) {
    final spots = <FlSpot>[];
    var maxN = 0.0;
    for (var i = 0; i < trend.length; i++) {
      final nv = (trend[i]['new_tenants'] as num?)?.toDouble() ?? 0;
      if (nv > maxN) maxN = nv;
      spots.add(FlSpot(i.toDouble(), nv));
    }
    final n = trend.length;
    final maxX = n <= 1 ? 1.0 : (n - 1).toDouble();
    final maxY = maxN <= 0 ? 1.0 : maxN * 1.15;

    if (trend.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          child: SizedBox(
            height: 220,
            child: Center(
              child: Text(
                'No tenant growth series yet.',
                style: theme.textTheme.bodyMedium?.copyWith(color: theme.hintColor),
              ),
            ),
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Tenant growth', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text('New pharmacies per month', style: theme.textTheme.labelSmall?.copyWith(color: theme.hintColor)),
            const SizedBox(height: 12),
            SizedBox(
              height: 220,
              child: LineChart(
                LineChartData(
                  minX: 0,
                  maxX: maxX,
                  minY: 0,
                  maxY: maxY,
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: maxY > 0 ? (maxY / 4).clamp(1, 1e9) : 1,
                    getDrawingHorizontalLine: (v) => FlLine(
                      color: theme.colorScheme.outline.withValues(alpha: 0.12),
                      strokeWidth: 1,
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 28,
                        interval: maxY > 0 ? (maxY / 4).clamp(1, 1e9) : 1,
                        getTitlesWidget: (v, meta) => SideTitleWidget(
                          meta: meta,
                          child: Text(
                            v.toInt().toString(),
                            style: theme.textTheme.labelSmall?.copyWith(color: theme.hintColor),
                          ),
                        ),
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 22,
                        interval: 1,
                        getTitlesWidget: (v, meta) {
                          final i = v.round().clamp(0, n - 1);
                          final m = trend[i]['month']?.toString();
                          return SideTitleWidget(
                            meta: meta,
                            child: Text(
                              _shortMonthLabel(m),
                              style: theme.textTheme.labelSmall?.copyWith(color: theme.hintColor),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  lineBarsData: [
                    LineChartBarData(
                      isCurved: true,
                      color: AppColors.tertiary,
                      barWidth: 2.5,
                      dotData: const FlDotData(show: false),
                      spots: spots,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AdminShortcut extends StatelessWidget {
  const _AdminShortcut({
    required this.icon,
    required this.label,
    required this.route,
  });

  final IconData icon;
  final String label;
  final String route;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: 168,
      child: Material(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => context.push(route),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
            child: Row(
              children: [
                Icon(icon, color: theme.colorScheme.primary),
                const SizedBox(width: 10),
                Expanded(child: Text(label, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700))),
                const Icon(Icons.chevron_right_rounded, size: 18),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color),
            const SizedBox(height: 12),
            Text(label, style: theme.textTheme.labelMedium?.copyWith(color: theme.hintColor)),
            const SizedBox(height: 4),
            Text(value, style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900)),
          ],
        ),
      ),
    );
  }
}
