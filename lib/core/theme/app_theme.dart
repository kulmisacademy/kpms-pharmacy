import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

/// KPMS Material 3 theme — **Plus Jakarta Sans**, green + navy enterprise system.
abstract final class AppTheme {
  static const double radiusCard = 18;
  static const double radiusInput = 14;
  static const double radiusButton = 14;

  static ThemeData get light {
    const onNavy = Colors.white;
    final colorScheme = ColorScheme.light(
      primary: AppColors.primary,
      onPrimary: Colors.white,
      primaryContainer: const Color(0xFFDCFCE7),
      onPrimaryContainer: const Color(0xFF14532D),
      secondary: AppColors.secondary,
      onSecondary: onNavy,
      secondaryContainer: const Color(0xFFE2ECF5),
      onSecondaryContainer: AppColors.secondary,
      tertiary: AppColors.tertiary,
      onTertiary: Color(0xFF042F2E),
      tertiaryContainer: AppColors.tertiary.withValues(alpha: 0.16),
      onTertiaryContainer: const Color(0xFF065F46),
      surface: AppColors.surfaceCard,
      onSurface: const Color(0xFF0F172A),
      onSurfaceVariant: AppColors.neutral,
      outline: AppColors.outlineMuted,
      outlineVariant: AppColors.outlineMuted.withValues(alpha: 0.65),
      error: const Color(0xFFB3261E),
      surfaceContainerHighest: AppColors.surfacePage,
    );

    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: colorScheme,
    );

    final titleWhite = GoogleFonts.plusJakartaSans(
      fontSize: 18,
      fontWeight: FontWeight.w700,
      color: onNavy,
      letterSpacing: -0.2,
    );

    return base.copyWith(
      scaffoldBackgroundColor: AppColors.surfacePage,
      textTheme: GoogleFonts.plusJakartaSansTextTheme(base.textTheme).apply(
        bodyColor: const Color(0xFF0F172A),
        displayColor: const Color(0xFF0F172A),
      ),
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        backgroundColor: AppColors.secondary,
        foregroundColor: onNavy,
        iconTheme: const IconThemeData(color: onNavy),
        titleTextStyle: titleWhite,
        systemOverlayStyle: SystemUiOverlayStyle.light.copyWith(
          statusBarColor: Colors.transparent,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 2,
        shadowColor: AppColors.secondary.withValues(alpha: 0.1),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusCard),
          side: BorderSide(color: AppColors.outlineMuted.withValues(alpha: 0.85)),
        ),
        color: AppColors.surfaceCard,
        surfaceTintColor: Colors.transparent,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusButton)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.secondary,
          side: BorderSide(color: AppColors.secondary.withValues(alpha: 0.35)),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusButton)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusButton)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceCard,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusInput),
          borderSide: BorderSide(color: AppColors.outlineMuted),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusInput),
          borderSide: BorderSide(color: AppColors.outlineMuted),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusInput),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        indicatorColor: AppColors.primary.withValues(alpha: 0.18),
        backgroundColor: Colors.transparent,
        labelTextStyle: WidgetStateProperty.all(
          GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600, fontSize: 12),
        ),
      ),
    );
  }

  static ThemeData get dark {
    final colorScheme = ColorScheme.dark(
      primary: AppColors.primary,
      onPrimary: Colors.white,
      primaryContainer: AppColors.primary.withValues(alpha: 0.22),
      onPrimaryContainer: const Color(0xFFBBF7D0),
      secondary: const Color(0xFF94A3B8),
      onSecondary: AppColors.secondary,
      secondaryContainer: AppColors.navyMid.withValues(alpha: 0.55),
      onSecondaryContainer: const Color(0xFFE2E8F0),
      tertiary: AppColors.tertiary,
      onTertiary: const Color(0xFF022C22),
      tertiaryContainer: AppColors.tertiary.withValues(alpha: 0.18),
      onTertiaryContainer: const Color(0xFFD1FAE5),
      surface: AppColors.surfaceDarkCard,
      onSurface: const Color(0xFFF1F5F9),
      onSurfaceVariant: const Color(0xFF94A3B8),
      outline: const Color(0xFF475569),
      surfaceContainerHighest: AppColors.surfaceDark,
      error: const Color(0xFFF2B8B5),
    );

    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme,
    );

    final titleDarkAppBar = GoogleFonts.plusJakartaSans(
      fontSize: 18,
      fontWeight: FontWeight.w700,
      color: const Color(0xFFF8FAFC),
      letterSpacing: -0.2,
    );

    return base.copyWith(
      scaffoldBackgroundColor: AppColors.surfaceDark,
      textTheme: GoogleFonts.plusJakartaSansTextTheme(base.textTheme).apply(
        bodyColor: const Color(0xFFF1F5F9),
        displayColor: const Color(0xFFF8FAFC),
      ),
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        // Spec: deep navy chrome — distinct from [surfaceDarkCard] tiles below.
        backgroundColor: AppColors.brandNavy,
        foregroundColor: const Color(0xFFF8FAFC),
        iconTheme: const IconThemeData(color: Color(0xFFF8FAFC)),
        titleTextStyle: titleDarkAppBar,
        systemOverlayStyle: SystemUiOverlayStyle.light.copyWith(
          statusBarColor: Colors.transparent,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 1,
        shadowColor: Colors.black.withValues(alpha: 0.45),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusCard),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
        ),
        color: AppColors.surfaceDarkCard,
        surfaceTintColor: Colors.transparent,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusButton)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFFE2E8F0),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.22)),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusButton)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.tertiary,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusButton)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceDarkCard,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusInput),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusInput),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusInput),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.transparent,
        indicatorColor: AppColors.primary.withValues(alpha: 0.28),
        labelTextStyle: WidgetStateProperty.all(
          GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600, fontSize: 12),
        ),
      ),
    );
  }
}
