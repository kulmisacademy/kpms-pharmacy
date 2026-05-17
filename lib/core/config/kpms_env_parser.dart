/// Minimal `.env` line parser (no shell expansion). Later duplicate keys override earlier ones.
abstract final class KpmsEnvParser {
  static Map<String, String> stripEmpty(Map<String, String> m) =>
      Map.fromEntries(m.entries.where((e) => e.value.trim().isNotEmpty));

  static Map<String, String> parse(String raw) {
    final m = <String, String>{};
    for (final line in raw.split(RegExp(r'\r?\n'))) {
      final t = line.trim();
      if (t.isEmpty || t.startsWith('#')) continue;
      final i = t.indexOf('=');
      if (i <= 0) continue;
      final k = t.substring(0, i).trim();
      if (k.isEmpty) continue;
      var v = t.substring(i + 1).trim();
      if (v.startsWith('"') && v.endsWith('"') && v.length >= 2) {
        v = v.substring(1, v.length - 1);
      } else if (v.startsWith("'") && v.endsWith("'") && v.length >= 2) {
        v = v.substring(1, v.length - 1);
      }
      m[k] = v;
    }
    return m;
  }

  static Map<String, String> merge(Map<String, String> base, Map<String, String> overlay) {
    return {...base, ...overlay};
  }
}
