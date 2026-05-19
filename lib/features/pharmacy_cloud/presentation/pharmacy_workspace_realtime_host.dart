import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/auth/kpms_permission_gate.dart';
import '../../../core/auth/permission_providers.dart';
import '../../../core/notifications/kpms_notification_log.dart';
import '../../../core/notifications/pharmacy_notification_signal_provider.dart';
import '../../../core/staff/kpms_staff_rbac_log.dart';
import '../../../core/supabase/pharmacy_operational_gate.dart';
import '../../../core/supabase/pharmacy_operational_warning_provider.dart';
import '../../../core/supabase/supabase_bootstrap.dart';
import '../../../core/sync/kpms_realtime_log.dart';
import '../../../providers/pharmacy_local_workspace.dart';
import '../application/workspace_realtime_reconciler.dart';

/// Supabase Realtime → in-memory workspace delta patches (no bootstrap reload).
class PharmacyWorkspaceRealtimeHost extends ConsumerStatefulWidget {
  const PharmacyWorkspaceRealtimeHost({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<PharmacyWorkspaceRealtimeHost> createState() => _PharmacyWorkspaceRealtimeHostState();
}

class _PharmacyWorkspaceRealtimeHostState extends ConsumerState<PharmacyWorkspaceRealtimeHost> {
  RealtimeChannel? _channel;
  String? _subscribedTenantId;
  String? _subscribedUserId;
  Object? _subscribeEpoch;

  @override
  void dispose() {
    _teardownChannel();
    super.dispose();
  }

  void _teardownChannel() {
    final tid = _subscribedTenantId ?? '';
    final ch = _channel;
    _channel = null;
    _subscribedTenantId = null;
    _subscribedUserId = null;
    if (ch != null) {
      KpmsRealtimeLog.unsubscribed(tenantId: tid);
      SupabaseBootstrap.clientOrNull?.removeChannel(ch);
    }
  }

  void _onWorkspaceChange(String table, String tenantId, PostgresChangePayload payload) {
    unawaited(
      ref.read(workspaceRealtimeReconcilerProvider).onPostgresChange(
            table: table,
            tenantId: tenantId,
            payload: payload,
          ),
    );
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
    const workspaceTables = [
      'pharmacy_inventory',
      'pharmacy_sales',
      'pharmacy_sale_items',
      'pharmacy_sale_returns',
      'pharmacy_purchases',
      'pharmacy_purchase_items',
      'pharmacy_purchase_returns',
      'pharmacy_customers',
      'pharmacy_suppliers',
      'pharmacy_expenses',
      'pharmacy_medicine_categories',
      'pharmacy_product_barcodes',
    ];

    for (final table in workspaceTables) {
      ch.onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: table,
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'tenant_id',
          value: tenantId,
        ),
        callback: (payload) => _onWorkspaceChange(table, tenantId, payload),
      );
    }

    ch.onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'pharmacy_notifications',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'tenant_id',
        value: tenantId,
      ),
      callback: (_) {
        KpmsNotificationLog.realtimeReceived(table: 'pharmacy_notifications');
        ref.read(pharmacyCloudNotificationSignalProvider.notifier).state++;
      },
    );

    ch.onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'pharmacy_staff_activity',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'tenant_id',
        value: tenantId,
      ),
      callback: (_) {
        KpmsRealtimeLog.eventReceived(
          table: 'pharmacy_staff_activity',
          tenantId: tenantId,
          op: 'INSERT',
        );
      },
    );

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

    KpmsRealtimeLog.subscribed(tenantId: tenantId, tableCount: workspaceTables.length + 5);
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
