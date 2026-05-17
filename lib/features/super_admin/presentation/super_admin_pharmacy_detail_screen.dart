import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_routes.dart';
import '../../../core/utils/kpms_feedback.dart';
import '../../../core/widgets/kpms_platform_admin_shell.dart';
import '../application/platform_admin_providers.dart';

/// Operator detail for one pharmacy: edit, suspend, subscription, archive/delete.
class SuperAdminPharmacyDetailScreen extends ConsumerWidget {
  const SuperAdminPharmacyDetailScreen({super.key, required this.tenantId});

  final String tenantId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(superAdminPharmacyDetailProvider(tenantId));
    final plansAsync = ref.watch(superAdminPlansProvider);

    return async.when(
      loading: () => const KpmsPlatformAdminShell(title: 'Pharmacy', subtitle: 'Loading…', body: Center(child: CircularProgressIndicator())),
      error: (e, _) => KpmsPlatformAdminShell(
        title: 'Pharmacy',
        subtitle: 'Error',
        body: Center(child: Text('$e')),
      ),
      data: (bundle) {
        final t = bundle.tenant;
        if (t == null) {
          return KpmsPlatformAdminShell(
            title: 'Pharmacy',
            subtitle: 'Not found',
            body: Center(
              child: FilledButton(
                onPressed: () => context.go(AppRoutes.superAdminPharmacies),
                child: const Text('Back to directory'),
              ),
            ),
          );
        }
        final sub = bundle.subscription;
        final planMap = sub?['subscription_plans'] is Map ? Map<String, dynamic>.from(sub!['subscription_plans'] as Map) : null;
        final statsAsync = ref.watch(_pharmacyStatsProvider(tenantId));

        return KpmsPlatformAdminShell(
          title: t['name']?.toString() ?? 'Pharmacy',
          subtitle: 'Tenant $tenantId',
          actions: [
            IconButton(
              tooltip: 'Refresh',
              onPressed: () {
                ref.invalidate(superAdminPharmacyDetailProvider(tenantId));
                ref.invalidate(superAdminPharmaciesProvider);
              },
              icon: const Icon(Icons.refresh_rounded),
            ),
          ],
          body: ListView(
            padding: const EdgeInsets.only(bottom: 32),
            children: [
              _InfoCard(tenant: t, subscription: sub, planName: planMap?['name']?.toString()),
              statsAsync.when(
                loading: () => const Padding(padding: EdgeInsets.all(16), child: LinearProgressIndicator()),
                error: (Object? err, StackTrace? stack) => const SizedBox.shrink(),
                data: (s) => Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Operational stats',
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 8),
                        Text('Staff: ${s['staff_active'] ?? 0} active · ${s['staff_total'] ?? 0} total'),
                        Text('Sales (30d): ${s['sales_30d'] ?? 0} · Purchases (30d): ${s['purchases_30d'] ?? 0}'),
                        Text('Inventory lines: ${s['inventory_lines'] ?? 0} · Tx rows: ${s['transaction_rows'] ?? 0}'),
                        Text('Storage estimate: ~${s['storage_estimate_mb'] ?? '—'} MB'),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  FilledButton.tonalIcon(
                    icon: const Icon(Icons.edit_rounded),
                    label: const Text('Edit pharmacy'),
                    onPressed: () => _editPharmacy(context, ref, t),
                  ),
                  FilledButton.tonalIcon(
                    icon: const Icon(Icons.block_rounded),
                    label: const Text('Suspend'),
                    onPressed: t['suspended_at'] != null
                        ? null
                        : () => _suspend(context, ref),
                  ),
                  FilledButton.tonalIcon(
                    icon: const Icon(Icons.check_circle_outline_rounded),
                    label: const Text('Reactivate'),
                    onPressed: t['suspended_at'] == null ? null : () => _reactivate(context, ref),
                  ),
                  FilledButton.tonalIcon(
                    icon: const Icon(Icons.archive_outlined),
                    label: const Text('Archive (soft delete)'),
                    onPressed: t['deleted_at'] != null ? null : () => _archive(context, ref),
                  ),
                  FilledButton.tonalIcon(
                    icon: const Icon(Icons.logout_rounded),
                    label: const Text('Force logout staff'),
                    onPressed: t['deleted_at'] != null ? null : () => _forceLogout(context, ref),
                  ),
                  FilledButton.tonalIcon(
                    icon: const Icon(Icons.restart_alt_rounded),
                    label: const Text('Mark account reset'),
                    onPressed: () => _resetFlag(context, ref),
                  ),
                  FilledButton.tonalIcon(
                    style: FilledButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
                    icon: const Icon(Icons.delete_forever_rounded),
                    label: const Text('Delete permanently'),
                    onPressed: () => _hardDelete(context, ref),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Text('Subscription', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              plansAsync.when(
                loading: () => const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator())),
                error: (e, _) => Text('Plans: $e'),
                data: (plans) => _SubscriptionCard(
                  tenantId: tenantId,
                  plans: plans,
                  current: sub,
                  onSaved: () {
                    ref.invalidate(superAdminPharmacyDetailProvider(tenantId));
                    ref.invalidate(superAdminPharmaciesProvider);
                    kpmsSnack(context, 'Subscription updated.');
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _editPharmacy(BuildContext context, WidgetRef ref, Map<String, dynamic> t) async {
    final name = TextEditingController(text: t['name']?.toString() ?? '');
    final address = TextEditingController(text: t['address']?.toString() ?? '');
    final phone = TextEditingController(text: t['phone']?.toString() ?? '');
    final license = TextEditingController(text: t['license_number']?.toString() ?? '');
    final owner = TextEditingController(text: t['owner_name']?.toString() ?? '');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit pharmacy'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: name, decoration: const InputDecoration(labelText: 'Name')),
              TextField(controller: address, decoration: const InputDecoration(labelText: 'Address')),
              TextField(controller: phone, decoration: const InputDecoration(labelText: 'Phone')),
              TextField(controller: license, decoration: const InputDecoration(labelText: 'License')),
              TextField(controller: owner, decoration: const InputDecoration(labelText: 'Owner name')),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
        ],
      ),
    );
    if (ok != true) return;
    if (!context.mounted) return;
    try {
      await ref.read(platformAdminRepositoryProvider).updatePharmacy(
            tenantId: tenantId,
            name: name.text.trim(),
            address: address.text.trim(),
            phone: phone.text.trim(),
            license: license.text.trim(),
            ownerName: owner.text.trim(),
          );
      if (!context.mounted) return;
      ref.invalidate(superAdminPharmacyDetailProvider(tenantId));
      ref.invalidate(superAdminPharmaciesProvider);
      kpmsSnack(context, 'Pharmacy saved.');
    } catch (e) {
      if (!context.mounted) return;
      kpmsSnack(context, '$e', isError: true);
    }
  }

  Future<void> _forceLogout(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Force logout all staff?'),
        content: const Text(
          'Increments a server epoch; pharmacy apps sign out once and must sign in again. '
          'Use for compromise or policy enforcement.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Force logout')),
        ],
      ),
    );
    if (ok != true) return;
    if (!context.mounted) return;
    try {
      await ref.read(platformAdminRepositoryProvider).forceLogoutTenant(tenantId);
      if (!context.mounted) return;
      kpmsSnack(context, 'Force logout issued. Devices refresh on next operational check.');
    } catch (e) {
      if (!context.mounted) return;
      kpmsSnack(context, '$e', isError: true);
    }
  }

  Future<void> _suspend(BuildContext context, WidgetRef ref) async {
    final reason = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Suspend pharmacy'),
        content: TextField(
          controller: reason,
          decoration: const InputDecoration(labelText: 'Reason (optional)', border: OutlineInputBorder()),
          maxLines: 3,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Suspend')),
        ],
      ),
    );
    if (ok != true) return;
    if (!context.mounted) return;
    try {
      await ref.read(platformAdminRepositoryProvider).suspendPharmacy(tenantId, reason.text.trim());
      if (!context.mounted) return;
      ref.invalidate(superAdminPharmacyDetailProvider(tenantId));
      ref.invalidate(superAdminPharmaciesProvider);
      kpmsSnack(context, 'Pharmacy suspended. Staff sign-in is blocked.');
    } catch (e) {
      if (!context.mounted) return;
      kpmsSnack(context, '$e', isError: true);
    }
  }

  Future<void> _reactivate(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reactivate pharmacy'),
        content: const Text('Staff will regain access (subject to subscription status).'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Reactivate')),
        ],
      ),
    );
    if (ok != true) return;
    if (!context.mounted) return;
    try {
      await ref.read(platformAdminRepositoryProvider).reactivatePharmacy(tenantId);
      if (!context.mounted) return;
      ref.invalidate(superAdminPharmacyDetailProvider(tenantId));
      ref.invalidate(superAdminPharmaciesProvider);
      kpmsSnack(context, 'Pharmacy reactivated.');
    } catch (e) {
      if (!context.mounted) return;
      kpmsSnack(context, '$e', isError: true);
    }
  }

  Future<void> _archive(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Archive pharmacy?'),
        content: const Text(
          'Soft-deletes the tenant for the directory. Linked staff lose tenant visibility. This is reversible only by support (DB restore).',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Archive')),
        ],
      ),
    );
    if (ok != true) return;
    if (!context.mounted) return;
    try {
      await ref.read(platformAdminRepositoryProvider).archivePharmacy(tenantId);
      if (!context.mounted) return;
      ref.invalidate(superAdminPharmaciesProvider);
      kpmsSnack(context, 'Pharmacy archived.');
      context.go(AppRoutes.superAdminPharmacies);
    } catch (e) {
      if (!context.mounted) return;
      kpmsSnack(context, '$e', isError: true);
    }
  }

  Future<void> _resetFlag(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Mark account for reset?'),
        content: const Text('Flags the tenant for support follow-up. Does not change passwords automatically.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Confirm')),
        ],
      ),
    );
    if (ok != true) return;
    if (!context.mounted) return;
    try {
      await ref.read(platformAdminRepositoryProvider).resetPharmacyAccount(tenantId);
      if (!context.mounted) return;
      kpmsSnack(context, 'Reset flag recorded.');
    } catch (e) {
      if (!context.mounted) return;
      kpmsSnack(context, '$e', isError: true);
    }
  }

  Future<void> _hardDelete(BuildContext context, WidgetRef ref) async {
    final confirm = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Permanent deletion'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'This removes the tenant row and cascades related data. Type DELETE to confirm.',
              style: TextStyle(color: Theme.of(ctx).colorScheme.error, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: confirm,
              decoration: const InputDecoration(labelText: 'Type DELETE', border: OutlineInputBorder()),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Theme.of(ctx).colorScheme.error),
            onPressed: () => Navigator.pop(ctx, confirm.text.trim() == 'DELETE'),
            child: const Text('Delete forever'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    if (!context.mounted) return;
    try {
      await ref.read(platformAdminRepositoryProvider).deletePharmacyHard(tenantId);
      if (!context.mounted) return;
      ref.invalidate(superAdminPharmaciesProvider);
      kpmsSnack(context, 'Tenant deleted.');
      context.go(AppRoutes.superAdminPharmacies);
    } catch (e) {
      if (!context.mounted) return;
      kpmsSnack(context, '$e', isError: true);
    }
  }
}

final _pharmacyStatsProvider = FutureProvider.autoDispose.family<Map<String, dynamic>, String>((ref, tenantId) async {
  return ref.read(platformAdminRepositoryProvider).pharmacyStats(tenantId);
});

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.tenant, this.subscription, this.planName});

  final Map<String, dynamic> tenant;
  final Map<String, dynamic>? subscription;
  final String? planName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final suspended = tenant['suspended_at'] != null;
    final archived = tenant['deleted_at'] != null;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (archived) Chip(label: const Text('Archived'), backgroundColor: theme.colorScheme.errorContainer),
                if (suspended && !archived) Chip(label: const Text('Suspended'), backgroundColor: theme.colorScheme.tertiaryContainer),
                if (!suspended && !archived) Chip(label: const Text('Active'), backgroundColor: theme.colorScheme.primaryContainer),
              ],
            ),
            const SizedBox(height: 12),
            _line('Phone', tenant['phone']?.toString()),
            _line('Owner', tenant['owner_name']?.toString()),
            _line('Created', tenant['created_at']?.toString()),
            _line('Last activity', tenant['last_activity_at']?.toString() ?? '—'),
            _line('Plan', planName ?? subscription?['plan']?.toString() ?? '—'),
            _line('Subscription status', subscription?['status']?.toString() ?? '—'),
            _line('Expires', subscription?['expires_at']?.toString() ?? '—'),
            _line('Payment', subscription?['payment_status']?.toString() ?? '—'),
            _line('Billing', subscription?['billing_interval']?.toString() ?? '—'),
            _line('Grace until', subscription?['grace_ends_at']?.toString() ?? '—'),
          ],
        ),
      ),
    );
  }

  Widget _line(String k, String? v) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: 140, child: Text(k, style: const TextStyle(fontWeight: FontWeight.w600))),
            Expanded(child: Text(v ?? '—')),
          ],
        ),
      );
}

class _SubscriptionCard extends ConsumerStatefulWidget {
  const _SubscriptionCard({
    required this.tenantId,
    required this.plans,
    required this.current,
    required this.onSaved,
  });

  final String tenantId;
  final List<Map<String, dynamic>> plans;
  final Map<String, dynamic>? current;
  final VoidCallback onSaved;

  @override
  ConsumerState<_SubscriptionCard> createState() => _SubscriptionCardState();
}

class _SubscriptionCardState extends ConsumerState<_SubscriptionCard> {
  String? _planId;
  DateTime? _expires;
  DateTime? _graceEnds;
  String _billing = 'monthly';
  String _payment = 'current';
  String _status = 'active';

  @override
  void initState() {
    super.initState();
    final c = widget.current;
    _planId = c?['plan_id']?.toString();
    final ex = c?['expires_at'];
    if (ex is String) {
      _expires = DateTime.tryParse(ex)?.toUtc();
    }
    final g = c?['grace_ends_at'];
    if (g is String) {
      _graceEnds = DateTime.tryParse(g)?.toUtc();
    }
    final bi = (c?['billing_interval'] as String?)?.trim();
    if (bi == 'yearly' || bi == 'trial' || bi == 'monthly') {
      _billing = bi!;
    }
    _payment = (c?['payment_status'] as String?)?.trim().isNotEmpty == true ? c!['payment_status'] as String : 'current';
    _status = (c?['status'] as String?)?.trim().isNotEmpty == true ? c!['status'] as String : 'active';
  }

  @override
  Widget build(BuildContext context) {
    final activePlans = widget.plans.where((p) => p['is_active'] == true).toList();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Controlled selection; `initialValue` does not follow setState updates.
            DropdownButtonFormField<String>(
              // ignore: deprecated_member_use
              value: () {
                if (_planId != null && activePlans.any((p) => p['id']?.toString() == _planId)) return _planId;
                if (activePlans.isEmpty) return null;
                return activePlans.first['id']?.toString();
              }(),
              decoration: const InputDecoration(labelText: 'Plan', border: OutlineInputBorder()),
              items: activePlans
                  .map(
                    (p) => DropdownMenuItem(
                      value: p['id']?.toString(),
                      child: Text('${p['name']} (${(p['monthly_price_cents'] as num? ?? 0) / 100} / mo)'),
                    ),
                  )
                  .toList(),
              onChanged: (v) => setState(() => _planId = v),
            ),
            const SizedBox(height: 12),
            ListTile(
              title: Text(_expires == null ? 'No expiry' : 'Expires ${_expires!.toLocal()}'),
              trailing: TextButton(
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _expires ?? DateTime.now().add(const Duration(days: 30)),
                    firstDate: DateTime.now().subtract(const Duration(days: 1)),
                    lastDate: DateTime.now().add(const Duration(days: 3650)),
                  );
                  if (picked != null) setState(() => _expires = picked);
                },
                child: const Text('Pick date'),
              ),
            ),
            TextButton(onPressed: () => setState(() => _expires = null), child: const Text('Clear expiry')),
            const SizedBox(height: 12),
            ListTile(
              title: Text(_graceEnds == null ? 'No grace end' : 'Grace until ${_graceEnds!.toLocal()}'),
              trailing: TextButton(
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _graceEnds ?? DateTime.now().add(const Duration(days: 7)),
                    firstDate: DateTime.now().subtract(const Duration(days: 1)),
                    lastDate: DateTime.now().add(const Duration(days: 3650)),
                  );
                  if (picked != null) setState(() => _graceEnds = picked);
                },
                child: const Text('Pick grace'),
              ),
            ),
            TextButton(onPressed: () => setState(() => _graceEnds = null), child: const Text('Clear grace')),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              key: ValueKey(_billing),
              initialValue: _billing,
              decoration: const InputDecoration(labelText: 'Billing interval', border: OutlineInputBorder()),
              items: const [
                DropdownMenuItem(value: 'monthly', child: Text('monthly')),
                DropdownMenuItem(value: 'yearly', child: Text('yearly')),
                DropdownMenuItem(value: 'trial', child: Text('trial')),
              ],
              onChanged: (v) => setState(() => _billing = v ?? 'monthly'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              key: ValueKey(_payment),
              initialValue: _payment,
              decoration: const InputDecoration(labelText: 'Payment status', border: OutlineInputBorder()),
              items: const [
                DropdownMenuItem(value: 'current', child: Text('current')),
                DropdownMenuItem(value: 'overdue', child: Text('overdue')),
                DropdownMenuItem(value: 'trialing', child: Text('trialing')),
                DropdownMenuItem(value: 'unknown', child: Text('unknown')),
                DropdownMenuItem(value: 'canceled', child: Text('canceled')),
              ],
              onChanged: (v) => setState(() => _payment = v ?? 'current'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              // ignore: deprecated_member_use
              value: _status,
              decoration: const InputDecoration(labelText: 'Subscription status', border: OutlineInputBorder()),
              items: const [
                DropdownMenuItem(value: 'active', child: Text('active')),
                DropdownMenuItem(value: 'inactive', child: Text('inactive')),
                DropdownMenuItem(value: 'canceled', child: Text('canceled')),
              ],
              onChanged: (v) => setState(() => _status = v ?? 'active'),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _planId == null
                  ? null
                  : () async {
                      final repo = ref.read(platformAdminRepositoryProvider);
                      await repo.assignSubscription(
                        tenantId: widget.tenantId,
                        planId: _planId!,
                        expiresAt: _expires,
                        graceEndsAt: _graceEnds,
                        billingInterval: _billing,
                        paymentStatus: _payment,
                        status: _status,
                      );
                      widget.onSaved();
                    },
              child: const Text('Save subscription'),
            ),
          ],
        ),
      ),
    );
  }
}
