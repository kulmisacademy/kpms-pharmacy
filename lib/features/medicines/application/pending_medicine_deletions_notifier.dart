import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/tenant/kpms_active_tenant_provider.dart';

/// Client ids removed locally that still need a cloud `pharmacy_inventory` delete.
final pendingMedicineDeletionsProvider =
    StateNotifierProvider<PendingMedicineDeletionsNotifier, List<String>>((ref) {
  return PendingMedicineDeletionsNotifier(ref);
});

class PendingMedicineDeletionsNotifier extends StateNotifier<List<String>> {
  PendingMedicineDeletionsNotifier(this._ref) : super(const []);

  final Ref _ref;
  String? _loadedTenantId;

  static String _prefsKey(String tenantId) => 'kpms_pending_med_deletes_v1_$tenantId';

  Future<void> reloadForTenant(String tenantId) async {
    final tid = tenantId.trim();
    if (tid.isEmpty) {
      state = const [];
      _loadedTenantId = null;
      return;
    }
    _loadedTenantId = tid;
    await _load(tid);
  }

  Future<void> clearForTenantSwitch() async {
    state = const [];
    _loadedTenantId = null;
  }

  Future<void> _load(String tenantId) async {
    final tid = tenantId.trim();
    if (tid.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey(tid));
    if (raw == null || raw.isEmpty) return;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        state = [for (final e in decoded) '$e'.trim()].where((s) => s.isNotEmpty).toList();
      }
    } catch (_) {}
  }

  Future<void> _ensureLoaded() async {
    final tid = _ref.read(kpmsActiveTenantIdProvider).valueOrNull;
    if (tid == null || tid.isEmpty) return;
    if (_loadedTenantId == tid) return;
    await reloadForTenant(tid);
  }

  Future<void> _persist() async {
    final tid = _loadedTenantId ?? _ref.read(kpmsActiveTenantIdProvider).valueOrNull;
    if (tid == null || tid.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    if (state.isEmpty) {
      await prefs.remove(_prefsKey(tid));
    } else {
      await prefs.setString(_prefsKey(tid), jsonEncode(state));
    }
  }

  Future<void> enqueue(String clientId) async {
    await _ensureLoaded();
    final id = clientId.trim();
    if (id.isEmpty || state.contains(id)) return;
    state = [...state, id];
    await _persist();
  }

  Future<void> clearIds(Iterable<String> ids) async {
    final remove = ids.map((e) => e.trim()).where((s) => s.isNotEmpty).toSet();
    if (remove.isEmpty) return;
    state = state.where((id) => !remove.contains(id)).toList();
    await _persist();
  }

  Future<void> replaceAll(List<String> ids) async {
    state = [for (final e in ids) e.trim()].where((s) => s.isNotEmpty).toList();
    await _persist();
  }
}
