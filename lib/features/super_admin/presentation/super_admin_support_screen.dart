import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_routes.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/kpms_platform_admin_shell.dart';
import 'widgets/platform_admin_ui.dart';

/// Support hub — links operator tools (announcements, audit, monitoring).
class SuperAdminSupportScreen extends ConsumerWidget {
  const SuperAdminSupportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return KpmsPlatformAdminShell(
      title: 'Support',
      subtitle: 'Moderation and platform communications',
      body: ListView(
        padding: const EdgeInsets.only(bottom: PlatformAdminSpacing.xl),
        children: [
          GlassCard(
            padding: const EdgeInsets.all(PlatformAdminSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Operator tools', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: PlatformAdminSpacing.sm),
                _SupportLink(
                  icon: Icons.campaign_outlined,
                  title: 'Platform announcements',
                  subtitle: 'Broadcast in-app banner to all pharmacy tenants',
                  onTap: () => context.push(AppRoutes.superAdminAnnouncements),
                ),
                _SupportLink(
                  icon: Icons.history_edu_outlined,
                  title: 'Audit log',
                  subtitle: 'Search suspensions, subscription changes, forced logouts',
                  onTap: () => context.push(AppRoutes.superAdminAudit),
                ),
                _SupportLink(
                  icon: Icons.monitor_heart_outlined,
                  title: 'System health',
                  subtitle: 'Realtime, push, and sync signals',
                  onTap: () => context.push(AppRoutes.superAdminMonitoring),
                ),
                _SupportLink(
                  icon: Icons.storefront_outlined,
                  title: 'Pharmacy directory',
                  subtitle: 'Suspend, activate, subscription, force logout',
                  onTap: () => context.push(AppRoutes.superAdminPharmacies),
                ),
              ],
            ),
          ),
          const SizedBox(height: PlatformAdminSpacing.md),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(PlatformAdminSpacing.md),
              child: Text(
                'Dedicated ticketing integrates with your helpdesk later. Use audit + pharmacy actions for production moderation today.',
                style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor, height: 1.45),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SupportLink extends StatelessWidget {
  const _SupportLink({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: PlatformAdminSpacing.sm),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        tileColor: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
        leading: Icon(icon),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: onTap,
      ),
    );
  }
}
