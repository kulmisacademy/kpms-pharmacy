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
  return host.copyWith(
    brightness: Brightness.light,
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.surfaceCard,
    dividerTheme: DividerThemeData(color: scheme.outline.withValues(alpha: 0.12)),
  );
}
