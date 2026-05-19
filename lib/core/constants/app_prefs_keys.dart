/// SharedPreferences keys — keep stable across releases.
abstract final class AppPrefsKeys {
  static const String onboardingCompleted = 'kpms_onboarding_v1';
  static const String themeMode = 'kpms_theme_mode';

  /// BCP-47 language code: `en`, `so`, or `ar`.
  static const String appLocale = 'kpms_app_locale_v1';
  static const String platformSidebarCollapsed = 'kpms_platform_sidebar_collapsed_v1';

  /// When true, a successful POS barcode scan adds the line immediately from the scanner.
  static const String posAutoAddAfterBarcodeScan = 'kpms_pos_auto_add_barcode_v1';

  /// Full local pharmacy workspace (catalog, ledgers, AR customers, suppliers).
  static const String pharmacyLocalWorkspace = 'kpms_pharmacy_workspace_v1';

  /// Monotonic schema for [pharmacyLocalWorkspace] + related local bundles (clear on bump).
  static const String localBundleSchemaVersion = 'kpms_local_bundle_schema_v1';

  /// Platform operator login — "Remember this device" UX preference (session persistence is Supabase default).
  static const String platformRememberDevice = 'kpms_platform_remember_device_v1';

  /// Last acknowledged [profiles.permission_revoke_nonce] per signed-in user (`$key_$userId`).
  static const String permissionRevokeNonce = 'kpms_perm_revoke_nonce_v1';

  /// Last acknowledged [tenants.force_logout_epoch] per user (`${forceLogoutEpochAck}_$userId`).
  static const String forceLogoutEpochAck = 'kpms_force_logout_epoch_ack_v1';

  /// Anonymous install fingerprint for [pharmacy_staff_device_sessions.device_id].
  static const String deviceFingerprint = 'kpms_device_fingerprint_v1';

  /// ISO-8601 last successful cloud pull per tenant (`${workspaceLastPullAt}_$tenantId`).
  static const String workspaceLastPullAt = 'kpms_workspace_last_pull_v1';
}
