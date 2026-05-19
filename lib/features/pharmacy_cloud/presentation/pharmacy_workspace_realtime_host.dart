import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/auth/kpms_permission_gate.dart';
import '../../../core/auth/permission_providers.dart';
import '../../../core/notifications/kpms_notification_log.dart';
import '../../../core/notifications/pharmacy_notification_signal_provider.dart';
import '../../../core/performance/kpms_performance_log.dart';
import '../../../core/staff/kpms_staff_rbac_log.dart';
import '../../../core/supabase/pharmacy_operational_gate.dart';
import '../../../core/supabase/pharmacy_operational_warning_provider.dart';
import '../../../core/supabase/supabase_bootstrap.dart';
import '../../../core/sync/kpms_realtime_log.dart';
import '../../../core/sync/kpms_sync_log.dart';
import '../../../providers/pharmacy_local_workspace.dart';
import '../../../features/enterprise/application/pharmacy_enterprise_bootstrap.dart';
import '../../../features/enterprise/application/pharmacy_enterprise_providers.dart';
import '../application/pharmacy_cloud_providers.dart';

/// Listens to Supabase Realtime for `pharmacy_*` changes and triggers cloud re-sync.
class PharmacyWorkspaceRealtimeHost extends ConsumerStatefulWidget {
  const PharmacyWorkspaceRealtimeHost({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<PharmacyWorkspaceRealtimeHost> createState() => _PharmacyWorkspaceRealtimeHostState();
}

class _PharmacyWorkspaceRealtimeHostState extends ConsumerState<PharmacyWorkspaceRealtimeHost> {
  RealtimeChannel? _channel;
  Timer? _debounce;
  String? _subscribedTenantId;
  String? _subscribedUserId;
  Object? _subscribeEpoch;

  @override
  void dispose() {
    _teardownChannel();
    super.dispose();
  }

  void _teardownChannel() {
    _debounce?.cancel();
    _debounce = null;
    final ch = _channel;
    _channel = null;
    _subscribedTenantId = null;
    _subscribedUserId = null;
    if (ch != null) {
      KpmsRealtimeLog.unsubscribed(tenantId: _subscribedTenantId ?? '');
      SupabaseBootstrap.clientOrNull?.removeChannel(ch);
    }
  }

  static const _enterpriseOnlyTables = {
    'pharmacy_expenses',
    'pharmacy_medicine_categories',
    'pharmacy_product_barcodes',
  };

  void _scheduleResync(String table, String tenantId) {
    KpmsSyncLog.realtimeEvent(table);
    KpmsRealtimeLog.realtimeReceived(table: table, tenantId: tenantId);
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 900), () {
      if (!mounted) return;
      KpmsPerformanceLog.realtimeBatched(channel: 'kpms_workspace', debounceMs: 900);
      KpmsRealtimeLog.workspaceRefreshScheduled(tenantId: tenantId, triggerTable: table);
      if (_enterpriseOnlyTables.contains(table)) {
        ref.read(pharmacyEnterpriseSyncGenerationProvider.notifier).state++;
        ref.invalidate(pharmacyEnterpriseBootstrapProvider);
        return;
      }
      ref.read(pharmacyCloudSyncGenerationProvider.notifier).state++;
      ref.read(pharmacyWorkspaceBootstrapReadyProvider.notifier).state = false;
      ref.invalidate(pharmacyWorkspaceBootstrapProvider);
    });
  }

  void _subscribe(String tenantId, String userId) {
    final client = SupabaseBootstrap.clientOrNull;
    if (client == null) return;
    if (_channel != null &&
        _subscribedTenantId == tenantId &&
        _subscribedUserId == userId) {
      return;
    }
    _teardownChannel();

    final ch = client.channel('kpms_workspace_$tenantId');
    for (final table in [
      'pharmacy_inventory',
      'pharmacy_sales',
      'pharmacy_purchases',
      'pharmacy_customers',
      'pharmacy_suppliers',
      'pharmacy_sale_returns',
      'pharmacy_notifications',
      'pharmacy_expenses',
      'pharmacy_medicine_categories',
      'pharmacy_product_barcodes',
    ]) {
      ch.onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: table,
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'tenant_id',
          value: tenantId,
        ),
        callback: (payload) {
          if (table == 'pharmacy_notifications') {
            KpmsNotificationLog.realtimeReceived(table: table);
            ref.read(pharmacyCloudNotificationSignalProvider.notifier).state++;
            return;
          }
          _scheduleResync(table, tenantId);
        },
      );
    }
    ch.onPostgresChanges(
      event: PostgresChangeEvent.update,
      schema: 'public',
      table: 'profiles',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'id',
        value: userId,
      ),
      callback: (_) {
        KpmsStaffRbacLog.permissionUpdated(staffId: userId);
        KpmsPermissionGate.invalidate();
        ref.invalidate(kpmsPermissionContextProvider);
      },
    );
    ch.onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'tenants',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'id',
        value: tenantId,
      ),
      callback: (_) {
        PharmacyOperationalGate.invalidate();
        ref.invalidate(pharmacySubscriptionBannerProvider);
      },
    );
    ch.onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'subscriptions',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'tenant_id',
        value: tenantId,
      ),
      callback: (_) {
        PharmacyOperationalGate.invalidate();
        ref.invalidate(pharmacySubscriptionBannerProvider);
      },
    );
    KpmsRealtimeLog.subscribed(tenantId: tenantId, tableCount: 13);
    ch.subscribe();
    _channel = ch;
    _subscribedTenantId = tenantId;
    _subscribedUserId = userId;
  }

  @override
  Widget build(BuildContext context) {
    final tenantId = ref.watch(kpmsActiveTenantIdProvider).valueOrNull;
    final userId = ref.watch(supabaseAuthUserIdProvider).valueOrNull;

    if (tenantId == null || tenantId.isEmpty || userId == null || userId.isEmpty) {
      if (_channel != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _teardownChannel();
        });
      }
    } else if (_subscribedTenantId != tenantId || _subscribedUserId != userId) {
      final epoch = Object();
      _subscribeEpoch = epoch;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _subscribeEpoch != epoch) return;
        if (tenantId.isEmpty || userId.isEmpty) return;
        _subscribe(tenantId, userId);
      });
    }

    return widget.child;
  }
}
