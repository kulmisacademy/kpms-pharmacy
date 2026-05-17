import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/staff_repository.dart';
import '../domain/staff_member.dart';

final staffRepositoryProvider = Provider<StaffRepository>((ref) => const StaffRepository());

final tenantStaffListProvider = FutureProvider<List<StaffMember>>((ref) async {
  return ref.watch(staffRepositoryProvider).listTenantStaff();
});
