import 'dart:collection';

/// Simple in-memory throttling to slow brute-force attempts (per isolate).
abstract final class LoginRateLimiter {
  static final _failures = HashMap<String, List<DateTime>>();

  static const _maxFailures = 5;
  static const _window = Duration(minutes: 2);
  static const _lockout = Duration(seconds: 45);

  static String _key(String email) => email.trim().toLowerCase();

  static void recordSuccess(String email) {
    _failures.remove(_key(email));
  }

  static void recordFailure(String email) {
    final k = _key(email);
    final now = DateTime.now();
    final list = _failures.putIfAbsent(k, () => <DateTime>[])..add(now);
    list.removeWhere((t) => now.difference(t) > _window);
  }

  /// If true, caller should refuse login and show a short lockout message.
  static bool isLockedOut(String email) {
    final k = _key(email);
    final list = _failures[k];
    if (list == null || list.isEmpty) return false;
    final now = DateTime.now();
    list.removeWhere((t) => now.difference(t) > _window);
    if (list.length < _maxFailures) return false;
    final oldestInWindow = list.first;
    return now.difference(oldestInWindow) < _window;
  }

  static Duration? timeUntilRetry(String email) {
    if (!isLockedOut(email)) return null;
    final k = _key(email);
    final list = _failures[k];
    if (list == null || list.isEmpty) return null;
    final now = DateTime.now();
    final oldestInWindow = list.first;
    final unlockAt = oldestInWindow.add(_window);
    final d = unlockAt.difference(now);
    return d > Duration.zero ? d : _lockout;
  }
}
