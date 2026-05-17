import 'package:flutter/material.dart';

import 'responsive_helpers.dart';

/// Picks the child for the current viewport tier (mobile / tablet / desktop).
class ResponsiveLayout extends StatelessWidget {
  const ResponsiveLayout({
    super.key,
    required this.mobile,
    this.tablet,
    required this.desktop,
  });

  final Widget mobile;
  final Widget? tablet;
  final Widget desktop;

  @override
  Widget build(BuildContext context) {
    switch (responsiveTierOf(context)) {
      case ResponsiveTier.mobile:
        return mobile;
      case ResponsiveTier.tablet:
        return tablet ?? desktop;
      case ResponsiveTier.desktop:
        return desktop;
    }
  }
}
