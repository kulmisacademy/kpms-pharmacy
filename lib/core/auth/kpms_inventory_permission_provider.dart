import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'permission_providers.dart';
import 'staff_feature_access.dart';

/// True when the user may add, edit, or delete medicines (inventory management).
final kpmsCanManageInventoryProvider = Provider<bool>((ref) {
  final p = ref.watch(kpmsPermissionContextProvider).valueOrNull;
  if (p == null) return false;
  if (p.isPharmacyAdminTier || p.isPlatformSuperAdmin) return true;
  return p.features.canManageInventory;
});

extension StaffFeatureAccessInventory on StaffFeatureAccess {
  bool get canManageInventory => canAccessRoute('/app/medicines/add');
}
