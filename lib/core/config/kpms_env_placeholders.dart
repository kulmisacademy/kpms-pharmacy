/// Detects obvious non-production placeholders in bundled env (still anon-safe checks).
abstract final class KpmsEnvPlaceholders {
  static bool looksLikePlaceholderUrl(String? url) {
    if (url == null) return true;
    final u = url.trim().toLowerCase();
    if (u.isEmpty) return true;
    return u.contains('yourproject') ||
        u.contains('your_project') ||
        u.contains('replace_me') ||
        u.contains('xxx.') ||
        u.endsWith('.invalid') ||
        u.contains('example.com');
  }

  static bool looksLikePlaceholderAnon(String? key) {
    if (key == null) return true;
    final k = key.trim().toLowerCase();
    if (k.isEmpty) return true;
    return k.contains('your_anon') ||
        k.contains('replace') ||
        k == 'configure_anon_key_in_default_env';
  }
}
