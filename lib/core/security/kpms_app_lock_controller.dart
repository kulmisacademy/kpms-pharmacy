import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'kpms_app_lock_store.dart';

@immutable
class KpmsAppLockState {
  const KpmsAppLockState({
    required this.ready,
    required this.hasPin,
    required this.locked,
  });

  /// Initial state before the store has been read.
  const KpmsAppLockState.initial()
      : ready = false,
        hasPin = false,
        locked = false;

  final bool ready;
  final bool hasPin;

  /// True when the lock screen should block the app.
  final bool locked;

  /// Whether the lock screen must currently be shown.
  bool get shouldBlock => ready && hasPin && locked;

  KpmsAppLockState copyWith({bool? ready, bool? hasPin, bool? locked}) =>
      KpmsAppLockState(
        ready: ready ?? this.ready,
        hasPin: hasPin ?? this.hasPin,
        locked: locked ?? this.locked,
      );
}

class KpmsAppLockController extends StateNotifier<KpmsAppLockState> {
  KpmsAppLockController() : super(const KpmsAppLockState.initial()) {
    _load();
  }

  /// Re-lock after the app has been in the background longer than this.
  static const Duration relockAfter = Duration(seconds: 60);

  DateTime? _backgroundedAt;

  Future<void> _load() async {
    final has = await KpmsAppLockStore.hasPin();
    // If a PIN exists, start locked so the app is protected on cold start.
    state = KpmsAppLockState(ready: true, hasPin: has, locked: has);
  }

  Future<bool> unlock(String pin) async {
    final ok = await KpmsAppLockStore.verify(pin);
    if (ok) state = state.copyWith(locked: false);
    return ok;
  }

  /// Called after the PIN is created/changed so the new state is reflected.
  Future<void> refreshHasPin({bool lockNow = false}) async {
    final has = await KpmsAppLockStore.hasPin();
    state = state.copyWith(ready: true, hasPin: has, locked: lockNow && has);
  }

  Future<void> disablePin() async {
    await KpmsAppLockStore.clearPin();
    state = state.copyWith(hasPin: false, locked: false);
  }

  void onPaused() {
    if (state.hasPin) _backgroundedAt = DateTime.now();
  }

  void onResumed() {
    if (!state.hasPin) return;
    final since = _backgroundedAt;
    _backgroundedAt = null;
    if (since == null) return;
    if (DateTime.now().difference(since) >= relockAfter) {
      state = state.copyWith(locked: true);
    }
  }
}

final kpmsAppLockProvider =
    StateNotifierProvider<KpmsAppLockController, KpmsAppLockState>(
  (ref) => KpmsAppLockController(),
);
