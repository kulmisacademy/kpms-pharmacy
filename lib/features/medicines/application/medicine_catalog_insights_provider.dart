import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/medicine_catalog_notifier.dart';
import 'medicine_catalog_stats.dart';

/// “Expiring soon” window for catalog insights (days).
final medicineCatalogSoonDaysProvider = StateProvider<int>((ref) => 30);

/// Recomputes only when the catalog list or soon-window changes — not on search keystrokes.
final medicineCatalogInsightsProvider = Provider<MedicineCatalogInsights>((ref) {
  final meds = ref.watch(medicineCatalogProvider);
  final soon = ref.watch(medicineCatalogSoonDaysProvider);
  return MedicineCatalogInsights.compute(meds, soonWithinDays: soon);
});
