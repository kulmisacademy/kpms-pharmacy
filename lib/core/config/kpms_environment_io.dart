import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

/// Reads project-root env files as one string (IO only). Not available on web.
///
/// Concatenation order (later lines win when parsed as a single map):
/// - debug/profile: `.env.development` then `.env`
/// - release: `.env.production` then `.env`
Future<String?> readRootEnvLayer(bool release) async {
  final root = await _findProjectRoot();
  if (root == null) return null;

  final names = <String>[
    if (!release) '.env.development',
    if (release) '.env.production',
    '.env',
  ];

  final sb = StringBuffer();
  for (final n in names) {
    try {
      final file = File(p.join(root.path, n));
      if (await file.exists()) {
        sb.writeln(await file.readAsString());
      }
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('[kpms] Could not read $n: $e\n$st');
      }
    }
  }

  final merged = sb.toString().trim();
  return merged.isEmpty ? null : merged;
}

Future<Directory?> _findProjectRoot() async {
  var d = Directory.current;
  for (var i = 0; i < 20; i++) {
    try {
      if (await File(p.join(d.path, 'pubspec.yaml')).exists()) {
        return d;
      }
    } catch (_) {
      return null;
    }
    final parent = d.parent;
    if (parent.path == d.path) break;
    d = parent;
  }
  return null;
}
