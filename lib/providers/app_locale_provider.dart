import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/constants/app_prefs_keys.dart';
import '../features/settings/application/pharmacy_settings_providers.dart';

const _supportedCodes = {'en', 'so', 'ar'};

Locale kpmsLocaleFromCode(String code) {
  switch (code) {
    case 'so':
      return const Locale('so');
    case 'ar':
      return const Locale('ar');
    default:
      return const Locale('en');
  }
}

class AppLocaleNotifier extends StateNotifier<Locale> {
  AppLocaleNotifier(this._ref) : super(const Locale('en'));

  final Ref _ref;

  Future<void> loadFromDevice() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(AppPrefsKeys.appLocale);
    if (stored != null && _supportedCodes.contains(stored)) {
      state = kpmsLocaleFromCode(stored);
    }
    await mergeFromTenantIfNoDevicePreference();
  }

  /// When the device has no saved locale, adopt [tenants.settings.ui_locale] once.
  Future<void> mergeFromTenantIfNoDevicePreference() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getString(AppPrefsKeys.appLocale) != null) return;
    final tenant = _ref.read(pharmacySessionProvider).valueOrNull?.tenant;
    final raw = tenant?.settingsJson['ui_locale'];
    if (raw is! String || !_supportedCodes.contains(raw)) return;
    state = kpmsLocaleFromCode(raw);
    await prefs.setString(AppPrefsKeys.appLocale, raw);
  }

  Future<void> setLocale(Locale locale) async {
    final code = locale.languageCode;
    if (!_supportedCodes.contains(code)) return;
    state = Locale(code);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppPrefsKeys.appLocale, code);

    final session = _ref.read(pharmacySessionProvider).valueOrNull;
    if (session == null) return;
    final merged = session.tenant.mergeSettingsJson({'ui_locale': code});
    try {
      await _ref.read(pharmacySettingsRepositoryProvider).updateTenant(
            tenantId: session.tenant.id,
            name: session.tenant.name,
            address: session.tenant.address,
            phone: session.tenant.phone,
            licenseNumber: session.tenant.licenseNumber,
            ownerName: session.tenant.ownerName,
            settings: merged,
          );
      await _ref.read(pharmacySessionProvider.notifier).reload();
    } catch (_) {
      // Locale already applied locally; server sync can retry later.
    }
  }
}

final appLocaleProvider = StateNotifierProvider<AppLocaleNotifier, Locale>((ref) {
  final notifier = AppLocaleNotifier(ref);
  unawaited(notifier.loadFromDevice());
  ref.listen<AsyncValue<PharmacySessionData?>>(pharmacySessionProvider, (_, _) {
    unawaited(notifier.mergeFromTenantIfNoDevicePreference());
  });
  return notifier;
});
