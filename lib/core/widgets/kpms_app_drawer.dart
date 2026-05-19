import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/application/auth_providers.dart';
import '../../providers/pharmacy_local_workspace.dart';
import '../../l10n/app_localizations.dart';
import '../../l10n/kpms_nav_l10n.dart';
import '../auth/kpms_permission_gate.dart';
import '../auth/permission_providers.dart';
import '../constants/app_constants.dart';
import '../constants/app_routes.dart';
import '../navigation/kpms_destinations.dart';
import '../theme/app_colors.dart';

/// Full app map — pharmacy items respect RBAC; platform block only for super admins.
class KpmsAppDrawer extends ConsumerWidget {
  const KpmsAppDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l = AppLocalizations.of(context);
    final location = GoRouterState.of(context).uri.path;
    final permAsync = ref.watch(kpmsPermissionContextProvider);

    void go(String route) {
      Navigator.of(context).maybePop();
      context.go(route);
    }

    Future<void> signOut() async {
      Navigator.of(context).maybePop();
      await flushPharmacyWorkspacePersistence(ref, reason: 'sign_out');
      KpmsPermissionGate.invalidate();
      await ref.read(authRepositoryProvider).signOut();
      if (context.mounted) context.go(AppRoutes.login);
    }

    return Drawer(
      child: SafeArea(
        child: permAsync.when(
          loading: () => const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator())),
          error: (e, _) => ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Text(l.commonRetry, style: theme.textTheme.titleMedium),
              const SizedBox(height: 12),
              FilledButton(onPressed: () => ref.invalidate(kpmsPermissionContextProvider), child: Text(l.commonRetry)),
            ],
          ),
          data: (perm) {
            final pharmacy = visiblePharmacyDestinations(perm);
            final showPlatform = perm.isPlatformSuperAdmin;

            return ListView(
              padding: const EdgeInsets.only(bottom: 24),
              children: [
                DrawerHeader(
                  margin: EdgeInsets.zero,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        AppColors.brandNavy,
                        AppColors.navyMid,
                        AppColors.primary.withValues(alpha: 0.42),
                      ],
                      stops: const [0.0, 0.65, 1.0],
                    ),
                  ),
                  child: Align(
                    alignment: Alignment.bottomLeft,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          AppConstants.appName,
                          style: theme.textTheme.headlineSmall?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Text(
                          l.drawerAllModulesTagline,
                          style: theme.textTheme.bodySmall?.copyWith(color: Colors.white.withValues(alpha: 0.88)),
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
                  child: Text(
                    l.drawerPharmacySection,
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
                ...pharmacy.map((d) {
                  final selected = location == d.route;
                  return ListTile(
                    leading: Icon(d.icon, color: selected ? theme.colorScheme.primary : null),
                    title: Text(d.navId.title(l)),
                    subtitle: Text(d.navId.subtitle(l), maxLines: 1, overflow: TextOverflow.ellipsis),
                    selected: selected,
                    onTap: () => go(d.route),
                  );
                }),
                if (showPlatform) ...[
                  const Divider(height: 32),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
                    child: Text(
                      l.drawerPlatformSection,
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: theme.colorScheme.secondary,
                      ),
                    ),
                  ),
                  ...kpmsPlatformDestinations.map((d) {
                    final selected = location == d.route;
                    return ListTile(
                      leading: Icon(d.icon, color: selected ? theme.colorScheme.secondary : null),
                      title: Text(d.navId.title(l)),
                      subtitle: Text(d.navId.subtitle(l), maxLines: 1, overflow: TextOverflow.ellipsis),
                      selected: selected,
                      onTap: () => go(d.route),
                    );
                  }),
                ],
                const Divider(height: 24),
                ListTile(
                  leading: const Icon(Icons.logout_rounded),
                  title: Text(l.authSignOut),
                  onTap: signOut,
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
