import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/constants/app_prefs_keys.dart';

/// Initial mode resolved synchronously after [preloadInitialThemeMode] runs in `main()`.
/// Defaults to system when not yet preloaded.
ThemeMode _initialThemeMode = ThemeMode.system;

/// Reads SharedPreferences once and caches the persisted theme so [ThemeModeNotifier]
/// can start with the user's preference (no light → dark flash).
Future<void> preloadInitialThemeMode() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    _initialThemeMode = ThemeModeNotifier._parse(prefs.getString(AppPrefsKeys.themeMode));
  } catch (_) {
    _initialThemeMode = ThemeMode.system;
  }
}

class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  ThemeModeNotifier() : super(_initialThemeMode) {
    _syncFromPrefs();
  }

  /// Reconciles state in case [preloadInitialThemeMode] wasn't awaited (cold cache).
  Future<void> _syncFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final next = _parse(prefs.getString(AppPrefsKeys.themeMode));
    if (next != state) state = next;
  }

  static ThemeMode _parse(String? raw) => switch (raw) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      };

  static String _serialize(ThemeMode mode) => switch (mode) {
        ThemeMode.light => 'light',
        ThemeMode.dark => 'dark',
        ThemeMode.system => 'system',
      };

  Future<void> setTheme(ThemeMode mode) async {
    state = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppPrefsKeys.themeMode, _serialize(mode));
  }
}

final themeModeProvider = StateNotifierProvider<ThemeModeNotifier, ThemeMode>((ref) {
  return ThemeModeNotifier();
});
