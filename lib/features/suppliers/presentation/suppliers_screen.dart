import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_routes.dart';
import '../../../core/navigation/kpms_breakpoints.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/kpms_feedback.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/kpms_page_shell.dart';
import '../../purchases/application/purchase_ledger_notifier.dart';
import '../application/suppliers_notifier.dart';
import '../domain/supplier.dart';

/// Suppliers — shared with purchases; balance updates from credit buys.
class SuppliersScreen extends ConsumerWidget {
  const SuppliersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final rows = ref.watch(suppliersProvider);
    ref.watch(purchaseLedgerProvider);

    int purchaseCountFor(String supplierId) {
      return ref.read(purchaseLedgerProvider).invoices.where((p) => p.supplierId == supplierId).length;
    }

    return KpmsPageShell(
      title: 'Suppliers',
      subtitle: 'Contacts · balance · purchase history',
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addSupplier(context, ref),
        icon: const Icon(Icons.person_add_alt_1_rounded),
        label: const Text('Add supplier'),
      ),
      body: ListView.separated(
        padding: KpmsBreakpoints.pageScrollPadding(context, bottomExtra: 82),
        itemCount: rows.length,
        separatorBuilder: (context, index) => const SizedBox(height: 10),
        itemBuilder: (context, i) {
          final s = rows[i];
          final purchases = purchaseCountFor(s.id);
          return GlassCard(
            borderRadius: 18,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: InkWell(
              onTap: () => context.push('${AppRoutes.supplierFinance}/${s.id}'),
              borderRadius: BorderRadius.circular(18),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: theme.colorScheme.primaryContainer,
                    child: Icon(Icons.local_shipping_outlined, color: theme.colorScheme.primary),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(s.name, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
                        Text(s.address, style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor)),
                        Text(s.phone, style: theme.textTheme.bodySmall),
                        Text(
                          '$purchases purchase invoice${purchases == 1 ? '' : 's'}',
                          style: theme.textTheme.labelSmall?.copyWith(color: theme.hintColor),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'Balance',
                        style: theme.textTheme.labelSmall?.copyWith(color: theme.hintColor),
                      ),
                      Text(
                        '\$${s.balanceOwed.toStringAsFixed(2)}',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w900,
                          color: s.balanceOwed > 0.009 ? Colors.orange.shade800 : AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _addSupplier(BuildContext context, WidgetRef ref) {
    final name = TextEditingController();
    final phone = TextEditingController();
    final address = TextEditingController();
    final notes = TextEditingController();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(ctx).bottom,
          left: 24,
          right: 24,
          top: 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Add supplier', style: Theme.of(ctx).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 16),
            TextField(
              controller: name,
              decoration: const InputDecoration(labelText: 'Company name *'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: phone,
              decoration: const InputDecoration(labelText: 'Phone'),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: address,
              decoration: const InputDecoration(labelText: 'Address'),
              maxLines: 2,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: notes,
              decoration: const InputDecoration(labelText: 'Notes (optional)'),
              maxLines: 2,
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: () {
                if (name.text.trim().isEmpty) {
                  kpmsSnack(context, 'Company name required', isError: true);
                  return;
                }
                final id = 'sup_${DateTime.now().millisecondsSinceEpoch}';
                ref.read(suppliersProvider.notifier).addSupplier(
                      Supplier(
                        id: id,
                        name: name.text.trim(),
                        phone: phone.text.trim().isEmpty ? '—' : phone.text.trim(),
                        address: address.text.trim().isEmpty ? '—' : address.text.trim(),
                        notes: notes.text.trim(),
                      ),
                    );
                Navigator.pop(ctx);
                kpmsSnack(context, 'Supplier added');
              },
              child: const Text('Save'),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    ).whenComplete(() {
      name.dispose();
      phone.dispose();
      address.dispose();
      notes.dispose();
    });
  }
}
