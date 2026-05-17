import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/navigation/kpms_breakpoints.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/kpms_platform_admin_shell.dart';
import '../application/platform_admin_providers.dart';

/// Revenue view backed by [super_admin_dashboard_stats] MRR estimate.
class SuperAdminRevenueScreen extends ConsumerWidget {
  const SuperAdminRevenueScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(superAdminDashboardStatsProvider);
    final theme = Theme.of(context);
    return KpmsPlatformAdminShell(
      title: 'Revenue',
      subtitle: 'Estimated MRR from plan list',
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh_rounded),
          onPressed: () => ref.invalidate(superAdminDashboardStatsProvider),
        ),
      ],
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (s) {
          final cents = (s['estimated_mrr_cents'] as num?)?.toInt() ?? 0;
          final mrr = (cents / 100).toStringAsFixed(2);
          final active = s['active_subscriptions'] ?? '—';
          return ListView(
            padding: KpmsBreakpoints.pageScrollPadding(context),
            children: [
              GlassCard(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Estimated MRR', style: theme.textTheme.labelMedium?.copyWith(color: theme.hintColor)),
                    Text('\$$mrr', style: theme.textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w900, color: AppColors.primary)),
                    const SizedBox(height: 8),
                    Text(
                      'Sum of active subscription plan prices (monthly) for non-suspended, non-archived pharmacies.',
                      style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor, height: 1.4),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Card(
                child: ListTile(
                  title: const Text('Active paying seats (approx.)'),
                  subtitle: Text('$active subscriptions counted as active'),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
