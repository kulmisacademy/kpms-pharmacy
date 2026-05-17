import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/constants/app_prefs_keys.dart';

final posAutoAddAfterScanProvider =
    AsyncNotifierProvider<PosAutoAddAfterScanNotifier, bool>(PosAutoAddAfterScanNotifier.new);

class PosAutoAddAfterScanNotifier extends AsyncNotifier<bool> {
  @override
  Future<bool> build() async {
    final p = await SharedPreferences.getInstance();
    return p.getBool(AppPrefsKeys.posAutoAddAfterBarcodeScan) ?? true;
  }

  Future<void> setAutoAdd(bool value) async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(AppPrefsKeys.posAutoAddAfterBarcodeScan, value);
    state = AsyncData(value);
  }
}
