import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/navigation/kpms_breakpoints.dart';
import '../../../core/utils/kpms_feedback.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/kpms_empty_state.dart';
import '../../../core/widgets/kpms_page_shell.dart';

/// PRD §5.10 — Customers (profiles, purchase history, prescriptions link).
class CustomersScreen extends ConsumerStatefulWidget {
  const CustomersScreen({super.key});

  @override
  ConsumerState<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends ConsumerState<CustomersScreen> {
  final _q = TextEditingController();
  final List<({String name, String phone})> _rows = [];

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final q = _q.text.trim().toLowerCase();
    final filtered = _rows.where((c) => q.isEmpty || c.name.toLowerCase().contains(q) || c.phone.toLowerCase().contains(q)).toList();

    return KpmsPageShell(
      title: 'Customers',
      subtitle: 'Search · history · Rx uploads',
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openNewCustomer,
        icon: const Icon(Icons.person_add_rounded),
        label: const Text('New customer'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(0, 16, 0, 8),
            child: GlassCard(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: TextField(
                controller: _q,
                decoration: InputDecoration(
                  hintText: 'Search customer…',
                  border: InputBorder.none,
                  prefixIcon: Icon(Icons.search_rounded, color: theme.hintColor),
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
          ),
          Expanded(
            child: filtered.isEmpty
                ? KpmsEmptyState(
                    icon: Icons.people_outline_rounded,
                    title: q.isEmpty ? 'No customers yet' : 'No matches',
                    message: q.isEmpty
                        ? 'Add walk-in or loyalty profiles. Records stay private to your pharmacy once synced.'
                        : 'Try a different search.',
                    actionLabel: q.isEmpty ? 'New customer' : null,
                    onAction: q.isEmpty ? _openNewCustomer : null,
                  )
                : ListView.separated(
                    padding: KpmsBreakpoints.pageScrollPadding(context, bottomExtra: 72),
                    itemCount: filtered.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 10),
                    itemBuilder: (context, i) {
                      final c = filtered[i];
                      return Card(
                        child: ListTile(
                          leading: CircleAvatar(
                            child: Text(c.name.isNotEmpty ? c.name[0].toUpperCase() : '?'),
                          ),
                          title: Text(c.name, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                          subtitle: Text(c.phone.isEmpty ? 'No phone' : c.phone),
                          trailing: const Icon(Icons.chevron_right_rounded),
                          onTap: () => _openCustomer(c.name, c.phone),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  void _openNewCustomer() {
    final name = TextEditingController();
    final phone = TextEditingController();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom, left: 24, right: 24, top: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('New customer', style: Theme.of(ctx).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 16),
            TextField(controller: name, decoration: const InputDecoration(labelText: 'Full name')),
            const SizedBox(height: 12),
            TextField(controller: phone, decoration: const InputDecoration(labelText: 'Phone')),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: () {
                final n = name.text.trim();
                if (n.isEmpty) {
                  kpmsSnack(context, 'Enter a name', isError: true);
                  return;
                }
                Navigator.pop(ctx);
                setState(() {
                  _rows.add((name: n, phone: phone.text.trim()));
                });
                kpmsSnack(context, 'Customer added for this session.');
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    ).whenComplete(() {
      name.dispose();
      phone.dispose();
    });
  }

  void _openCustomer(String name, String phone) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(name),
        content: Text(
          phone.isEmpty ? 'Full profile sync uses Supabase customer tables (tenant-scoped).' : '$phone\n\nHistory loads from your pharmacy database.',
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close'))],
      ),
    );
  }
}
