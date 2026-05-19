import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/debt_customer.dart';

final debtCustomersProvider =
    StateNotifierProvider<DebtCustomersNotifier, List<DebtCustomer>>((ref) {
  return DebtCustomersNotifier();
});

String _phoneKey(String raw) {
  return raw.replaceAll(RegExp(r'\D'), '');
}

class DebtCustomersNotifier extends StateNotifier<List<DebtCustomer>> {
  DebtCustomersNotifier() : super(const []);

  void replaceAll(List<DebtCustomer> next) {
    state = List<DebtCustomer>.from(next);
  }

  void reconcileWorkspace(List<DebtCustomer> remote) => replaceAll(remote);

  bool mergeWorkspaceEntity(DebtCustomer incoming) {
    final idx = state.indexWhere((c) => c.id == incoming.id);
    if (idx < 0) {
      state = [incoming, ...state];
      return true;
    }
    final existing = state[idx];
    if (existing.name == incoming.name &&
        existing.phoneKey == incoming.phoneKey &&
        existing.notes == incoming.notes) {
      return false;
    }
    state = [
      for (final c in state)
        if (c.id == incoming.id) incoming else c,
    ];
    return true;
  }

  void removeWorkspaceEntity(String clientId) {
    state = state.where((c) => c.id != clientId).toList();
  }

  List<DebtCustomer> search(String raw) {
    final q = raw.trim().toLowerCase();
    final digits = _phoneKey(raw);
    if (q.isEmpty) return List.of(state);
    return state.where((c) {
      if (c.name.toLowerCase().contains(q)) return true;
      if (digits.isNotEmpty && c.phoneKey.contains(digits)) return true;
      return false;
    }).toList(growable: false);
  }

  DebtCustomer? byId(String? id) {
    if (id == null || id.isEmpty) return null;
    for (final c in state) {
      if (c.id == id) return c;
    }
    return null;
  }

  DebtCustomer? findByPhoneKey(String phoneKey) {
    if (phoneKey.isEmpty) return null;
    for (final c in state) {
      if (c.phoneKey == phoneKey) return c;
    }
    return null;
  }

  /// Resolves existing customer by normalized phone, or creates a new profile.
  DebtCustomer findOrCreate({
    required String name,
    required String phoneDisplay,
    String notes = '',
  }) {
    final trimmedName = name.trim();
    final trimmedPhone = phoneDisplay.trim();
    final key = _phoneKey(trimmedPhone);
    if (key.isNotEmpty) {
      final existing = findByPhoneKey(key);
      if (existing != null) {
        final mergedNotes = [existing.notes, notes.trim()]
            .where((s) => s.isNotEmpty)
            .join(' · ');
        final updated = existing.copyWith(
          name: trimmedName.isNotEmpty ? trimmedName : existing.name,
          phoneDisplay: trimmedPhone.isNotEmpty ? trimmedPhone : existing.phoneDisplay,
          notes: mergedNotes,
        );
        state = [
          for (final c in state)
            if (c.id == existing.id) updated else c,
        ];
        return updated;
      }
    }
    final id = 'dc_${DateTime.now().microsecondsSinceEpoch}';
    final c = DebtCustomer(
      id: id,
      name: trimmedName.isEmpty ? 'Customer' : trimmedName,
      phoneDisplay: trimmedPhone,
      phoneKey: key,
      notes: notes.trim(),
      createdAt: DateTime.now(),
    );
    state = [c, ...state];
    return c;
  }
}
