import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Encrypted on-device store for the optional app-lock PIN.
///
/// Only a salted SHA-256 hash of the PIN is persisted — never the PIN itself.
/// Storage is platform-encrypted (Keychain / Keystore / encrypted prefs).
abstract final class KpmsAppLockStore {
  KpmsAppLockStore._();

  static const _hashKey = 'kpms_app_lock_pin_hash_v1';
  static const _saltKey = 'kpms_app_lock_pin_salt_v1';

  static const FlutterSecureStorage _storage = FlutterSecureStorage(
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock_this_device),
  );

  static String _hash(String pin, String salt) =>
      sha256.convert(utf8.encode('$salt::$pin')).toString();

  static String _newSalt() {
    final rnd = Random.secure();
    final bytes = List<int>.generate(16, (_) => rnd.nextInt(256));
    return base64Url.encode(bytes);
  }

  /// True when a PIN is currently set.
  static Future<bool> hasPin() async {
    try {
      final h = await _storage.read(key: _hashKey);
      return h != null && h.isNotEmpty;
    } catch (e, st) {
      debugPrint('KpmsAppLockStore.hasPin failed: $e\n$st');
      return false;
    }
  }

  /// Persists a new PIN (replaces any existing one).
  static Future<void> setPin(String pin) async {
    final salt = _newSalt();
    await _storage.write(key: _saltKey, value: salt);
    await _storage.write(key: _hashKey, value: _hash(pin, salt));
  }

  /// True when [pin] matches the stored PIN.
  static Future<bool> verify(String pin) async {
    try {
      final salt = await _storage.read(key: _saltKey);
      final stored = await _storage.read(key: _hashKey);
      if (salt == null || stored == null || stored.isEmpty) return false;
      return _hash(pin, salt) == stored;
    } catch (e, st) {
      debugPrint('KpmsAppLockStore.verify failed: $e\n$st');
      return false;
    }
  }

  /// Removes the PIN (disables app lock).
  static Future<void> clearPin() async {
    try {
      await _storage.delete(key: _hashKey);
      await _storage.delete(key: _saltKey);
    } catch (e, st) {
      debugPrint('KpmsAppLockStore.clearPin failed: $e\n$st');
    }
  }
}
