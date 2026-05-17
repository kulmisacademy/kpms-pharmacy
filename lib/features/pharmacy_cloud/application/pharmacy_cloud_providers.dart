import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/pharmacy_cloud_repository.dart';
import 'pharmacy_workspace_sync_service.dart';

final pharmacyCloudRepositoryProvider = Provider<PharmacyCloudRepository>(
  (ref) => const PharmacyCloudRepository(),
);

final pharmacyWorkspaceSyncServiceProvider = Provider<PharmacyWorkspaceSyncService>(
  (ref) => PharmacyWorkspaceSyncService(ref.watch(pharmacyCloudRepositoryProvider)),
);

/// Increment to trigger workspace re-pull from cloud (e.g. after realtime event).
final pharmacyCloudSyncGenerationProvider = StateProvider<int>((ref) => 0);
