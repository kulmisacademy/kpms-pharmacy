import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:kpms/app.dart';

void main() {
  testWidgets('App starts (Supabase setup screen without dart-defines)', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: KpmsApp()));
    await tester.pump();
    expect(find.textContaining('Supabase'), findsWidgets);
  });
}
