import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/app_localizations.dart';
import '../../l10n/kpms_nav_l10n.dart';
import '../auth/permission_providers.dart';
import '../navigation/kpms_breakpoints.dart';
import '../navigation/kpms_dock_model.dart';
import '../navigation/kpms_destinations.dart';
import '../theme/app_colors.dart';
import 'kpms_all_features_sheet.dart';

/// Clinical Precision — **modern floating dock**: frosted glass, capsule active states,
/// elevated center hub (design kit). Slots are **RBAC-filtered** (no hidden access).
class KpmsMobileBottomNav extends ConsumerWidget {
  const KpmsMobileBottomNav({super.key});

  static bool showForWidth(double width) => width < KpmsBreakpoints.mobileBottomNav;

  /// Extra space for **scrollable** content so the last items clear the floating dock.
  static double scrollClearanceBottom(BuildContext context) {
    if (!showForWidth(MediaQuery.sizeOf(context).width)) return 0;
    final ref = 14.0;
    final scale = (MediaQuery.textScalerOf(context).scale(ref) / ref).clamp(1.0, 1.45);
    return 32 * scale;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l = AppLocalizations.of(context);
    final location = GoRouterState.of(context).uri.path;
    final perm = ref.watch(kpmsPermissionContextProvider).valueOrNull;
    final model = perm == null ? KpmsDockModel.empty : kpmsDockModelFor(perm);

    final idx = model.indexMatchingLocation(location);
    final navIndex = idx ?? 2;

    final isDark = theme.brightness == Brightness.dark;
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final bottomPad = bottomInset > 0 ? 10.0 : 18.0;

    final frostTint = isDark
        ? AppColors.surfaceDarkCard.withValues(alpha: 0.88)
        : Colors.white.withValues(alpha: 0.78);
    final borderColor = AppColors.outlineMuted.withValues(alpha: isDark ? 0.28 : 0.55);
    final shadowSoft = AppColors.primary.withValues(alpha: isDark ? 0.22 : 0.10);

    final refFont = 14.0;
    final textScaler = MediaQuery.textScalerOf(context);
    final textScaleFactor = (textScaler.scale(refFont) / refFont).clamp(1.0, 1.4);
    final barHeight = (92 * textScaleFactor).clamp(92.0, 104.0);

    KpmsDestination? left0 = model.left.isNotEmpty ? model.left[0] : null;
    KpmsDestination? left1 = model.left.length > 1 ? model.left[1] : null;
    KpmsDestination? right0 = model.right.isNotEmpty ? model.right[0] : null;
    KpmsDestination? right1 = model.right.length > 1 ? model.right[1] : null;

    void go(KpmsDestination? d) {
      if (d == null) return;
      context.go(d.route);
    }

    void onSelect(int i) {
      if (i == 2) {
        showKpmsAllFeaturesSheet(context);
        return;
      }
      switch (i) {
        case 0:
          go(left0);
          break;
        case 1:
          go(left1);
          break;
        case 3:
          go(right0);
          break;
        case 4:
          go(right1);
          break;
        default:
          break;
      }
    }

    Widget tileFor(KpmsDestination? d, int slotIndex) {
      if (d == null) {
        return const Expanded(child: SizedBox.shrink());
      }
      return Expanded(
        child: _DockTile(
          selected: navIndex == slotIndex,
          icon: d.icon,
          activeIcon: d.icon,
          label: d.navId.title(l),
          onTap: () => onSelect(slotIndex),
        ),
      );
    }

    return Padding(
      padding: EdgeInsets.fromLTRB(14, 12, 14, bottomPad),
      child: Material(
        color: Colors.transparent,
        elevation: 0,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                color: frostTint,
                border: Border.all(color: borderColor, width: 1),
                boxShadow: [
                  BoxShadow(
                    color: shadowSoft,
                    blurRadius: 40,
                    offset: const Offset(0, 14),
                    spreadRadius: -8,
                  ),
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.06),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: SizedBox(
                height: barHeight,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      tileFor(left0, 0),
                      tileFor(left1, 1),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 2),
                          child: Transform.translate(
                            offset: const Offset(0, -10),
                            child: _HubDockButton(
                              emphasized: navIndex == 2,
                              onTap: () => onSelect(2),
                            ),
                          ),
                        ),
                      ),
                      tileFor(right0, 3),
                      tileFor(right1, 4),
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

class _DockTile extends StatelessWidget {
  const _DockTile({
    required this.selected,
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.onTap,
  });

  final bool selected;
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = AppColors.primary;
    final muted = theme.colorScheme.onSurface.withValues(alpha: 0.55);

    return Semantics(
      selected: selected,
      button: true,
      label: label,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(22),
          splashColor: primary.withValues(alpha: 0.12),
          highlightColor: primary.withValues(alpha: 0.06),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 240),
                  curve: Curves.easeOutCubic,
                  padding: EdgeInsets.symmetric(
                    horizontal: selected ? 12 : 10,
                    vertical: selected ? 7 : 5,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(22),
                    color: selected ? primary.withValues(alpha: 0.14) : Colors.transparent,
                    boxShadow: selected
                        ? [
                            BoxShadow(
                              color: primary.withValues(alpha: 0.12),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ]
                        : null,
                  ),
                  child: Icon(
                    selected ? activeIcon : icon,
                    size: 24,
                    color: selected ? primary : muted,
                  ),
                ),
                const SizedBox(height: 3),
                AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 200),
                  style: (theme.textTheme.labelSmall ?? const TextStyle()).copyWith(
                    fontSize: 10,
                    height: 1.1,
                    letterSpacing: 0.15,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                    color: selected ? primary : muted,
                  ),
                  child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HubDockButton extends StatefulWidget {
  const _HubDockButton({
    required this.emphasized,
    required this.onTap,
  });

  final bool emphasized;
  final VoidCallback onTap;

  @override
  State<_HubDockButton> createState() => _HubDockButtonState();
}

class _HubDockButtonState extends State<_HubDockButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hub = AppColors.primary;
    final emphasized = widget.emphasized;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedScale(
          scale: _pressed ? 0.92 : 1.0,
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOutCubic,
          child: Material(
            color: Colors.transparent,
            shape: const CircleBorder(),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: widget.onTap,
              onHighlightChanged: (v) => setState(() => _pressed = v),
              splashColor: Colors.white.withValues(alpha: 0.22),
              highlightColor: Colors.white.withValues(alpha: 0.08),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 260),
                curve: Curves.easeOutCubic,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      hub,
                      AppColors.primaryDark,
                      AppColors.navyMid.withValues(alpha: 0.55),
                    ],
                    stops: const [0.0, 0.55, 1.0],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: hub.withValues(alpha: emphasized ? 0.5 : 0.34),
                      blurRadius: emphasized ? 18 : 12,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Icon(Icons.grid_view_rounded, color: Colors.white, size: emphasized ? 26 : 24),
              ),
            ),
          ),
        ),
        const SizedBox(height: 1),
        Text(
          AppLocalizations.of(context).dockAll,
          style: theme.textTheme.labelSmall?.copyWith(
            fontSize: 10,
            height: 1.1,
            fontWeight: emphasized ? FontWeight.w800 : FontWeight.w600,
            color: emphasized ? hub : theme.colorScheme.onSurface.withValues(alpha: 0.55),
          ),
        ),
      ],
    );
  }
}
