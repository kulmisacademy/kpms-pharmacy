import 'package:flutter/material.dart';

import '../responsive/responsive_breakpoints.dart';

/// Layout breakpoints — bottom nav only on compact widths.
abstract final class KpmsBreakpoints {
  /// Below this width, show mobile bottom navigation + hub sheet.
  static const double mobileBottomNav = ResponsiveBreakpoints.mobile;

  /// Narrow toolbar: single menu leading, back in actions, fewer app bar icons.
  static bool compactToolbar(double width) => width < mobileBottomNav;

  /// Single horizontal inset for [KpmsContentWidth] — avoids stacking 16+20px margins on phones.
  static double pagePaddingHorizontal(double width) {
    if (width < 520) return 12;
    if (width < 720) return 14;
    if (width < 1100) return 18;
    return 22;
  }

  /// Padding for root child inside [KpmsContentWidth] — **no horizontal** (gutters are from content width).
  static EdgeInsets pageBodyInsets(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    final top = w < 520 ? 6.0 : 10.0;
    final bottom = w < 520 ? 12.0 : 16.0;
    return EdgeInsets.fromLTRB(0, top, 0, bottom);
  }

  /// [ListView] / [GridView] padding under page shell — horizontal handled by [KpmsContentWidth].
  static EdgeInsets pageScrollPadding(BuildContext context, {double bottomExtra = 0}) {
    final w = MediaQuery.sizeOf(context).width;
    final top = w < 520 ? 6.0 : 8.0;
    final bottom = (w < 520 ? 14.0 : 18.0) + bottomExtra;
    return EdgeInsets.fromLTRB(0, top, 0, bottom);
  }
}
