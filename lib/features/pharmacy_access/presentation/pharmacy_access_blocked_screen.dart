import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_routes.dart';
import '../../../core/supabase/pharmacy_operational_gate.dart';
import '../../../core/supabase/profile_tenant_gate.dart';
import '../../../core/tenant/pharmacy_workspace_isolation.dart';
import '../../../providers/pharmacy_local_workspace.dart';
import '../../../core/supabase/supabase_bootstrap.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/glass_card.dart';
import '../../auth/application/auth_providers.dart';

/// Full-screen gate when pharmacy workspace is blocked (suspension, expiry, maintenance).
class PharmacyAccessBlockedScreen extends ConsumerWidget {
  const PharmacyAccessBlockedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final client = SupabaseBootstrap.clientOrNull;
    final uid = client?.auth.currentUser?.id;

    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(gradient: AppColors.brandGradient),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: GlassCard(
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Icon(Icons.shield_outlined, size: 52, color: theme.colorScheme.error),
                      const SizedBox(height: 16),
                      Text(
                        'Access paused',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 12),
                      if (uid != null && client != null)
                        FutureBuilder<PharmacyOperationalStatus>(
                          future: PharmacyOperationalGate.resolve(client, uid),
                          builder: (context, snap) {
                            final reason = snap.data?.reason;
                            final headline = reason == 'subscription_expired'
                                ? 'Subscription expired'
                                : reason == 'maintenance'
                                    ? 'Maintenance'
                                    : reason == 'archived'
                                        ? 'Account closed'
                                        : reason == 'subscription_inactive'
                                            ? 'Subscription inactive'
                                            : 'Account suspended';
                            final msg = snap.data?.message ??
                                'Your organization cannot use the pharmacy workspace right now.';
                            return Column(
                              children: [
                                Text(
                                  headline,
                                  textAlign: TextAlign.center,
                                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  msg,
                                  textAlign: TextAlign.center,
                                  style: theme.textTheme.bodyMedium?.copyWith(height: 1.45, color: theme.hintColor),
                                ),
                              ],
                            );
                          },
                        )
                      else
                        Text(
                          'Sign in again to continue.',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium?.copyWith(color: theme.hintColor),
                        ),
                      const SizedBox(height: 28),
                      FilledButton(
                        onPressed: () async {
                          resetTenantSessionCaches(ref, reason: 'access_blocked_sign_out');
                          ref.invalidate(pharmacyWorkspaceBootstrapProvider);
                          await ref.read(authRepositoryProvider).signOut();
                          ProfileTenantGate.invalidate();
                          PharmacyOperationalGate.invalidate();
                          if (!context.mounted) return;
                          context.go(AppRoutes.login);
                        },
                        child: const Text('Sign out'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
