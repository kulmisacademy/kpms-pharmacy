import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'kpms_bundled_env_reader.dart';
import 'kpms_env_diagnostics.dart';
import 'kpms_env_parser.dart';
import 'kpms_env_placeholders.dart';
import 'kpms_environment_stub.dart' if (dart.library.io) 'kpms_environment_io.dart' as env_io;

/// Centralized KPMS environment resolution.
///
/// **Release (store APK/AAB):** bundled `assets/env/default.env` + `production.env`, optional
/// `--dart-define`. Root `.env` is **not** read at runtime on device.
///
/// **Debug mobile:** same bundled layers + `generated_debug.env` (synced from root `.env` at build).
///
/// **Precedence (highest wins):** `--dart-define` → bundled assets → IO project-root `.env*` (desktop).
class KpmsEnvironment {
  KpmsEnvironment._();

  static const _urlKeys = ['SUPABASE_URL', 'KPMS_SUPABASE_URL'];
  static const _anonKeys = ['SUPABASE_ANON_KEY', 'KPMS_SUPABASE_ANON_KEY'];

  static String? _loadError;
  static List<String> _startupIssues = const [];
  static Map<String, String> _resolved = const {};

  static String? get loadError => _loadError;
  static List<String> get startupIssues => List.unmodifiable(_startupIssues);

  static String? get supabaseUrl => _firstNonEmpty(_urlKeys);
  static String? get supabaseAnonKey => _firstNonEmpty(_anonKeys);

  /// Optional absolute URL for Supabase `resetPasswordForEmail(redirectTo:)` (mobile deep link / universal link).
  static String? get authPasswordResetRedirectUrl => _firstNonEmpty(['KPMS_AUTH_PASSWORD_RESET_REDIRECT']);

  static bool get isConfigured {
    if (_hasServiceRoleKey) return false;
    return (supabaseUrl?.isNotEmpty ?? false) && (supabaseAnonKey?.isNotEmpty ?? false);
  }

  static bool get _hasServiceRoleKey =>
      _resolved.keys.any((k) => k.toUpperCase().contains('SERVICE_ROLE'));

  static bool _mapHasSupabaseKeys(Map<String, String> m) {
    bool ok(String k) => (m[k]?.trim().isNotEmpty ?? false);
    return ok('SUPABASE_URL') ||
        ok('KPMS_SUPABASE_URL') ||
        ok('SUPABASE_ANON_KEY') ||
        ok('KPMS_SUPABASE_ANON_KEY');
  }

  static bool _definesPresent(Map<String, String> m) =>
      m.containsKey('SUPABASE_URL') ||
      m.containsKey('SUPABASE_ANON_KEY') ||
      m.containsKey('KPMS_SUPABASE_URL') ||
      m.containsKey('KPMS_SUPABASE_ANON_KEY');

  /// Loads env, syncs [dotenv], and populates [startupIssues].
  static Future<void> load() async {
    _loadError = null;
    _startupIssues = const [];
    _resolved = const {};

    try {
      final release = kReleaseMode;
      final fromDefines = _fromDartDefines();
      final includeGeneratedDebug = !release &&
          (kIsWeb ||
              defaultTargetPlatform == TargetPlatform.android ||
              defaultTargetPlatform == TargetPlatform.iOS);
      final fromAssets = await KpmsBundledEnvReader.loadMerged(
        releaseMode: release,
        includeGeneratedDebug: includeGeneratedDebug,
      );
      final fromRoot = await _fromProjectRoot(release);

      final hadDartDefines = _definesPresent(fromDefines);
      final hadBundledKeys = _mapHasSupabaseKeys(fromAssets);
      final hadIoRoot = fromRoot.isNotEmpty;

      // Merge order (later wins): IO root → bundled → dart-define.
      var merged = <String, String>{};
      merged = KpmsEnvParser.merge(merged, fromRoot);
      merged = KpmsEnvParser.merge(merged, fromAssets);
      merged = KpmsEnvParser.merge(merged, fromDefines);
      _resolved = merged;

      final envString = merged.entries.map((e) => '${e.key}=${e.value}').join('\n');
      dotenv.loadFromString(envString: envString, isOptional: true);

      _startupIssues = _validateIssues();

      KpmsEnvDiagnostics.logAfterEnvLoad(
        releaseMode: release,
        hadDartDefines: hadDartDefines,
        hadBundledSupabaseKeys: hadBundledKeys,
        hadIoRootLayer: hadIoRoot,
        loadedGeneratedDebugAsset: includeGeneratedDebug,
      );
    } catch (e, st) {
      _loadError = '$e';
      if (kDebugMode) {
        debugPrint('[kpms] KpmsEnvironment.load failed: $e\n$st');
      }
      _startupIssues = ['Environment load failed: $e'];
    }
  }

  static Map<String, String> _fromDartDefines() {
    const url = String.fromEnvironment('SUPABASE_URL', defaultValue: '');
    const anon = String.fromEnvironment('SUPABASE_ANON_KEY', defaultValue: '');
    const urlAlt = String.fromEnvironment('KPMS_SUPABASE_URL', defaultValue: '');
    const anonAlt = String.fromEnvironment('KPMS_SUPABASE_ANON_KEY', defaultValue: '');
    const sentryDsn = String.fromEnvironment('KPMS_SENTRY_DSN', defaultValue: '');
    final m = <String, String>{};
    if (url.isNotEmpty) m['SUPABASE_URL'] = url;
    if (anon.isNotEmpty) m['SUPABASE_ANON_KEY'] = anon;
    if (urlAlt.isNotEmpty) m['KPMS_SUPABASE_URL'] = urlAlt;
    if (anonAlt.isNotEmpty) m['KPMS_SUPABASE_ANON_KEY'] = anonAlt;
    if (sentryDsn.isNotEmpty) m['KPMS_SENTRY_DSN'] = sentryDsn;
    return m;
  }

  /// Optional Sentry DSN (public ingest endpoint). Prefer `--dart-define=KPMS_SENTRY_DSN=...` in CI.
  static String? get sentryDsn => _firstNonEmpty(['KPMS_SENTRY_DSN', 'SENTRY_DSN']);

  static Future<Map<String, String>> _fromProjectRoot(bool release) async {
    final raw = await env_io.readRootEnvLayer(release);
    if (raw == null || raw.trim().isEmpty) return {};
    return KpmsEnvParser.stripEmpty(KpmsEnvParser.parse(raw));
  }

  static String? _firstNonEmpty(List<String> keys) {
    for (final k in keys) {
      final v = _resolved[k]?.trim();
      if (v != null && v.isNotEmpty) return v;
    }
    return null;
  }

  static List<String> _validateIssues() {
    final issues = <String>[];
    final url = supabaseUrl;
    final anon = supabaseAnonKey;

    if ((url ?? '').isEmpty) {
      issues.add('Missing SUPABASE_URL. For release APK, set real values in assets/env/default.env or CI dart-define.');
    } else if (KpmsEnvPlaceholders.looksLikePlaceholderUrl(url)) {
      issues.add('SUPABASE_URL looks like a placeholder — replace in assets/env/default.env.');
    }

    if ((anon ?? '').isEmpty) {
      issues.add('Missing SUPABASE_ANON_KEY (anon/public key only).');
    } else if (KpmsEnvPlaceholders.looksLikePlaceholderAnon(anon)) {
      issues.add('SUPABASE_ANON_KEY looks like a placeholder — replace in assets/env/default.env.');
    }

    for (final e in _resolved.entries) {
      final k = e.key.toUpperCase();
      if (k.contains('SERVICE_ROLE') || k.contains('SERVICE_ROLE_KEY')) {
        issues.add('Remove SERVICE_ROLE keys from client configuration.');
      }
    }
    return issues;
  }
}
