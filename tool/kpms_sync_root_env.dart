// Sync project-root `.env` into `assets/env/generated_debug.env` for targets that
// do not run Android Gradle / Xcode (e.g. `flutter run -d chrome`).
//
// Usage: dart run tool/kpms_sync_root_env.dart
import 'dart:io';

void main() {
  final root = Directory.current;
  final src = File.fromUri(root.uri.resolve('.env'));
  final out = File.fromUri(root.uri.resolve('assets/env/generated_debug.env'));
  if (!src.existsSync()) {
    stderr.writeln('kpms_sync_root_env: no .env next to pubspec (${root.path})');
    exitCode = 1;
    return;
  }
  out.parent.createSync(recursive: true);
  src.copySync(out.path);
  stdout.writeln('kpms_sync_root_env: copied .env → assets/env/generated_debug.env');
}
