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
  PendingMedicineDeletionsNotifier(this._ref) : super(const []) {
    _load();
  }

  final Ref _ref;

  static String _prefsKey(String tenantId) => 'kpms_pending_med_deletes_v1_$tenantId';

  Future<void> _load() async {
    final tid = _ref.read(kpmsActiveTenantIdProvider).valueOrNull;
    if (tid == null || tid.isEmpty) return;
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

  Future<void> _persist() async {
    final tid = _ref.read(kpmsActiveTenantIdProvider).valueOrNull;
    if (tid == null || tid.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    if (state.isEmpty) {
      await prefs.remove(_prefsKey(tid));
    } else {
      await prefs.setString(_prefsKey(tid), jsonEncode(state));
    }
  }

  Future<void> enqueue(String clientId) async {
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
