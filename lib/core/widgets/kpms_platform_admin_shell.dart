import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/app_constants.dart';
import '../constants/app_prefs_keys.dart';
import '../constants/app_routes.dart';
import '../auth/kpms_permission_gate.dart';
import '../navigation/kpms_breakpoints.dart';
import '../navigation/kpms_destinations.dart';
import '../theme/app_colors.dart';
import '../../features/auth/application/auth_providers.dart';
import '../../l10n/app_localizations.dart';
import '../../l10n/kpms_nav_l10n.dart';
import '../../providers/theme_provider.dart';

/// Web-style SaaS shell for **platform super admins only**: persistent sidebar (wide)
/// or drawer (narrow), module search, no pharmacy bottom navigation.
class KpmsPlatformAdminShell extends ConsumerStatefulWidget {
  const KpmsPlatformAdminShell({
    super.key,
    required this.body,
    this.title,
    this.subtitle,
    this.actions = const [],
    this.floatingActionButton,
    this.contentMaxWidth = 1240,
  });

  final Widget body;
  final String? title;
  final String? subtitle;
  final List<Widget> actions;
  final Widget? floatingActionButton;
  final double contentMaxWidth;

  @override
  ConsumerState<KpmsPlatformAdminShell> createState() => _KpmsPlatformAdminShellState();
}

class _KpmsPlatformAdminShellState extends ConsumerState<KpmsPlatformAdminShell> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  bool _sidebarCollapsed = false;
  bool _prefsLoaded = false;

  static const double _railBreakpoint = 960;
  static const double _railExpanded = 232;
  static const double _railCollapsed = 76;

  @override
  void initState() {
    super.initState();
    _loadSidebarPref();
  }

  Future<void> _loadSidebarPref() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _sidebarCollapsed = prefs.getBool(AppPrefsKeys.platformSidebarCollapsed) ?? false;
      _prefsLoaded = true;
    });
  }

  Future<void> _setCollapsed(bool value) async {
    setState(() => _sidebarCollapsed = value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(AppPrefsKeys.platformSidebarCollapsed, value);
  }

  Future<void> _openModuleSearch() async {
    final picked = await showSearch<KpmsDestination?>(
      context: context,
      delegate: _KpmsPlatformModuleSearchDelegate(
        destinations: kpmsPlatformDestinations,
        l10n: AppLocalizations.of(context),
      ),
    );
    if (!mounted || picked == null) return;
    context.go(picked.route);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final width = MediaQuery.sizeOf(context).width;
    final useRail = width >= _railBreakpoint;
    final borderColor = theme.colorScheme.outline.withValues(alpha: theme.brightness == Brightness.dark ? 0.22 : 0.38);

    final location = GoRouterState.of(context).uri.path;

    final sidebar = _PlatformSidebar(
      expanded: !_sidebarCollapsed,
      currentPath: location,
      onSelect: (route) {
        context.go(route);
        if (!useRail) Navigator.of(context).pop();
      },
      onToggleCollapse: useRail && _prefsLoaded ? () => _setCollapsed(!_sidebarCollapsed) : null,
    );

    return Scaffold(
      key: _scaffoldKey,
      floatingActionButton: widget.floatingActionButton,
      drawer: useRail
          ? null
          : Drawer(
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.horizontal(right: Radius.circular(20)),
              ),
              child: SafeArea(child: sidebar),
            ),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (useRail)
            SafeArea(
              right: false,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 280),
                curve: Curves.easeOutCubic,
                width: _sidebarCollapsed ? _railCollapsed : _railExpanded,
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerLow,
                  border: Border(right: BorderSide(color: borderColor)),
                ),
                child: ClipRect(child: sidebar),
              ),
            ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _PlatformStickyHeader(
                  useRail: useRail,
                  onMenu: () => _scaffoldKey.currentState?.openDrawer(),
                  onSearchTap: _openModuleSearch,
                ),
                if (widget.title != null || widget.actions.isNotEmpty)
                  _PlatformPageHeading(
                    title: widget.title,
                    subtitle: widget.subtitle,
                    actions: widget.actions,
                  ),
                Expanded(
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: widget.contentMaxWidth),
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(
                          KpmsBreakpoints.pagePaddingHorizontal(width),
                          8,
                          KpmsBreakpoints.pagePaddingHorizontal(width),
                          16,
                        ),
                        child: widget.body,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PlatformPageHeading extends StatelessWidget {
  const _PlatformPageHeading({
    required this.title,
    required this.subtitle,
    required this.actions,
  });

  final String? title;
  final String? subtitle;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (title == null && actions.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 8, 0, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null)
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title!,
                    style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.3),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      subtitle!,
                      style: theme.textTheme.labelMedium?.copyWith(color: theme.hintColor, fontWeight: FontWeight.w600),
                    ),
                  ],
                ],
              ),
            )
          else
            const Spacer(),
          ...actions,
        ],
      ),
    );
  }
}

class _PlatformStickyHeader extends ConsumerWidget {
  const _PlatformStickyHeader({
    required this.useRail,
    required this.onMenu,
    required this.onSearchTap,
  });

  final bool useRail;
  final VoidCallback? onMenu;
  final VoidCallback onSearchTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final bottom = BorderSide(color: scheme.outline.withValues(alpha: theme.brightness == Brightness.dark ? 0.2 : 0.35));
    final shadow = theme.brightness == Brightness.dark
        ? <BoxShadow>[BoxShadow(color: Colors.black.withValues(alpha: 0.35), blurRadius: 18, offset: const Offset(0, 4))]
        : <BoxShadow>[BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 20, offset: const Offset(0, 4))];

    return Material(
      color: scheme.surface,
      elevation: 0,
      shadowColor: Colors.transparent,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: scheme.surface,
          border: Border(bottom: bottom),
          boxShadow: shadow,
        ),
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 6, 10, 8),
            child: LayoutBuilder(
              builder: (context, c) {
                final narrow = c.maxWidth < 560;
                return Row(
                  children: [
                    if (!useRail)
                      IconButton(
                        tooltip: 'Navigation',
                        onPressed: onMenu,
                        icon: const Icon(Icons.menu_rounded),
                      ),
                    if (!narrow) ...[
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 260),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              AppConstants.appName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.2),
                            ),
                            Text(
                              'Platform admin',
                              style: theme.textTheme.labelSmall?.copyWith(color: theme.hintColor, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Material(
                          color: scheme.surfaceContainerHighest.withValues(alpha: 0.55),
                          borderRadius: BorderRadius.circular(14),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(14),
                            onTap: onSearchTap,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              child: Row(
                                children: [
                                  Icon(Icons.search_rounded, size: 22, color: theme.hintColor),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      narrow ? 'Search…' : 'Search platform sections…',
                                      style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor, fontWeight: FontWeight.w500),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(left: 6),
                      child: _RoleChip(label: 'Super Admin'),
                    ),
                    IconButton(
                      tooltip: 'Toggle theme',
                      onPressed: () {
                        final isDark = Theme.of(context).brightness == Brightness.dark;
                        ref.read(themeModeProvider.notifier).setTheme(isDark ? ThemeMode.light : ThemeMode.dark);
                      },
                      icon: Icon(Theme.of(context).brightness == Brightness.dark ? Icons.light_mode_outlined : Icons.dark_mode_outlined),
                    ),
                    PopupMenuButton<String>(
                      tooltip: 'Account',
                      offset: const Offset(0, 40),
                      itemBuilder: (ctx) => const [
                        PopupMenuItem(
                          value: 'logout',
                          child: ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(Icons.logout_rounded),
                            title: Text('Sign out'),
                          ),
                        ),
                      ],
                      onSelected: (value) async {
                        if (value == 'logout') {
                          await ref.read(authRepositoryProvider).signOut();
                          KpmsPermissionGate.invalidate();
                          if (!context.mounted) return;
                          context.go(AppRoutes.superAdminLogin);
                        }
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: CircleAvatar(
                          radius: 18,
                          backgroundColor: AppColors.primary.withValues(alpha: 0.14),
                          child: Icon(Icons.admin_panel_settings_rounded, color: AppColors.primary, size: 22),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _RoleChip extends StatelessWidget {
  const _RoleChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.35)),
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w700, letterSpacing: 0.2),
      ),
    );
  }
}

class _PlatformSidebar extends StatelessWidget {
  const _PlatformSidebar({
    required this.expanded,
    required this.currentPath,
    required this.onSelect,
    required this.onToggleCollapse,
  });

  final bool expanded;
  final String currentPath;
  final ValueChanged<String> onSelect;
  final VoidCallback? onToggleCollapse;

  bool _isActive(String route) {
    if (route == AppRoutes.superAdmin) {
      return currentPath == AppRoutes.superAdmin || currentPath == '${AppRoutes.superAdmin}/';
    }
    return currentPath.startsWith(route);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = AppColors.primary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(expanded ? 16 : 10, 16, expanded ? 12 : 10, 12),
          child: Row(
            children: [
              if (expanded)
                Expanded(
                  child: Text(
                    AppConstants.appName,
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900, letterSpacing: -0.5),
                  ),
                )
              else
                Icon(Icons.admin_panel_settings_rounded, color: primary, size: 28),
              if (onToggleCollapse != null)
                IconButton(
                  tooltip: expanded ? 'Collapse' : 'Expand',
                  onPressed: onToggleCollapse,
                  icon: AnimatedRotation(
                    turns: expanded ? 0 : 0.5,
                    duration: const Duration(milliseconds: 220),
                    child: Icon(expanded ? Icons.chevron_left_rounded : Icons.chevron_right_rounded),
                  ),
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Text(
            'Platform',
            style: theme.textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: theme.colorScheme.secondary,
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
            itemCount: kpmsPlatformDestinations.length,
            itemBuilder: (context, i) {
              final d = kpmsPlatformDestinations[i];
              final active = _isActive(d.route);
              return Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: _SidebarTile(
                  expanded: expanded,
                  destination: d,
                  active: active,
                  onTap: () => onSelect(d.route),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _SidebarTile extends StatefulWidget {
  const _SidebarTile({
    required this.expanded,
    required this.destination,
    required this.active,
    required this.onTap,
  });

  final bool expanded;
  final KpmsDestination destination;
  final bool active;
  final VoidCallback onTap;

  @override
  State<_SidebarTile> createState() => _SidebarTileState();
}

class _SidebarTileState extends State<_SidebarTile> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l = AppLocalizations.of(context);
    final title = widget.destination.navId.title(l);
    final primary = AppColors.primary;
    final bg = widget.active
        ? primary.withValues(alpha: 0.14)
        : _hover
            ? theme.colorScheme.onSurface.withValues(alpha: 0.05)
            : Colors.transparent;
    final fg = widget.active ? primary : theme.colorScheme.onSurface.withValues(alpha: 0.82);

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: widget.onTap,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: widget.expanded ? 12 : 0, vertical: 10),
            child: widget.expanded
                ? Row(
                    children: [
                      Icon(widget.destination.icon, size: 22, color: fg),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelLarge?.copyWith(
                            fontWeight: widget.active ? FontWeight.w800 : FontWeight.w600,
                            color: fg,
                          ),
                        ),
                      ),
                    ],
                  )
                : Tooltip(
                    message: title,
                    child: Center(child: Icon(widget.destination.icon, size: 22, color: fg)),
                  ),
          ),
        ),
      ),
    );
  }
}

class _KpmsPlatformModuleSearchDelegate extends SearchDelegate<KpmsDestination?> {
  _KpmsPlatformModuleSearchDelegate({required this.destinations, required this.l10n});

  final List<KpmsDestination> destinations;
  final AppLocalizations l10n;

  @override
  String get searchFieldLabel => l10n.platformSearchModules;

  @override
  List<Widget>? buildActions(BuildContext context) {
    if (query.isEmpty) return null;
    return [
      IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => query = ''),
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(icon: const Icon(Icons.arrow_back_rounded), onPressed: () => close(context, null));
  }

  List<KpmsDestination> _filtered() {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return destinations;
    return destinations
        .where(
          (d) =>
              d.navId.title(l10n).toLowerCase().contains(q) ||
              d.navId.subtitle(l10n).toLowerCase().contains(q) ||
              d.route.toLowerCase().contains(q),
        )
        .toList(growable: false);
  }

  @override
  Widget buildResults(BuildContext context) => _list(context);

  @override
  Widget buildSuggestions(BuildContext context) => _list(context);

  Widget _list(BuildContext context) {
    final theme = Theme.of(context);
    final rows = _filtered();
    if (rows.isEmpty) {
      return Center(child: Text(l10n.platformSearchNoMatches, style: theme.textTheme.bodyMedium?.copyWith(color: theme.hintColor)));
    }
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: rows.length,
      separatorBuilder: (context, index) => const Divider(height: 1),
      itemBuilder: (context, i) {
        final d = rows[i];
        return ListTile(
          leading: Icon(d.icon, color: AppColors.primary),
          title: Text(d.navId.title(l10n), style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
          subtitle: Text(d.navId.subtitle(l10n), style: theme.textTheme.bodySmall),
          onTap: () => close(context, d),
        );
      },
    );
  }
}
