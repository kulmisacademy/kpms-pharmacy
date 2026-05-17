import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/pharmacy_enterprise_cloud_repository.dart';
import 'pharmacy_enterprise_sync_service.dart';

final pharmacyEnterpriseCloudRepositoryProvider = Provider<PharmacyEnterpriseCloudRepository>(
  (ref) => const PharmacyEnterpriseCloudRepository(),
);

final pharmacyEnterpriseSyncServiceProvider = Provider<PharmacyEnterpriseSyncService>(
  (ref) => PharmacyEnterpriseSyncService(ref.watch(pharmacyEnterpriseCloudRepositoryProvider)),
);

/// Bump to re-pull enterprise bundle from cloud (realtime).
final pharmacyEnterpriseSyncGenerationProvider = StateProvider<int>((ref) => 0);
