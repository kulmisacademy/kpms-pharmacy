import 'kpms_release_monitoring.dart';

/// Lightweight counters for auth / tenant restore health (Sentry breadcrumbs + optional capture).
abstract final class KpmsAuthHealthMetrics {
  static int tenantRestoreFailures = 0;
  static int tenantStickyRecoveries = 0;
  static int tenantRpcFallbacks = 0;
  static int tokenRefreshFailures = 0;
  static int resumeSessionRefreshFailures = 0;
  static int resumeSessionRefreshSuccess = 0;

  static void onTenantRpcFallback(String rpcName) {
    tenantRpcFallbacks++;
    KpmsReleaseMonitoring.addBreadcrumb(
      'auth.tenant',
      'tenant_rpc_fallback',
      data: {'rpc': rpcName, 'count': tenantRpcFallbacks},
    );
  }

  static void onTenantStickyRecovery(String reason) {
    tenantStickyRecoveries++;
    KpmsReleaseMonitoring.addBreadcrumb(
      'auth.tenant',
      'tenant_sticky_recovery',
      data: {'reason': reason, 'count': tenantStickyRecoveries},
    );
  }

  static void onTenantRestoreFailure(String stage) {
    tenantRestoreFailures++;
    KpmsReleaseMonitoring.addBreadcrumb(
      'auth.tenant',
      'tenant_restore_failure',
      data: {'stage': stage, 'count': tenantRestoreFailures},
    );
    if (tenantRestoreFailures % 5 == 1) {
      KpmsReleaseMonitoring.captureException(
        StateError('kpms_tenant_restore_failures>=$tenantRestoreFailures'),
        extras: {'stage': stage},
      );
    }
  }

  static void onTokenRefreshFailure(Object err, StackTrace st) {
    tokenRefreshFailures++;
    KpmsReleaseMonitoring.addBreadcrumb(
      'auth.session',
      'token_refresh_failed',
      data: {'count': tokenRefreshFailures},
    );
    KpmsReleaseMonitoring.captureException(err, stackTrace: st);
  }

  static void onResumeRefreshOk() {
    resumeSessionRefreshSuccess++;
    KpmsReleaseMonitoring.addBreadcrumb(
      'auth.session',
      'resume_refresh_ok',
      data: {'count': resumeSessionRefreshSuccess},
    );
  }

  static void onResumeRefreshFail(Object err, StackTrace st) {
    resumeSessionRefreshFailures++;
    KpmsReleaseMonitoring.addBreadcrumb(
      'auth.session',
      'resume_refresh_fail',
      data: {'count': resumeSessionRefreshFailures, 'err': err.toString()},
    );
    KpmsReleaseMonitoring.captureException(err, stackTrace: st);
  }
}
