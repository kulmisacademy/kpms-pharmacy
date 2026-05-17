import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/permission_providers.dart';
import '../../../core/tenant/kpms_active_tenant_provider.dart';
import '../../../core/tenant/pharmacy_workspace_isolation.dart';
import '../../../core/supabase/pharmacy_operational_gate.dart';
import '../../../core/supabase/supabase_bootstrap.dart';
import '../../../core/sync/outbox/kpms_sync_outbox_service.dart';
import '../../../core/notifications/pharmacy_notification_signal_provider.dart';
import '../../analytics/application/sales_analytics_notifier.dart';
import '../../medicines/data/medicine_catalog_notifier.dart';
import '../../sales/application/sales_ledger_notifier.dart';
import '../../settings/application/pharmacy_settings_providers.dart';
import '../../subscriptions/application/tenant_subscription_providers.dart';
import '../../suppliers/application/suppliers_notifier.dart';
import '../data/pharmacy_notification_repository.dart';
import '../domain/pharmacy_notification_models.dart';

/// Evaluates local operational state and upserts deduped rows into `pharmacy_notifications`.
abstract final class KpmsOperationalNotificationEngine {
  KpmsOperationalNotificationEngine._();

  static const _refundThreshold = 500.0;

  static Future<void> run(WidgetRef ref) async {
    final client = SupabaseBootstrap.clientOrNull;
    if (client == null) return;

    final tid = ref.read(kpmsActiveTenantIdProvider).valueOrNull?.trim();
    final uid = ref.read(supabaseAuthUserIdProvider).valueOrNull;
    final loaded = ref.read(kpmsLoadedWorkspaceTenantProvider);
    if (tid == null || tid.isEmpty || uid == null) return;
    if (loaded != null && loaded != tid) return;

    final session = ref.read(pharmacySessionProvider).valueOrNull;
    final tenant = session?.tenant;
    if (tenant == null) return;

    final perm = ref.read(kpmsPermissionContextProvider).valueOrNull;
    final isAdmin = perm?.isPharmacyAdminTier == true;

    // Low stock
    if (tenant.notifLowStock) {
      for (final m in ref.read(medicineCatalogProvider)) {
        if (!m.isLowStock) continue;
        await PharmacyNotificationRepository.upsertOperational(
          tenantId: tid,
          userId: uid,
          kind: KpmsNotificationKind.lowStock,
          title: 'Low stock: ${m.name}',
          body: 'Qty ${m.quantity} · threshold ${m.minimumStockAlert}',
          dedupeKey: 'low_stock:${m.id}',
          priority: m.quantity == 0 ? 'high' : 'normal',
          payload: {
            'medicine_id': m.id,
            'quantity': m.quantity,
            'threshold': m.minimumStockAlert,
          },
        );
      }
    }

    // Expiry
    if (tenant.notifExpiry) {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      for (final m in ref.read(medicineCatalogProvider)) {
        final e = m.expiryDate;
        if (e == null) continue;
        final d0 = DateTime(e.year, e.month, e.day);
        final days = d0.difference(today).inDays;
        if (days < 0) {
          await PharmacyNotificationRepository.upsertOperational(
            tenantId: tid,
            userId: uid,
            kind: KpmsNotificationKind.expiryExpired,
            title: 'Expired: ${m.name}',
            body: 'Expiry was ${d0.toIso8601String().split('T').first}',
            dedupeKey: 'expiry_exp:${m.id}',
            priority: 'critical',
            payload: {'medicine_id': m.id, 'expiry': d0.toIso8601String()},
          );
        } else if (days <= 7) {
          await PharmacyNotificationRepository.upsertOperational(
            tenantId: tid,
            userId: uid,
            kind: KpmsNotificationKind.expirySoon7,
            title: 'Expires in ≤7d: ${m.name}',
            body: '$days day(s) · qty ${m.quantity}',
            dedupeKey: 'expiry_7:${m.id}',
            priority: 'high',
            payload: {'medicine_id': m.id, 'days': days},
          );
        } else if (days <= 30) {
          await PharmacyNotificationRepository.upsertOperational(
            tenantId: tid,
            userId: uid,
            kind: KpmsNotificationKind.expirySoon30,
            title: 'Expires in ≤30d: ${m.name}',
            body: '$days day(s) · qty ${m.quantity}',
            dedupeKey: 'expiry_30:${m.id}',
            priority: 'normal',
            payload: {'medicine_id': m.id, 'days': days},
          );
        }
      }
    }

    // Debt: customers (invoice-level)
    if (tenant.notifDebt) {
      final stale = DateTime.now().subtract(const Duration(days: 30));
      for (final inv in ref.read(salesLedgerProvider).invoices) {
        if (!inv.hasOpenDebt) continue;
        if (!inv.issuedAt.isBefore(stale)) continue;
        await PharmacyNotificationRepository.upsertOperational(
          tenantId: tid,
          userId: uid,
          kind: KpmsNotificationKind.debtCustomerOverdue,
          title: 'Overdue balance: ${inv.customerName}',
          body: 'Open ${_money(inv.remainingBalance)} · ${_fmt(inv.issuedAt)}',
          dedupeKey: 'debt_cust:${inv.invoiceNumber}',
          priority: 'high',
          payload: {
            'invoice': inv.invoiceNumber,
            'balance': inv.remainingBalance,
          },
        );
      }
      for (final s in ref.read(suppliersProvider)) {
        if (s.balanceOwed <= 0.009) continue;
        await PharmacyNotificationRepository.upsertOperational(
          tenantId: tid,
          userId: uid,
          kind: KpmsNotificationKind.debtSupplierOverdue,
          title: 'Supplier AP: ${s.name}',
          body: 'Balance owed ${_money(s.balanceOwed)}',
          dedupeKey: 'debt_sup:${s.id}',
          priority: 'normal',
          payload: {'supplier_id': s.id, 'balance': s.balanceOwed},
        );
      }
    }

    // Sync outbox
    final failed = await KpmsSyncOutboxService.failedCountForTenant(tid);
    final pending = await KpmsSyncOutboxService.pendingCountForTenant(tid);
    if (failed > 0) {
      await PharmacyNotificationRepository.upsertOperational(
        tenantId: tid,
        userId: uid,
        kind: KpmsNotificationKind.syncFailed,
        title: 'Cloud sync needs attention',
        body: '$failed item(s) failed after retries · review sync status',
        dedupeKey: 'sync_failed',
        priority: 'high',
        payload: {'failed': failed, 'pending': pending},
      );
    } else if (pending > 12) {
      await PharmacyNotificationRepository.upsertOperational(
        tenantId: tid,
        userId: uid,
        kind: KpmsNotificationKind.syncBacklog,
        title: 'Sync queue backlog',
        body: '$pending operations pending upload',
        dedupeKey: 'sync_backlog',
        priority: 'normal',
        payload: {'pending': pending},
      );
    }

    // Subscription (lightweight parse)
    final sub = ref.read(myTenantSubscriptionProvider).valueOrNull;
    if (sub != null && isAdmin) {
      final exp = sub['expires_at'];
      final status = '${sub['status'] ?? ''}';
      final pay = '${sub['payment_status'] ?? ''}';
      if (exp != null) {
        final expAt = DateTime.tryParse('$exp');
        if (expAt != null) {
          final days = expAt.difference(DateTime.now()).inDays;
          if (days <= 14 && days >= 0) {
            await PharmacyNotificationRepository.upsertOperational(
              tenantId: tid,
              userId: uid,
              kind: KpmsNotificationKind.subscriptionWarning,
              title: 'Subscription renewing soon',
              body: '${days}d until period end · status $status',
              dedupeKey: 'sub_warn',
              priority: days <= 3 ? 'high' : 'normal',
              payload: {'days': days, 'status': status},
            );
          }
        }
      }
      if (pay == 'past_due' || pay == 'unpaid') {
        await PharmacyNotificationRepository.upsertOperational(
          tenantId: tid,
          userId: uid,
          kind: KpmsNotificationKind.subscriptionWarning,
          title: 'Subscription payment due',
          body: 'Payment status: $pay',
          dedupeKey: 'sub_payment',
          priority: 'critical',
          payload: {'status': status, 'payment_status': pay},
        );
      }
    }

    // Operational gate (suspension hints — non-blocking UX copy)
    final gate = await PharmacyOperationalGate.resolve(client, uid);
    if (gate.blocked && gate.message != null && gate.message!.isNotEmpty && isAdmin) {
      await PharmacyNotificationRepository.upsertOperational(
        tenantId: tid,
        userId: uid,
        kind: KpmsNotificationKind.subscriptionWarning,
        title: 'Pharmacy access notice',
        body: gate.message!,
        dedupeKey: 'op_gate:${gate.reason ?? 'general'}',
        priority: gate.blocked ? 'critical' : 'normal',
        payload: {'reason': gate.reason, 'blocked': gate.blocked},
      );
    }

    // Large refunds (admin)
    if (isAdmin) {
      for (final r in ref.read(salesLedgerProvider).returns) {
        if (r.refundTotal < _refundThreshold) continue;
        await PharmacyNotificationRepository.upsertOperational(
          tenantId: tid,
          userId: uid,
          kind: KpmsNotificationKind.staffLargeRefund,
          title: 'Large refund recorded',
          body: '${r.returnInvoiceNumber} · ${_money(r.refundTotal)}',
          dedupeKey: 'lg_refund:${r.returnInvoiceNumber}',
          priority: 'high',
          payload: {
            'return': r.returnInvoiceNumber,
            'refund': r.refundTotal,
            'cashier': r.cashierName,
          },
        );
      }
    }

    // Sales milestone (session daily vs month profit heuristic)
    final analytics = ref.read(salesAnalyticsProvider);
    if (analytics.dailyTotal >= 1000 && analytics.monthlyTotal > 0) {
      final ratio = analytics.dailyTotal / (analytics.monthlyTotal / 30 + 1);
      if (ratio >= 1.8) {
        await PharmacyNotificationRepository.upsertOperational(
          tenantId: tid,
          userId: uid,
          kind: KpmsNotificationKind.salesMilestone,
          title: 'Strong sales day',
          body: 'Today ${_money(analytics.dailyTotal)} vs monthly trend',
          dedupeKey: 'sales_spike:${DateTime.now().toIso8601String().split('T').first}',
          priority: 'normal',
          payload: {'daily': analytics.dailyTotal, 'monthly': analytics.monthlyTotal},
        );
      }
    }

    ref.read(pharmacyCloudNotificationSignalProvider.notifier).state++;
  }

  static String _money(double n) => n.toStringAsFixed(2);

  static String _fmt(DateTime d) => d.toIso8601String().split('T').first;
}
