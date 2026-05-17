import 'dart:async';

import 'package:flutter/foundation.dart';

/// Notifies [GoRouter] when [stream] emits so `redirect` re-runs (e.g. Supabase auth).
class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    _subscription = stream.asBroadcastStream().listen((_) {
      if (_disposed) return;
      notifyListeners();
    });
  }

  late final StreamSubscription<dynamic> _subscription;
  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    unawaited(_subscription.cancel());
    super.dispose();
  }
}
