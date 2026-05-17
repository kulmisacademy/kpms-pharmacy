import 'package:flutter_riverpod/flutter_riverpod.dart';

final customFormLabelsProvider =
    StateNotifierProvider<CustomFormLabelsNotifier, Set<String>>((ref) {
  return CustomFormLabelsNotifier();
});

class CustomFormLabelsNotifier extends StateNotifier<Set<String>> {
  CustomFormLabelsNotifier() : super({});

  void add(String raw) {
    final t = raw.trim();
    if (t.isEmpty) return;
    state = {...state, t};
  }
}
