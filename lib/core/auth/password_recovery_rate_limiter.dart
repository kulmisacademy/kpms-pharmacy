/// Client-side throttles for password recovery (send bursts, verify lockout).
abstract final class PasswordRecoveryRateLimiter {
  static final Map<String, DateTime> _lastSend = {};
  static final Map<String, List<DateTime>> _sendHistory = {};
  static final Map<String, int> _verifyFails = {};
  static final Map<String, DateTime> _verifyLockUntil = {};

  static const sendCooldown = Duration(seconds: 60);
  static const maxVerifyAttempts = 5;
  static const verifyLockout = Duration(minutes: 15);
  static const maxSendsPerRollingHour = 5;

  static String _key(String email) => email.trim().toLowerCase();

  static void _pruneSendHistory(String email) {
    final k = _key(email);
    final list = _sendHistory.putIfAbsent(k, () => []);
    final cutoff = DateTime.now().subtract(const Duration(hours: 1));
    list.removeWhere((t) => t.isBefore(cutoff));
  }

  /// Sends in the last rolling hour (aligns with server-side hourly cap).
  static int sendsInLastHour(String email) {
    _pruneSendHistory(email);
    return (_sendHistory[_key(email)] ?? const []).length;
  }

  static Duration? sendCooldownRemaining(String email) {
    final last = _lastSend[_key(email)];
    if (last == null) return null;
    final elapsed = DateTime.now().difference(last);
    if (elapsed >= sendCooldown) return null;
    return sendCooldown - elapsed;
  }

  static bool canSend(String email) {
    if (sendsInLastHour(email) >= maxSendsPerRollingHour) return false;
    return sendCooldownRemaining(email) == null;
  }

  static Duration? sendBlockedRemaining(String email) {
    final cd = sendCooldownRemaining(email);
    if (cd != null) return cd;
    if (sendsInLastHour(email) >= maxSendsPerRollingHour) {
      _pruneSendHistory(email);
      final list = _sendHistory[_key(email)] ?? const [];
      if (list.isEmpty) return null;
      final oldest = list.reduce((a, b) => a.isBefore(b) ? a : b);
      final until = oldest.add(const Duration(hours: 1));
      final left = until.difference(DateTime.now());
      if (left.isNegative) return null;
      return left;
    }
    return null;
  }

  static void recordSend(String email) {
    final k = _key(email);
    _lastSend[k] = DateTime.now();
    _pruneSendHistory(email);
    _sendHistory.putIfAbsent(k, () => []).add(DateTime.now());
  }

  static DateTime? verifyLockUntil(String email) => _verifyLockUntil[_key(email)];

  static bool isVerifyLocked(String email) {
    final until = verifyLockUntil(email);
    if (until == null) return false;
    if (DateTime.now().isAfter(until)) {
      _verifyLockUntil.remove(_key(email));
      return false;
    }
    return true;
  }

  static bool canAttemptVerify(String email) {
    if (isVerifyLocked(email)) return false;
    return (_verifyFails[_key(email)] ?? 0) < maxVerifyAttempts;
  }

  static void recordVerifyFailure(String email) {
    final k = _key(email);
    final n = (_verifyFails[k] ?? 0) + 1;
    _verifyFails[k] = n;
    if (n >= maxVerifyAttempts) {
      _verifyLockUntil[k] = DateTime.now().add(verifyLockout);
    }
  }

  static void applyServerVerifyLock(String email) {
    _verifyLockUntil[_key(email)] = DateTime.now().add(verifyLockout);
  }

  static void clearVerifyFailures(String email) {
    final k = _key(email);
    _verifyFails.remove(k);
    _verifyLockUntil.remove(k);
  }

  static void resetSession(String email) {
    final k = _key(email);
    _lastSend.remove(k);
    _sendHistory.remove(k);
    _verifyFails.remove(k);
    _verifyLockUntil.remove(k);
  }
}
