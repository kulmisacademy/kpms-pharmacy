import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

import '../constants/app_prefs_keys.dart';

/// Stable random id for this app install (device session registry).
abstract final class KpmsDeviceFingerprint {
  static const _chars = 'abcdefghijklmnopqrstuvwxyz0123456789';

  static Future<String> resolve() async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getString(AppPrefsKeys.deviceFingerprint);
    if (existing != null && existing.length >= 8) return existing;
    final rnd = Random.secure();
    final buf = StringBuffer();
    for (var i = 0; i < 24; i++) {
      buf.write(_chars[rnd.nextInt(_chars.length)]);
    }
    final v = buf.toString();
    await prefs.setString(AppPrefsKeys.deviceFingerprint, v);
    return v;
  }
}
