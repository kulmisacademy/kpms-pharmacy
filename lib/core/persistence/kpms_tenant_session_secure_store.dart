import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Last confirmed pharmacy session (tenant binding) for the signed-in account.
///
/// Cleared on explicit [clear]. **Not** cleared on transient routing/session gaps so
/// offline / refresh hiccups can still recover workspace hints safely.
@immutable
class KpmsTenantSessionSnapshot {
  const KpmsTenantSessionSnapshot({
    required this.userId,
    required this.tenantId,
    this.role,
    this.pharmacyName,
    required this.savedAtMs,
  });

  final String userId;
  final String tenantId;
  final String? role;
  final String? pharmacyName;
  final int savedAtMs;

  static const int schemaVersion = 1;

  Map<String, dynamic> toJson() => {
        'v': schemaVersion,
        'userId': userId,
        'tenantId': tenantId,
        'role': role,
        'pharmacyName': pharmacyName,
        'savedAtMs': savedAtMs,
      };

  static KpmsTenantSessionSnapshot? tryDecode(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    try {
      final o = jsonDecode(raw);
      if (o is! Map) return null;
      final m = Map<String, dynamic>.from(o);
      if ((m['v'] as num?)?.toInt() != schemaVersion) return null;
      final uid = m['userId'] as String?;
      final tid = m['tenantId'] as String?;
      if (uid == null || uid.isEmpty || tid == null || tid.isEmpty) return null;
      return KpmsTenantSessionSnapshot(
        userId: uid,
        tenantId: tid,
        role: m['role'] as String?,
        pharmacyName: m['pharmacyName'] as String?,
        savedAtMs: (m['savedAtMs'] as num?)?.toInt() ?? 0,
      );
    } catch (_) {
      return null;
    }
  }
}

/// Encrypted device storage for tenant session hints (not a substitute for server truth).
abstract final class KpmsTenantSessionSecureStore {
  KpmsTenantSessionSecureStore._();

  static const _storageKey = 'kpms_tenant_session_snapshot_v1';

  static const FlutterSecureStorage _storage = FlutterSecureStorage(
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock_this_device),
  );

  static Future<KpmsTenantSessionSnapshot?> read() async {
    try {
      final raw = await _storage.read(key: _storageKey);
      return KpmsTenantSessionSnapshot.tryDecode(raw);
    } catch (e, st) {
      debugPrint('KpmsTenantSessionSecureStore.read failed: $e\n$st');
      return null;
    }
  }

  static Future<void> write(KpmsTenantSessionSnapshot snapshot) async {
    try {
      await _storage.write(
        key: _storageKey,
        value: jsonEncode(snapshot.toJson()),
      );
    } catch (e, st) {
      debugPrint('KpmsTenantSessionSecureStore.write failed: $e\n$st');
    }
  }

  static Future<void> clear() async {
    try {
      await _storage.delete(key: _storageKey);
    } catch (e, st) {
      debugPrint('KpmsTenantSessionSecureStore.clear failed: $e\n$st');
    }
  }
}
