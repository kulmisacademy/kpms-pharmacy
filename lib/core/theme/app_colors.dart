import 'package:flutter/material.dart';

/// KPMS **Pharmacy Enterprise** palette — primary green + deep navy.
/// Use [primary] for CTAs / success / POS; [secondary] for nav, headers, chrome.
abstract final class AppColors {
  // ─── Brand core ───
  /// Primary green — buttons, active states, success, POS, positive metrics.
  static const Color brandGreen = Color(0xFF16A34A);

  /// Deep navy — navigation, headers, sidebars, secondary analytics.
  static const Color brandNavy = Color(0xFF0D1B3D);

  /// Primary brand (same as green).
  static const Color primary = brandGreen;

  /// Darker green — gradients, pressed states, depth on primary.
  static const Color primaryDark = Color(0xFF15803D);

  /// Secondary = navy chrome.
  static const Color secondary = brandNavy;

  /// Mid navy — gradients, borders on navy, chart secondary series.
  static const Color navyMid = Color(0xFF152A52);

  /// Soft emerald accent — highlights, chips, tertiary chart tone (not rainbow).
  static const Color tertiary = Color(0xFF34D399);

  /// Neutral slate — secondary text, muted UI.
  static const Color neutral = Color(0xFF64748B);

  // ─── Surfaces (light) ───
  static const Color surfacePage = Color(0xFFF1F5F9);
  static const Color surfaceCard = Color(0xFFFFFFFF);
  static const Color outlineMuted = Color(0xFFE2E8F0);

  // ─── Surfaces (dark) — navy-tinted, not pure black ───
  /// Page / scroll canvas — darkest layer.
  static const Color surfaceDark = Color(0xFF0A0F1A);

  /// Cards, tiles, inputs — **lighter** than [surfaceDark] so content reads in slivers.
  static const Color surfaceDarkCard = Color(0xFF1A2D4D);

  /// Hero backgrounds & auth — deep navy through to forest green (premium, medical).
  static const LinearGradient brandGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF050A14),
      brandNavy,
      Color(0xFF134E2A),
    ],
    stops: [0.0, 0.48, 1.0],
  );

  static const LinearGradient glassHighlight = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0x40FFFFFF),
      Color(0x10FFFFFF),
    ],
  );

  // ─── Legacy aliases (screens compile unchanged) ───
  static const Color primaryBlue = primary;
  static const Color primaryBlueDark = primaryDark;
  static const Color accentGreen = tertiary;
  static const Color accentGreenSoft = Color(0xFF86EFAC);
  static const Color softGray = surfacePage;
  static const Color softGrayDark = surfaceDark;
  static const Color surfaceTint = outlineMuted;

  /// Pie / bar palette — green + navy family (no purple rainbow).
  static const int chartPrimaryArgb = 0xFF16A34A;
  static const int chartSecondaryArgb = 0xFF0D1B3D;
  static const int chartTertiaryArgb = 0xFF34D399;
  static const int chartQuaternaryArgb = 0xFF1E3A5F;
}
