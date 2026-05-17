import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/kpms_permission_context.dart';
import '../../../core/auth/kpms_permission_gate.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/constants/app_routes.dart';
import '../../../core/navigation/kpms_destinations.dart';
import '../../../core/theme/app_colors.dart';
import '../../../features/auth/application/auth_providers.dart';
import '../../../features/notifications/application/pharmacy_notifications_providers.dart';
import '../../../features/settings/application/pharmacy_settings_providers.dart';
import '../../../l10n/app_localizations.dart';
import '../../../l10n/kpms_nav_l10n.dart';
import '../../../providers/theme_provider.dart';
import '../../../core/auth/permission_providers.dart';
import '../../../core/supabase/pharmacy_operational_warning_provider.dart';
import '../../../core/widgets/kpms_all_features_sheet.dart';
import '../../../core/widgets/kpms_content_width.dart';

/// Primary sidebar destinations for enterprise desktop (RBAC-filtered at runtime).
const List<KpmsNavId> kpmsDesktopPrimaryNavIds = [
  KpmsNavId.dashboard,
  KpmsNavId.medicines,
  KpmsNavId.inventory,
  KpmsNavId.pos,
  KpmsNavId.purchases,
  KpmsNavId.reports,
  KpmsNavId.notifications,
  KpmsNavId.staff,
  KpmsNavId.settings,
];

List<KpmsDestination> desktopPrimaryDestinations(KpmsPermissionContext perm) {
  final visible = visiblePharmacyDestinations(perm);
  final byId = {for (final d in visible) d.navId: d};
  return [
    for (final id in kpmsDesktopPrimaryNavIds)
      if (byId.containsKey(id)) byId[id]!,
  ];
}

/// Enterprise desktop shell: fixed left nav, top bar, scrollable content. No bottom navigation.
class DesktopShell extends ConsumerWidget {
  const DesktopShell({
    super.key,
    required this.title,
    this.subtitle,
    required this.body,
    this.actions = const [],
    this.floatingActionButton,
    this.constrainContentWidth = true,
    this.contentMaxWidth = 1280,
  });

  final String title;
  final String? subtitle;
  final Widget body;
  final List<Widget> actions;
  final Widget? floatingActionButton;
  final bool constrainContentWidth;
  final double contentMaxWidth;

  String _workspaceHome(WidgetRef ref) {
    final perm = ref.read(kpmsPermissionContextProvider).valueOrNull;
    return perm?.defaultLandingRoute ?? AppRoutes.home;
  }

  bool _canNotify(WidgetRef ref) {
    final perm = ref.read(kpmsPermissionContextProvider).valueOrNull;
    return perm == null || perm.canAccessLocation(AppRoutes.notifications);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l = AppLocalizations.of(context);
    final location = GoRouterState.of(context).uri.path;
    final permAsync = ref.watch(kpmsPermissionContextProvider);
    final branding = ref.watch(pharmacyBrandingProvider);
    final pharmacyLabel = branding.businessName.trim().isEmpty ? AppConstants.appName : branding.businessName.trim();
    final borderColor = theme.colorScheme.outline.withValues(alpha: theme.brightness == Brightness.dark ? 0.22 : 0.38);

    return Scaffold(
      floatingActionButton: floatingActionButton,
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SafeArea(
            right: false,
            child: Container(
              width: 248,
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerLow,
                border: Border(right: BorderSide(color: borderColor)),
              ),
              child: permAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, _) => Center(
                  child: TextButton(
                    onPressed: () => ref.invalidate(kpmsPermissionContextProvider),
                    child: Text(l.commonRetry),
                  ),
                ),
                data: (perm) {
                  final navItems = desktopPrimaryDestinations(perm);
                  final showPlatform = perm.isPlatformSuperAdmin;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 18, 16, 12),
                        child: Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [AppColors.brandNavy, AppColors.primary.withValues(alpha: 0.85)],
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.local_pharmacy_rounded, color: Colors.white, size: 22),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    AppConstants.appName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900),
                                  ),
                                  Text(
                                    pharmacyLabel,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: theme.hintColor,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: ListView(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          children: [
                            for (final d in navItems)
                              _DesktopNavTile(
                                destination: d,
                                selected: _routeSelected(location, d.route),
                                onTap: () => context.go(d.route),
                              ),
                            if (showPlatform) ...[
                              const SizedBox(height: 12),
                              Padding(
                                padding: const EdgeInsets.fromLTRB(8, 4, 8, 6),
                                child: Text(
                                  l.drawerPlatformSection,
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    color: theme.colorScheme.secondary,
                                  ),
                                ),
                              ),
                              for (final d in kpmsPlatformDestinations)
                                _DesktopNavTile(
                                  destination: d,
                                  selected: location == d.route,
                                  onTap: () => context.go(d.route),
                                  accent: theme.colorScheme.secondary,
                                ),
                            ],
                          ],
                        ),
                      ),
                      const Divider(height: 1),
                      ListTile(
                        dense: true,
                        leading: const Icon(Icons.grid_view_rounded, size: 22),
                        title: Text(l.shellAllModules, style: theme.textTheme.labelLarge),
                        onTap: () => showKpmsAllFeaturesSheet(context),
                        mouseCursor: SystemMouseCursors.click,
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Material(
                  color: theme.colorScheme.surface,
                  elevation: 0,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      border: Border(bottom: BorderSide(color: borderColor)),
                    ),
                    child: SafeArea(
                      bottom: false,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    title,
                                    style: theme.textTheme.titleLarge?.copyWith(
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: -0.3,
                                    ),
                                  ),
                                  if (subtitle != null)
                                    Text(
                                      subtitle!,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: theme.textTheme.labelMedium?.copyWith(
                                        color: theme.hintColor,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            IconButton(
                              tooltip: l.shellHome,
                              onPressed: () => context.go(_workspaceHome(ref)),
                              icon: const Icon(Icons.home_outlined),
                            ),
                            if (_canNotify(ref))
                              Builder(
                                builder: (context) {
                                  final unread = ref.watch(pharmacyNotificationUnreadCountSyncProvider);
                                  final label = unread > 99 ? '99+' : '$unread';
                                  return Badge(
                                    isLabelVisible: unread > 0,
                                    label: Text(label),
                                    child: IconButton(
                                      tooltip: l.shellNotifications,
                                      onPressed: () => context.push(AppRoutes.notifications),
                                      icon: const Icon(Icons.notifications_none_rounded),
                                    ),
                                  );
                                },
                              ),
                            IconButton(
                              tooltip: l.shellAllModules,
                              onPressed: () => showKpmsAllFeaturesSheet(context),
                              icon: const Icon(Icons.grid_view_rounded),
                            ),
                            IconButton(
                              tooltip: Theme.of(context).brightness == Brightness.dark ? 'Light mode' : 'Dark mode',
                              onPressed: () {
                                final isDark = Theme.of(context).brightness == Brightness.dark;
                                ref.read(themeModeProvider.notifier).setTheme(isDark ? ThemeMode.light : ThemeMode.dark);
                              },
                              icon: Icon(
                                Theme.of(context).brightness == Brightness.dark
                                    ? Icons.light_mode_outlined
                                    : Icons.dark_mode_outlined,
                              ),
                            ),
                            PopupMenuButton<String>(
                              tooltip: 'Account',
                              offset: const Offset(0, 40),
                              itemBuilder: (ctx) => [
                                PopupMenuItem(
                                  value: 'profile',
                                  child: ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    leading: const Icon(Icons.person_outline_rounded),
                                    title: Text(l.navProfileTitle),
                                  ),
                                ),
                                PopupMenuItem(
                                  value: 'settings',
                                  child: ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    leading: const Icon(Icons.settings_outlined),
                                    title: Text(l.navSettingsTitle),
                                  ),
                                ),
                                const PopupMenuDivider(),
                                PopupMenuItem(
                                  value: 'logout',
                                  child: ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    leading: const Icon(Icons.logout_rounded),
                                    title: Text(l.authSignOut),
                                  ),
                                ),
                              ],
                              onSelected: (value) async {
                                if (value == 'profile') {
                                  if (context.mounted) context.push(AppRoutes.profile);
                                  return;
                                }
                                if (value == 'settings') {
                                  if (context.mounted) context.push(AppRoutes.settings);
                                  return;
                                }
                                if (value == 'logout') {
                                  KpmsPermissionGate.invalidate();
                                  await ref.read(authRepositoryProvider).signOut();
                                  if (context.mounted) context.go(AppRoutes.login);
                                }
                              },
                              child: CircleAvatar(
                                radius: 18,
                                backgroundColor: AppColors.primary.withValues(alpha: 0.14),
                                child: Icon(Icons.person_rounded, color: AppColors.primary, size: 20),
                              ),
                            ),
                            ...actions,
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                ref.watch(pharmacySubscriptionBannerProvider).when(
                      data: (msg) {
                        if (msg == null || msg.isEmpty) return const SizedBox.shrink();
                        return Material(
                          color: theme.colorScheme.secondaryContainer.withValues(alpha: 0.92),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            child: Row(
                              children: [
                                Icon(Icons.info_outline_rounded, size: 18, color: theme.colorScheme.onSecondaryContainer),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    msg,
                                    style: theme.textTheme.labelMedium?.copyWith(
                                      color: theme.colorScheme.onSecondaryContainer,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                      loading: () => const SizedBox.shrink(),
                      error: (_, _) => const SizedBox.shrink(),
                    ),
                Expanded(
                  child: constrainContentWidth
                      ? KpmsContentWidth(maxWidth: contentMaxWidth, child: body)
                      : body,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  bool _routeSelected(String location, String route) {
    if (location == route) return true;
    if (route == AppRoutes.home && location.startsWith('/app/home')) return true;
    return location.startsWith(route) && route != AppRoutes.home;
  }
}

class _DesktopNavTile extends StatefulWidget {
  const _DesktopNavTile({
    required this.destination,
    required this.selected,
    required this.onTap,
    this.accent,
  });

  final KpmsDestination destination;
  final bool selected;
  final VoidCallback onTap;
  final Color? accent;

  @override
  State<_DesktopNavTile> createState() => _DesktopNavTileState();
}

class _DesktopNavTileState extends State<_DesktopNavTile> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l = AppLocalizations.of(context);
    final accent = widget.accent ?? theme.colorScheme.primary;
    final bg = widget.selected
        ? accent.withValues(alpha: 0.14)
        : _hover
            ? theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.65)
            : Colors.transparent;

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        cursor: SystemMouseCursors.click,
        child: Material(
          color: bg,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: widget.onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  Icon(
                    widget.destination.icon,
                    size: 22,
                    color: widget.selected ? accent : theme.colorScheme.onSurface.withValues(alpha: 0.72),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.destination.navId.title(l),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: widget.selected ? FontWeight.w800 : FontWeight.w600,
                        color: widget.selected ? accent : null,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
