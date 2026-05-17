import 'package:flutter/material.dart';

import 'responsive_breakpoints.dart';

/// Layout tier derived from viewport width.
enum ResponsiveTier {
  mobile,
  tablet,
  desktop,
}

ResponsiveTier responsiveTierForWidth(double width) {
  if (width < ResponsiveBreakpoints.mobile) return ResponsiveTier.mobile;
  if (width < ResponsiveBreakpoints.desktop) return ResponsiveTier.tablet;
  return ResponsiveTier.desktop;
}

ResponsiveTier responsiveTierOf(BuildContext context) =>
    responsiveTierForWidth(MediaQuery.sizeOf(context).width);

bool isMobile(BuildContext context) =>
    responsiveTierOf(context) == ResponsiveTier.mobile;

bool isTablet(BuildContext context) =>
    responsiveTierOf(context) == ResponsiveTier.tablet;

bool isDesktop(BuildContext context) =>
    responsiveTierOf(context) == ResponsiveTier.desktop;

bool isMobileWidth(double width) => width < ResponsiveBreakpoints.mobile;

bool isTabletWidth(double width) =>
    width >= ResponsiveBreakpoints.mobile && width < ResponsiveBreakpoints.desktop;

bool isDesktopWidth(double width) => width >= ResponsiveBreakpoints.desktop;
