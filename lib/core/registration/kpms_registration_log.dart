import 'package:flutter/foundation.dart';

/// Diagnostics for pharmacy registration (search logs for `[kpms.registration]`).
abstract final class KpmsRegistrationLog {
  static const String _p = '[kpms.registration]';

  static void _emit(String step, [String? detail]) {
    final tail = detail == null || detail.isEmpty ? '' : ' | $detail';
    debugPrint('$_p $step$tail');
  }

  static void registrationStarted() => _emit('registration_started');

  static void authCreated({required bool hasSession}) => _emit('auth_created', 'hasSession=$hasSession');

  static void sessionConfirmed() => _emit('session_confirmed');

  static void tenantCreated() => _emit('tenant_created');

  static void tenantLinked() => _emit('tenant_linked');

  static void tenantConfirmed({required bool hasTenant}) => _emit('tenant_confirmed', 'hasTenant=$hasTenant');

  static void registrationTimeout() => _emit('registration_timeout');

  static void redirectFallback(Object e) => _emit('redirect_fallback', e.toString());

  static void redirectStarted() => _emit('redirect_started');

  static void redirectCompleted() => _emit('redirect_completed');

  static void loadingReset() => _emit('loading_reset');

  static void sessionReloadScheduled() => _emit('session_reload_scheduled');

  static void sessionReloadDone() => _emit('session_reload_done');

  static void sessionReloadFailed(Object e) => _emit('session_reload_failed', e.toString());

  static void logoDeferredSkipped(Object e) => _emit('logo_deferred_skipped', e.toString());

  static void tenantLinkCheckTimeout() => _emit('tenant_link_check_timeout');

  static void rpcTimeout() => _emit('register_pharmacy_timeout');

  static void backPressedWhileBusy() => _emit('back_pressed_while_busy');
}
