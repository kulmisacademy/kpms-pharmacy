import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/permission_providers.dart';
import '../../enterprise/application/pharmacy_enterprise_bootstrap.dart';
import '../../../providers/pharmacy_local_workspace.dart';

/// Starts workspace + enterprise bootstrap only after auth and tenant are resolved.
/// Avoids full cloud pull on splash/login/public routes.
class PharmacyWorkspaceBootstrapHost extends ConsumerWidget {
  const PharmacyWorkspaceBootstrapHost({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = ref.watch(supabaseAuthUserIdProvider).valueOrNull;
    final tenantId = ref.watch(kpmsActiveTenantIdProvider).valueOrNull;

    if (uid != null && tenantId != null && tenantId.isNotEmpty) {
      ref.watch(pharmacyWorkspaceBootstrapProvider);
      ref.watch(pharmacyEnterpriseBootstrapProvider);
    }

    return child;
  }
}
