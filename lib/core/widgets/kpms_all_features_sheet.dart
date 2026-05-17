import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/app_localizations.dart';
import '../../l10n/kpms_nav_l10n.dart';
import '../auth/permission_providers.dart';
import '../navigation/kpms_breakpoints.dart';
import '../navigation/kpms_destinations.dart';
import '../responsive/responsive_helpers.dart';
import '../theme/app_colors.dart';
import 'kpms_responsive_dialog.dart';

/// Full hub: pharmacy modules filtered by role; Super Admin section only for platform operators.
Future<void> showKpmsAllFeaturesSheet(BuildContext context) {
  final theme = Theme.of(context);
  final width = MediaQuery.sizeOf(context).width;
  final maxHeight = MediaQuery.sizeOf(context).height * 0.92;
  final isDark = theme.brightness == Brightness.dark;
  final useDesktopPanel = isDesktop(context);

  Widget sheetContent(BuildContext ctx) {
    return Consumer(
      builder: (context, ref, _) {
        final permAsync = ref.watch(kpmsPermissionContextProvider);
        final radius = useDesktopPanel ? 20.0 : 28.0;
        return Container(
          constraints: BoxConstraints(
            maxHeight: maxHeight,
            maxWidth: useDesktopPanel ? 880 : double.infinity,
          ),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(radius),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.5 : 0.14),
                blurRadius: 40,
                offset: Offset(0, useDesktopPanel ? 8 : -12),
                spreadRadius: -4,
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(radius),
            child: permAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(48),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (_, _) => Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  AppLocalizations.of(context).featuresPermissionsError,
                  style: theme.textTheme.bodyMedium,
                ),
              ),
              data: (perm) {
                final l = AppLocalizations.of(context);
                final pharmacyItems = visiblePharmacyDestinations(perm);
                final showPlatform = perm.isPlatformSuperAdmin;

                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 12),
                    Container(
                      width: 48,
                      height: 5,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.14,
                        ),
                        borderRadius: BorderRadius.circular(100),
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.fromLTRB(
                        KpmsBreakpoints.pagePaddingHorizontal(width),
                        18,
                        KpmsBreakpoints.pagePaddingHorizontal(width),
                        12,
                      ),
                      child: Row(
                        children: [
                          DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  AppColors.primary.withValues(alpha: 0.22),
                                  AppColors.secondary.withValues(alpha: 0.14),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primary.withValues(
                                    alpha: 0.12,
                                  ),
                                  blurRadius: 16,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(11),
                              child: Icon(
                                Icons.grid_view_rounded,
                                color: AppColors.primary,
                                size: 22,
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  l.featuresHubTitle,
                                  style: theme.textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -0.3,
                                  ),
                                ),
                                Text(
                                  showPlatform
                                      ? l.featuresHubSubtitlePlatform
                                      : l.featuresHubSubtitlePharmacy,
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: theme.hintColor,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton.filledTonal(
                            tooltip: l.featuresClose,
                            style: IconButton.styleFrom(
                              foregroundColor: theme.colorScheme.onSurface
                                  .withValues(alpha: 0.75),
                            ),
                            onPressed: () => Navigator.of(ctx).pop(),
                            icon: const Icon(Icons.close_rounded, size: 22),
                          ),
                        ],
                      ),
                    ),
                    Flexible(
                      child: SingleChildScrollView(
                        padding: EdgeInsets.fromLTRB(
                          KpmsBreakpoints.pagePaddingHorizontal(width),
                          0,
                          KpmsBreakpoints.pagePaddingHorizontal(width),
                          28,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (showPlatform) ...[
                              _SectionLabel(
                                text: l.drawerPlatformSection,
                                color: theme.colorScheme.secondary,
                              ),
                              const SizedBox(height: 12),
                              _FeatureCardGrid(
                                items: kpmsPlatformDestinations,
                                crossAxisCount:
                                    width >= KpmsBreakpoints.mobileBottomNav
                                    ? 3
                                    : 2,
                                onTap: (route) {
                                  Navigator.of(ctx).pop();
                                  context.go(route);
                                },
                              ),
                            ] else ...[
                              _SectionLabel(
                                text: l.drawerPharmacySection,
                                color: theme.colorScheme.primary,
                              ),
                              const SizedBox(height: 12),
                              _FeatureCardGrid(
                                items: pharmacyItems,
                                crossAxisCount: useDesktopPanel
                                    ? 4
                                    : (width >= KpmsBreakpoints.mobileBottomNav
                                          ? 3
                                          : 2),
                                compact: !useDesktopPanel,
                                onTap: (route) {
                                  Navigator.of(ctx).pop();
                                  context.go(route);
                                },
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }

  if (useDesktopPanel) {
    return showKpmsResponsiveDialog<void>(
      context: context,
      maxWidth: 880,
      builder: sheetContent,
    );
  }

  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: false,
    backgroundColor: Colors.transparent,
    builder: sheetContent,
  );
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(left: 2),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 14,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            text,
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w800,
              color: color,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _FeatureCardGrid extends StatelessWidget {
  const _FeatureCardGrid({
    required this.items,
    required this.crossAxisCount,
    required this.onTap,
    this.compact = false,
  });

  final List<KpmsDestination> items;
  final int crossAxisCount;
  final void Function(String route) onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        mainAxisSpacing: compact ? 10 : 12,
        crossAxisSpacing: compact ? 10 : 12,
        childAspectRatio: compact ? 1.38 : (crossAxisCount >= 3 ? 1.02 : 0.96),
      ),
      itemCount: items.length,
      itemBuilder: (context, i) {
        final d = items[i];
        final isPlatform = d.zone == KpmsNavZone.platform;
        final accent = isPlatform ? AppColors.secondary : AppColors.primary;

        return _ModernFeatureCard(
          destination: d,
          accent: accent,
          compact: compact,
          title: d.navId.title(AppLocalizations.of(context)),
          subtitle: d.navId.subtitle(AppLocalizations.of(context)),
          onTap: () => onTap(d.route),
        );
      },
    );
  }
}

class _ModernFeatureCard extends StatefulWidget {
  const _ModernFeatureCard({
    required this.destination,
    required this.accent,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.compact = false,
  });

  final KpmsDestination destination;
  final Color accent;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool compact;

  @override
  State<_ModernFeatureCard> createState() => _ModernFeatureCardState();
}

class _ModernFeatureCardState extends State<_ModernFeatureCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final d = widget.destination;
    final compact = widget.compact;
    final isDark = theme.brightness == Brightness.dark;
    final surfaceElevated = theme.colorScheme.surfaceContainerHighest
        .withValues(alpha: isDark ? 0.45 : 0.65);
    final borderColor = theme.colorScheme.outline.withValues(
      alpha: isDark ? 0.22 : 0.12,
    );
    final accent = widget.accent;

    return AnimatedScale(
      scale: _pressed ? 0.97 : 1.0,
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOutCubic,
      child: Material(
        color: Colors.transparent,
        elevation: 0,
        child: InkWell(
          onTap: widget.onTap,
          onHighlightChanged: (v) => setState(() => _pressed = v),
          borderRadius: BorderRadius.circular(22),
          splashColor: accent.withValues(alpha: 0.12),
          highlightColor: accent.withValues(alpha: 0.06),
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [theme.colorScheme.surface, surfaceElevated],
              ),
              border: Border.all(color: borderColor, width: 1),
              boxShadow: [
                BoxShadow(
                  color: accent.withValues(alpha: isDark ? 0.14 : 0.08),
                  blurRadius: _pressed ? 12 : 20,
                  offset: Offset(0, _pressed ? 4 : 8),
                  spreadRadius: -2,
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.28 : 0.04),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                compact ? 12 : 14,
                compact ? 12 : 14,
                compact ? 10 : 12,
                compact ? 12 : 14,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeOutCubic,
                        padding: EdgeInsets.all(compact ? 9 : 11),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              accent.withValues(alpha: _pressed ? 0.26 : 0.18),
                              accent.withValues(alpha: _pressed ? 0.12 : 0.06),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: accent.withValues(alpha: 0.2),
                          ),
                        ),
                        child: Icon(d.icon, color: accent, size: 26),
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    widget.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.2,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    widget.subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.hintColor,
                      height: 1.3,
                      fontWeight: FontWeight.w500,
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
