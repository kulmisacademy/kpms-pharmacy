import 'package:flutter/material.dart';

import '../navigation/kpms_breakpoints.dart';
import '../responsive/responsive_helpers.dart';

/// Centers content on wide screens; **one** horizontal inset on phones (no double-padding).
class KpmsContentWidth extends StatelessWidget {
  const KpmsContentWidth({
    super.key,
    required this.child,
    this.maxWidth = 920,
    this.padding,
  });

  final Widget child;
  final double maxWidth;

  /// When null, uses [KpmsBreakpoints.pagePaddingHorizontal] for the current width.
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    final resolved = padding ??
        EdgeInsets.symmetric(horizontal: KpmsBreakpoints.pagePaddingHorizontal(w));
    // Scale desktop max width with viewport so wide monitors actually use the space
    // instead of leaving huge empty gutters. Honors `maxWidth` as a *minimum* desktop
    // budget — callers can still pass a smaller intentional reading-width.
    double effectiveMax = maxWidth;
    if (isDesktop(context)) {
      final dynamicMax = w >= 1900
          ? 1640.0
          : w >= 1600
              ? 1480.0
              : w >= 1400
                  ? 1320.0
                  : 1200.0;
      if (maxWidth <= 920) {
        effectiveMax = dynamicMax;
      } else if (dynamicMax > maxWidth) {
        effectiveMax = dynamicMax;
      }
    }
    return Align(
      alignment: Alignment.topCenter,
      child: Padding(
        padding: resolved,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: effectiveMax),
          child: child,
        ),
      ),
    );
  }
}
