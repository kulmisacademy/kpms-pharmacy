import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/shell/presentation/desktop_shell.dart';
import '../../l10n/app_localizations.dart';
import '../constants/app_routes.dart';
import '../../features/notifications/application/pharmacy_notifications_providers.dart';
import '../auth/permission_providers.dart';
import '../navigation/kpms_breakpoints.dart';
import '../responsive/responsive_helpers.dart';
import '../supabase/pharmacy_operational_warning_provider.dart';
import 'kpms_all_features_sheet.dart';
import 'kpms_app_drawer.dart';
import 'kpms_content_width.dart';
import 'kpms_mobile_bottom_nav.dart';

/// Consistent app bar, back navigation, theme toggle — used across PRD feature screens.
class KpmsPageShell extends ConsumerWidget {
  const KpmsPageShell({
    super.key,
    required this.title,
    this.subtitle,
    required this.body,
    this.floatingActionButton,
    this.actions = const [],
    /// false for full-bleed layouts (e.g. POS split view).
    this.constrainContentWidth = true,
  });

  final String title;
  final String? subtitle;
  final Widget body;
  final Widget? floatingActionButton;
  final List<Widget> actions;
  final bool constrainContentWidth;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isPlatformSuperAdmin = ref.watch(
      kpmsPermissionContextProvider.select((a) => a.valueOrNull?.isPlatformSuperAdmin == true),
    );
    final canNotify = ref.watch(
      kpmsPermissionContextProvider.select(
        (a) => a.valueOrNull?.canAccessLocation(AppRoutes.notifications) ?? true,
      ),
    );
    final workspaceHome = ref.watch(
      kpmsPermissionContextProvider.select(
        (a) => a.valueOrNull?.defaultLandingRoute ?? AppRoutes.home,
      ),
    );

    if (isDesktop(context) && !isPlatformSuperAdmin) {
      return DesktopShell(
        title: title,
        subtitle: subtitle,
        body: body,
        actions: actions,
        floatingActionButton: floatingActionButton,
        constrainContentWidth: constrainContentWidth,
      );
    }

  return _MobileTabletPageShell(
      title: title,
      subtitle: subtitle,
      body: body,
      actions: actions,
      floatingActionButton: floatingActionButton,
      constrainContentWidth: constrainContentWidth,
      workspaceHome: workspaceHome,
      canNotify: canNotify,
      useTabletDrawer: isTablet(context) && !isPlatformSuperAdmin,
    );
  }
}

/// Preserves mobile UI; tablet adds drawer navigation without bottom dock.
class _MobileTabletPageShell extends ConsumerWidget {
  const _MobileTabletPageShell({
    required this.title,
    this.subtitle,
    required this.body,
    required this.actions,
    this.floatingActionButton,
    required this.constrainContentWidth,
    required this.workspaceHome,
    required this.canNotify,
    required this.useTabletDrawer,
  });

  final String title;
  final String? subtitle;
  final Widget body;
  final List<Widget> actions;
  final Widget? floatingActionButton;
  final bool constrainContentWidth;
  final String workspaceHome;
  final bool canNotify;
  final bool useTabletDrawer;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l = AppLocalizations.of(context);
    final width = MediaQuery.sizeOf(context).width;
    final showMobileNav = KpmsMobileBottomNav.showForWidth(width);
    final compact = KpmsBreakpoints.compactToolbar(width);
    final onAppBar = theme.appBarTheme.foregroundColor ?? Colors.white;

    return Scaffold(
      drawer: useTabletDrawer ? const KpmsAppDrawer() : null,
      floatingActionButton: floatingActionButton,
      bottomNavigationBar: showMobileNav ? const KpmsMobileBottomNav() : null,
      appBar: AppBar(
        leading: Builder(
          builder: (scaffoldContext) {
            void openModules() => showKpmsAllFeaturesSheet(scaffoldContext);

            if (useTabletDrawer) {
              return IconButton(
                tooltip: l.shellAllModules,
                icon: const Icon(Icons.menu_rounded),
                onPressed: () => Scaffold.of(scaffoldContext).openDrawer(),
              );
            }

            if (compact) {
              return IconButton(
                tooltip: l.shellAllModules,
                icon: const Icon(Icons.grid_view_rounded),
                onPressed: openModules,
              );
            }
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: l.shellAllModules,
                  icon: const Icon(Icons.grid_view_rounded),
                  onPressed: openModules,
                ),
                IconButton(
                  tooltip: l.shellBack,
                  icon: const Icon(Icons.arrow_back_rounded),
                  onPressed: () {
                    if (context.canPop()) {
                      context.pop();
                    } else {
                      context.go(workspaceHome);
                    }
                  },
                ),
              ],
            );
          },
        ),
        leadingWidth: useTabletDrawer ? 56 : (compact ? 56 : 112),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
                color: onAppBar,
                letterSpacing: -0.2,
              ),
            ),
            if (subtitle != null)
              Text(
                subtitle!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: onAppBar.withValues(alpha: 0.82),
                  fontWeight: FontWeight.w600,
                  height: 1.25,
                ),
              ),
          ],
        ),
        actions: [
          if (compact && context.canPop())
            IconButton(
              tooltip: l.shellBack,
              icon: const Icon(Icons.arrow_back_rounded),
              onPressed: () {
                if (context.canPop()) {
                  context.pop();
                } else {
                  context.go(workspaceHome);
                }
              },
            ),
          if (!compact)
            IconButton(
              tooltip: l.shellHome,
              onPressed: () => context.go(workspaceHome),
              icon: const Icon(Icons.home_outlined),
            ),
          if (canNotify)
            Builder(
              builder: (context) {
                final unread = ref.watch(pharmacyNotificationUnreadCountSyncProvider);
                final label = unread > 99 ? '99+' : '$unread';
                return Badge(
                  backgroundColor: theme.colorScheme.error,
                  textColor: theme.colorScheme.onError,
                  isLabelVisible: unread > 0,
                  label: Text(
                    label,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onError,
                      fontWeight: FontWeight.w800,
                      fontSize: 10,
                    ),
                  ),
                  child: IconButton(
                    tooltip: l.shellNotifications,
                    onPressed: () => context.push(AppRoutes.notifications),
                    icon: const Icon(Icons.notifications_none_rounded),
                  ),
                );
              },
            ),
          if (useTabletDrawer)
            IconButton(
              tooltip: l.shellAllModules,
              icon: const Icon(Icons.grid_view_rounded),
              onPressed: () => showKpmsAllFeaturesSheet(context),
            ),
          ...actions,
        ],
      ),
      body: Padding(
        padding: EdgeInsets.only(bottom: KpmsMobileBottomNav.scrollClearanceBottom(context)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ref.watch(pharmacySubscriptionBannerProvider).when(
                  data: (msg) {
                    if (msg == null || msg.isEmpty) return const SizedBox.shrink();
                    return Material(
                      color: theme.colorScheme.secondaryContainer.withValues(alpha: 0.92),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                                  height: 1.25,
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
              child: constrainContentWidth ? KpmsContentWidth(child: body) : body,
            ),
          ],
        ),
      ),
    );
  }
}
