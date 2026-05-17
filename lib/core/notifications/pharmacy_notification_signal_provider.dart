import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Increment to invalidate notification feed (realtime or local engine).
final pharmacyCloudNotificationSignalProvider = StateProvider<int>((ref) => 0);
