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
    final effectiveMax = isDesktop(context) && maxWidth <= 920 ? 1280.0 : maxWidth;
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
