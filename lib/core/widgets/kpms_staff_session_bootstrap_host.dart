import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../device/kpms_device_fingerprint.dart';
import '../tenant/kpms_active_tenant_provider.dart';
import '../../features/staff/application/staff_providers.dart';

/// Registers this install in [pharmacy_staff_device_sessions] once the user has a tenant.
class KpmsStaffSessionBootstrapHost extends ConsumerStatefulWidget {
  const KpmsStaffSessionBootstrapHost({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<KpmsStaffSessionBootstrapHost> createState() => _KpmsStaffSessionBootstrapHostState();
}

class _KpmsStaffSessionBootstrapHostState extends ConsumerState<KpmsStaffSessionBootstrapHost> {
  bool _didRegister = false;

  Future<void> _register() async {
    try {
      final tid = ref.read(kpmsActiveTenantIdProvider).valueOrNull;
      if (tid == null || tid.isEmpty) return;
      final fp = await KpmsDeviceFingerprint.resolve();
      await ref.read(staffRepositoryProvider).registerDeviceSession(deviceId: fp);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(kpmsActiveTenantIdProvider);
    final tid = ref.read(kpmsActiveTenantIdProvider).valueOrNull;
    if (!_didRegister && tid != null && tid.isNotEmpty) {
      _didRegister = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        unawaited(_register());
      });
    }
    return widget.child;
  }
}
