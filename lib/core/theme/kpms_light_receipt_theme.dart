import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Light, high-contrast theme for receipt / invoice dialogs.
///
/// Parent app may be dark mode; [AppColors.surfaceCard] stays white while
/// [ThemeData.textTheme] uses dark-on-light colors for readability.
ThemeData kpmsLightReceiptHostTheme(BuildContext context) {
  final host = Theme.of(context);
  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.primary,
    brightness: Brightness.light,
  ).copyWith(
    surface: AppColors.surfaceCard,
    surfaceContainerHighest: AppColors.surfacePage,
  );
  // The host (often dark) textTheme carries light-on-dark text colors. Without
  // re-coloring it, any Text that relies on the default textTheme color renders
  // near-white on the white receipt card and disappears. Re-apply dark-on-light
  // colors so every receipt label is legible regardless of the app's brightness.
  final textTheme = host.textTheme.apply(
    bodyColor: scheme.onSurface,
    displayColor: scheme.onSurface,
  );
  final primaryTextTheme = host.primaryTextTheme.apply(
    bodyColor: scheme.onSurface,
    displayColor: scheme.onSurface,
  );

  return host.copyWith(
    brightness: Brightness.light,
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.surfaceCard,
    textTheme: textTheme,
    primaryTextTheme: primaryTextTheme,
    dividerTheme: DividerThemeData(color: scheme.outline.withValues(alpha: 0.12)),
  );
}
