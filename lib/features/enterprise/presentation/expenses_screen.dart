import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/audit/pharmacy_audit_hooks.dart';
import '../../../core/utils/kpms_feedback.dart';
import '../../../core/widgets/kpms_keyboard_aware_scroll.dart';
import '../../notifications/application/kpms_pharmacy_success_notifications.dart';
import '../../../core/auth/permission_providers.dart';
import '../../../core/supabase/auth_user_helpers.dart';
import '../../../core/supabase/supabase_bootstrap.dart';
import '../../../core/tenant/kpms_active_tenant_provider.dart';
import '../../../core/widgets/kpms_empty_state.dart';
import '../../../core/widgets/kpms_page_shell.dart';
import '../application/pharmacy_enterprise_providers.dart';
import '../application/pharmacy_expenses_notifier.dart';
import '../domain/pharmacy_expense.dart';

/// Tenant-scoped expense ledger (mobile-first).
class ExpensesScreen extends ConsumerStatefulWidget {
  const ExpensesScreen({super.key});

  @override
  ConsumerState<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends ConsumerState<ExpensesScreen> {
  String? _categoryFilter;
  String _search = '';

  Future<void> _openEditor({PharmacyExpense? existing}) async {
    final amountCtrl = TextEditingController(text: existing?.amount.toStringAsFixed(2) ?? '');
    final noteCtrl = TextEditingController(text: existing?.note ?? '');
    var category = existing?.category ?? PharmacyExpenseCategories.general;
    var issuedAt = existing?.issuedAt ?? DateTime.now();

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
          child: SingleChildScrollView(
            padding: kpmsSheetScrollPadding(ctx),
            child: StatefulBuilder(
              builder: (ctx, setModal) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                  Text(
                    existing == null ? 'Add expense' : 'Edit expense',
                    style: Theme.of(ctx).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    key: ValueKey(category),
                    initialValue: category,
                    decoration: const InputDecoration(labelText: 'Category', border: OutlineInputBorder()),
                    items: [
                      for (final c in PharmacyExpenseCategories.presets)
                        DropdownMenuItem(value: c, child: Text(PharmacyExpenseCategories.label(c))),
                    ],
                    onChanged: (v) => setModal(() => category = v ?? category),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: amountCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Amount', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: noteCtrl,
                    decoration: const InputDecoration(labelText: 'Note', border: OutlineInputBorder()),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 12),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Date'),
                    subtitle: Text('${issuedAt.year}-${issuedAt.month.toString().padLeft(2, '0')}-${issuedAt.day.toString().padLeft(2, '0')}'),
                    trailing: const Icon(Icons.calendar_today_outlined),
                    onTap: () async {
                      final d = await showDatePicker(
                        context: ctx,
                        initialDate: issuedAt,
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (d != null) setModal(() => issuedAt = d);
                    },
                  ),
                  const SizedBox(height: 16),
                    FilledButton(
                      onPressed: () {
                        final amount = double.tryParse(amountCtrl.text.replaceAll(',', '')) ?? 0;
                        if (amount <= 0) return;
                        Navigator.pop(ctx, true);
                      },
                      child: const Text('Save'),
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );

    if (saved != true || !mounted) return;

    final amount = double.tryParse(amountCtrl.text.replaceAll(',', '')) ?? 0;
    if (amount <= 0) return;

    final uid = kpmsAuthUserId(SupabaseBootstrap.clientOrNull);
    final notifier = ref.read(pharmacyExpensesProvider.notifier);

    if (existing == null) {
      final exp = PharmacyExpense(
        id: PharmacyExpense.newClientId(),
        category: category,
        amount: amount,
        note: noteCtrl.text.trim(),
        issuedAt: issuedAt,
        createdBy: uid,
      );
      notifier.add(exp);
      if (mounted) kpmsSnack(context, 'Expense saved');
      unawaited(KpmsPharmacySuccessNotifications.expenseAdded(
        ref,
        expenseId: exp.id,
        amount: amount,
      ));
      await PharmacyAuditHooks.expenseChange(
        action: 'expense.created',
        expenseId: exp.id,
        nextData: exp.toJson(),
      );
    } else {
      final updated = existing.copyWith(
        category: category,
        amount: amount,
        note: noteCtrl.text.trim(),
        issuedAt: issuedAt,
      );
      notifier.update(updated);
      await PharmacyAuditHooks.expenseChange(
        action: 'expense.updated',
        expenseId: updated.id,
        previousData: existing.toJson(),
        nextData: updated.toJson(),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final canFin = ref.watch(kpmsCanViewFinancialMetricsProvider);
    final now = DateTime.now();
    final monthTotal = ref.read(pharmacyExpensesProvider.notifier).totalForMonth(now);
    final todayTotal = ref.read(pharmacyExpensesProvider.notifier).totalForDay(now);

    final filtered = ref.read(pharmacyExpensesProvider.notifier).filtered(
          category: _categoryFilter,
          search: _search,
        );

    return KpmsPageShell(
      title: 'Expenses',
      subtitle: canFin ? 'Month \$${monthTotal.toStringAsFixed(2)} · Today \$${todayTotal.toStringAsFixed(2)}' : 'Operational costs',
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(0, 0, 0, 12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: const InputDecoration(
                      hintText: 'Search notes…',
                      prefixIcon: Icon(Icons.search_rounded),
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    onChanged: (v) => setState(() => _search = v),
                  ),
                ),
                const SizedBox(width: 8),
                PopupMenuButton<String?>(
                  tooltip: 'Category',
                  onSelected: (v) => setState(() => _categoryFilter = v),
                  itemBuilder: (_) => [
                    const PopupMenuItem(value: null, child: Text('All categories')),
                    for (final c in PharmacyExpenseCategories.presets)
                      PopupMenuItem(value: c, child: Text(PharmacyExpenseCategories.label(c))),
                  ],
                  child: const Padding(
                    padding: EdgeInsets.all(12),
                    child: Icon(Icons.filter_list_rounded),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: filtered.isEmpty
                ? const KpmsEmptyState(
                    icon: Icons.payments_outlined,
                    title: 'No expenses yet',
                    message: 'Track rent, utilities, payroll, and other pharmacy costs here.',
                  )
                : ListView.separated(
                    itemCount: filtered.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, i) {
                      final e = filtered[i];
                      return Material(
                        color: theme.colorScheme.surface,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(color: theme.colorScheme.outline.withValues(alpha: 0.25)),
                        ),
                        child: ListTile(
                          title: Text(PharmacyExpenseCategories.label(e.category)),
                          subtitle: Text(
                            e.note.isEmpty ? _formatDate(e.issuedAt) : '${e.note}\n${_formatDate(e.issuedAt)}',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: canFin
                              ? Text(
                                  '\$${e.amount.toStringAsFixed(2)}',
                                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                                )
                              : null,
                          onTap: () => _openEditor(existing: e),
                          onLongPress: () async {
                            final ok = await showDialog<bool>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: const Text('Delete expense?'),
                                actions: [
                                  TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                                  FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
                                ],
                              ),
                            );
                            if (ok == true && mounted) {
                              ref.read(pharmacyExpensesProvider.notifier).remove(e.id);
                              await PharmacyAuditHooks.expenseChange(
                                action: 'expense.deleted',
                                expenseId: e.id,
                                previousData: e.toJson(),
                              );
                              final tid = ref.read(kpmsActiveTenantIdProvider).valueOrNull;
                              if (tid != null) {
                                await ref.read(pharmacyEnterpriseCloudRepositoryProvider).deleteExpense(tid, e.id);
                              }
                            }
                          },
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
