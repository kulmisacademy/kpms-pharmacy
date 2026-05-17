import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'kpms_env_parser.dart';

/// Reads layered `.env` content from Flutter assets (bundled at build time).
///
/// Last layer `generated_debug.env` is overwritten on **Android/iOS Debug** builds from
/// project-root `.env`, and replaced with a placeholder for release/profile store builds.
abstract final class KpmsBundledEnvReader {
  /// [includeGeneratedDebug]: **false** for release builds and desktop — skips `generated_debug.env`
  /// so release APK uses only `default.env` + `production.env` (+ defines). **true** for debug mobile/web.
  static Future<Map<String, String>> loadMerged({
    required bool releaseMode,
    required bool includeGeneratedDebug,
  }) async {
    final layers = <String>[
      'assets/env/default.env',
      if (releaseMode) 'assets/env/production.env' else 'assets/env/development.env',
      if (includeGeneratedDebug) 'assets/env/generated_debug.env',
    ];

    var merged = <String, String>{};
    for (final path in layers) {
      try {
        final raw = await rootBundle.loadString(path);
        merged = KpmsEnvParser.merge(merged, KpmsEnvParser.stripEmpty(KpmsEnvParser.parse(raw)));
      } catch (e) {
        if (kDebugMode) {
          debugPrint('[kpms] Optional bundled env missing or unreadable: $path ($e)');
        }
      }
    }
    return merged;
  }
}
