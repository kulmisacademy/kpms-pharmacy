import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/navigation/kpms_breakpoints.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/kpms_feedback.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/kpms_page_shell.dart';
import '../application/tenant_subscription_providers.dart';

/// Tenant subscription overview backed by `subscriptions` + `subscription_plans`.
class SubscriptionsScreen extends ConsumerWidget {
  const SubscriptionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final mine = ref.watch(myTenantSubscriptionProvider);
    final catalog = ref.watch(subscriptionCatalogPlansProvider);

    final planRow = mine.valueOrNull?['plan_row'] is Map ? Map<String, dynamic>.from(mine.valueOrNull!['plan_row'] as Map) : null;
    final planLabel = planRow?['name']?.toString() ?? mine.valueOrNull?['plan']?.toString() ?? '—';
    final status = mine.valueOrNull?['status']?.toString() ?? '—';
    final expires = mine.valueOrNull?['expires_at']?.toString() ?? '—';
    final payment = mine.valueOrNull?['payment_status']?.toString() ?? '—';

    return KpmsPageShell(
      title: 'Subscription',
      subtitle: 'Plan · billing',
      body: ListView(
        padding: KpmsBreakpoints.pageScrollPadding(context),
        children: [
          GlassCard(
            padding: const EdgeInsets.all(20),
            child: mine.when(
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text('Could not load subscription: $e'),
              data: (row) {
                if (row == null) {
                  return const Text('No subscription row linked to your pharmacy yet.');
                }
                return Row(
                  children: [
                    Icon(Icons.verified_outlined, color: theme.colorScheme.primary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Current plan', style: theme.textTheme.labelSmall?.copyWith(color: theme.hintColor)),
                          Text('$planLabel · $status', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                          const SizedBox(height: 6),
                          Text('Expires: $expires', style: theme.textTheme.bodySmall),
                          Text('Payment: $payment', style: theme.textTheme.bodySmall),
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: () => kpmsSnack(context, 'Billing history when payment provider is connected.'),
                      child: const Text('Invoices'),
                    ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 20),
          Text('Catalog', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          catalog.when(
            loading: () => const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator())),
            error: (e, _) => Text('Plans: $e'),
            data: (plans) {
              if (plans.isEmpty) {
                return Text('No public plans configured.', style: theme.textTheme.bodyMedium?.copyWith(color: theme.hintColor));
              }
              return Column(
                children: plans.map((p) {
                  final cents = (p['monthly_price_cents'] as num?)?.toInt() ?? 0;
                  final price = cents == 0 ? 'Free' : '\$${(cents / 100).toStringAsFixed(0)}/mo';
                  final isCurrent = planRow != null && planRow['id']?.toString() == p['id']?.toString();
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Card(
                      elevation: isCurrent ? 2 : 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                        side: BorderSide(
                          color: isCurrent ? AppColors.primary : theme.dividerColor.withValues(alpha: 0.3),
                          width: isCurrent ? 2 : 1,
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    p['name']?.toString() ?? '',
                                    style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                                  ),
                                ),
                                Text(price, style: theme.textTheme.headlineSmall?.copyWith(color: AppColors.tertiary)),
                              ],
                            ),
                            if ((p['description']?.toString() ?? '').isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Text(p['description']?.toString() ?? '', style: theme.textTheme.bodyMedium),
                            ],
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton(
                                onPressed: isCurrent
                                    ? null
                                    : () => kpmsSnack(
                                          context,
                                          'Plan changes are managed by your platform operator. Contact support to upgrade.',
                                        ),
                                child: Text(isCurrent ? 'Current plan' : 'Request change'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}
