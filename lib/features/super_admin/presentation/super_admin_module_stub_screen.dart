import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/kpms_platform_admin_shell.dart';

/// Placeholder module for SaaS control-plane screens until operator APIs exist.
class SuperAdminModuleStubScreen extends StatelessWidget {
  const SuperAdminModuleStubScreen({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.body,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final String body;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return KpmsPlatformAdminShell(
      title: title,
      subtitle: subtitle,
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(22),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(icon, size: 40, color: AppColors.primary),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Operator console',
                            style: theme.textTheme.labelLarge?.copyWith(
                              color: AppColors.secondary,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.4,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(body, style: theme.textTheme.bodyMedium?.copyWith(height: 1.5)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Server-side enforcement',
              style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              'Expose read/write RPCs and RLS policies restricted to `platform_super_admin` only. '
              'The Flutter shell never mixes pharmacy JWT scopes with platform analytics.',
              style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor, height: 1.45),
            ),
          ],
        ),
      ),
    );
  }
}
