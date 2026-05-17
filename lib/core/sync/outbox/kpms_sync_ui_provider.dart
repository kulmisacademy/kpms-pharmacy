import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum KpmsSyncVisualState {
  idle,
  offline,
  pending,
  syncing,
  failed,
  retrying,
}

@immutable
class KpmsSyncUiState {
  const KpmsSyncUiState({
    this.visual = KpmsSyncVisualState.idle,
    this.pendingCount = 0,
    this.failedCount = 0,
    this.syncing = false,
  });

  final KpmsSyncVisualState visual;
  final int pendingCount;
  final int failedCount;
  final bool syncing;
}

class KpmsSyncUiNotifier extends StateNotifier<KpmsSyncUiState> {
  KpmsSyncUiNotifier() : super(const KpmsSyncUiState());

  void reset() => state = const KpmsSyncUiState();

  void applyCounts({
    required int pending,
    required int failed,
    required bool offline,
    required bool syncing,
    required bool retrying,
  }) {
    KpmsSyncVisualState v;
    if (offline) {
      v = KpmsSyncVisualState.offline;
    } else if (syncing) {
      v = KpmsSyncVisualState.syncing;
    } else if (retrying) {
      v = KpmsSyncVisualState.retrying;
    } else if (failed > 0) {
      v = KpmsSyncVisualState.failed;
    } else if (pending > 0) {
      v = KpmsSyncVisualState.pending;
    } else {
      v = KpmsSyncVisualState.idle;
    }
    state = KpmsSyncUiState(
      visual: v,
      pendingCount: pending,
      failedCount: failed,
      syncing: syncing,
    );
  }
}

final kpmsSyncUiProvider = StateNotifierProvider<KpmsSyncUiNotifier, KpmsSyncUiState>((ref) {
  return KpmsSyncUiNotifier();
});
