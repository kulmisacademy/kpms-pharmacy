import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/navigation/kpms_breakpoints.dart';
import '../../../core/utils/kpms_feedback.dart';
import '../../../core/widgets/kpms_platform_admin_shell.dart';
import '../application/platform_admin_providers.dart';

/// CRUD subscription plans via `super_admin_list_plans` / `super_admin_upsert_plan` / `super_admin_delete_plan`.
class SuperAdminPlansScreen extends ConsumerWidget {
  const SuperAdminPlansScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(superAdminPlansProvider);
    return KpmsPlatformAdminShell(
      title: 'Subscription plans',
      subtitle: 'Pricing catalog for tenant subscriptions',
      actions: [
        IconButton(
          tooltip: 'Refresh',
          onPressed: () => ref.invalidate(superAdminPlansProvider),
          icon: const Icon(Icons.refresh_rounded),
        ),
      ],
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(context, ref, null),
        icon: const Icon(Icons.add_rounded),
        label: const Text('New plan'),
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (plans) => ListView.separated(
          padding: KpmsBreakpoints.pageScrollPadding(context, bottomExtra: 88),
          itemCount: plans.length,
          separatorBuilder: (context, index) => const SizedBox(height: 10),
          itemBuilder: (context, i) {
            final p = plans[i];
            final id = p['id']?.toString();
            final active = p['is_active'] == true;
            final cents = (p['monthly_price_cents'] as num?)?.toInt() ?? 0;
            final price = (cents / 100).toStringAsFixed(2);
            final yCents = (p['yearly_price_cents'] as num?)?.toInt() ?? 0;
            final yStr = yCents > 0 ? ' · \$${(yCents / 100).toStringAsFixed(0)}/yr' : '';
            return Card(
              child: ListTile(
                title: Text(p['name']?.toString() ?? '', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                subtitle: Text('${p['slug']} · \$$price/mo$yStr · ${active ? 'active' : 'inactive'}\n${p['description'] ?? ''}'),
                isThreeLine: true,
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: 'Edit',
                      icon: const Icon(Icons.edit_outlined),
                      onPressed: id == null ? null : () => _openEditor(context, ref, p),
                    ),
                    IconButton(
                      tooltip: 'Delete',
                      icon: Icon(Icons.delete_outline_rounded, color: Theme.of(context).colorScheme.error),
                      onPressed: id == null
                          ? null
                          : () async {
                              final ok = await showDialog<bool>(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  title: const Text('Delete plan?'),
                                  content: const Text('Only allowed when no pharmacy uses this plan.'),
                                  actions: [
                                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                                    FilledButton(
                                      style: FilledButton.styleFrom(backgroundColor: Theme.of(ctx).colorScheme.error),
                                      onPressed: () => Navigator.pop(ctx, true),
                                      child: const Text('Delete'),
                                    ),
                                  ],
                                ),
                              );
                              if (ok != true) return;
                              if (!context.mounted) return;
                              try {
                                await ref.read(platformAdminRepositoryProvider).deletePlan(id);
                                if (!context.mounted) return;
                                ref.invalidate(superAdminPlansProvider);
                                kpmsSnack(context, 'Plan deleted.');
                              } catch (e) {
                                if (!context.mounted) return;
                                kpmsSnack(context, '$e', isError: true);
                              }
                            },
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _openEditor(BuildContext context, WidgetRef ref, Map<String, dynamic>? existing) async {
    final slug = TextEditingController(text: existing?['slug']?.toString() ?? '');
    final name = TextEditingController(text: existing?['name']?.toString() ?? '');
    final desc = TextEditingController(text: existing?['description']?.toString() ?? '');
    final price = TextEditingController(
      text: existing == null
          ? '0'
          : (((existing['monthly_price_cents'] as num?)?.toInt() ?? 0) / 100).toStringAsFixed(2),
    );
    final yearly = TextEditingController(
      text: existing == null
          ? '0'
          : (((existing['yearly_price_cents'] as num?)?.toInt() ?? 0) / 100).toStringAsFixed(2),
    );
    final maxMed = TextEditingController(text: '${existing?['max_medicines'] ?? ''}');
    final maxStaff = TextEditingController(text: '${existing?['max_staff'] ?? ''}');
    final maxBranch = TextEditingController(text: '${existing?['max_branches'] ?? ''}');
    final maxStorage = TextEditingController(text: '${existing?['max_storage_mb'] ?? ''}');
    final feat = TextEditingController(
      text: existing == null
          ? '{"reports":true,"enterprise":true,"pos":true}'
          : jsonEncode(existing['features'] ?? {'reports': true, 'enterprise': true, 'pos': true}),
    );
    final sort = TextEditingController(text: '${existing?['sort_order'] ?? 0}');
    var active = existing?['is_active'] != false;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Text(existing == null ? 'New plan' : 'Edit plan'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: slug, decoration: const InputDecoration(labelText: 'Slug (unique)', border: OutlineInputBorder())),
                const SizedBox(height: 10),
                TextField(controller: name, decoration: const InputDecoration(labelText: 'Name', border: OutlineInputBorder())),
                const SizedBox(height: 10),
                TextField(controller: desc, decoration: const InputDecoration(labelText: 'Description', border: OutlineInputBorder())),
                const SizedBox(height: 10),
                TextField(
                  controller: price,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Monthly price (USD)', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: yearly,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Yearly price (USD)', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: maxMed,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Max medicines (empty = unlimited)', border: OutlineInputBorder()),
                ),
                TextField(
                  controller: maxStaff,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Max staff', border: OutlineInputBorder()),
                ),
                TextField(
                  controller: maxBranch,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Max branches', border: OutlineInputBorder()),
                ),
                TextField(
                  controller: maxStorage,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Max storage (MB)', border: OutlineInputBorder()),
                ),
                TextField(
                  controller: feat,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Features JSON (e.g. reports, enterprise, pos)',
                    border: OutlineInputBorder(),
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 10),
                TextField(controller: sort, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Sort order', border: OutlineInputBorder())),
                SwitchListTile(
                  title: const Text('Active in catalog'),
                  value: active,
                  onChanged: (v) => setLocal(() => active = v),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
          ],
        ),
      ),
    );
    if (ok != true) return;
    if (!context.mounted) return;
    final dollars = double.tryParse(price.text.trim()) ?? 0;
    final cents = (dollars * 100).round();
    final yDollars = double.tryParse(yearly.text.trim()) ?? 0;
    final yCents = (yDollars * 100).round();
    final sortOrder = int.tryParse(sort.text.trim()) ?? 0;
    Map<String, dynamic>? featuresMap;
    try {
      final decoded = jsonDecode(feat.text.trim());
      if (decoded is Map) {
        featuresMap = Map<String, dynamic>.from(decoded);
      }
    } catch (_) {
      kpmsSnack(context, 'Invalid features JSON', isError: true);
      return;
    }
    if (featuresMap == null) {
      kpmsSnack(context, 'Features must be a JSON object.', isError: true);
      return;
    }
    try {
      await ref.read(platformAdminRepositoryProvider).upsertPlan(
            id: existing?['id']?.toString(),
            slug: slug.text.trim(),
            name: name.text.trim(),
            description: desc.text.trim(),
            monthlyPriceCents: cents,
            yearlyPriceCents: yCents,
            sortOrder: sortOrder,
            isActive: active,
            maxMedicines: int.tryParse(maxMed.text.trim()),
            maxStaff: int.tryParse(maxStaff.text.trim()),
            maxBranches: int.tryParse(maxBranch.text.trim()),
            maxStorageMb: int.tryParse(maxStorage.text.trim()),
            features: featuresMap,
          );
      if (!context.mounted) return;
      ref.invalidate(superAdminPlansProvider);
      kpmsSnack(context, 'Plan saved.');
    } catch (e) {
      if (!context.mounted) return;
      kpmsSnack(context, '$e', isError: true);
    }
  }
}
