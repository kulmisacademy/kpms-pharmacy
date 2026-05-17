import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../application/debt_customers_notifier.dart';
import '../domain/debt_customer.dart';

/// Search existing debt customers or confirm adding a new one from current form fields.
Future<DebtCustomer?> showDebtCustomerPickerSheet(
  BuildContext context, {
  required String initialName,
  required String initialPhone,
  String initialNotes = '',
}) {
  return showModalBottomSheet<DebtCustomer>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (ctx) => _DebtCustomerPickerBody(
      initialName: initialName,
      initialPhone: initialPhone,
      initialNotes: initialNotes,
    ),
  );
}

class _DebtCustomerPickerBody extends ConsumerStatefulWidget {
  const _DebtCustomerPickerBody({
    required this.initialName,
    required this.initialPhone,
    required this.initialNotes,
  });

  final String initialName;
  final String initialPhone;
  final String initialNotes;

  @override
  ConsumerState<_DebtCustomerPickerBody> createState() => _DebtCustomerPickerBodyState();
}

class _DebtCustomerPickerBodyState extends ConsumerState<_DebtCustomerPickerBody> {
  late final TextEditingController _q;
  late final TextEditingController _name;
  late final TextEditingController _phone;
  late final TextEditingController _notes;

  @override
  void initState() {
    super.initState();
    _q = TextEditingController();
    _name = TextEditingController(text: widget.initialName);
    _phone = TextEditingController(text: widget.initialPhone);
    _notes = TextEditingController(text: widget.initialNotes);
  }

  @override
  void dispose() {
    _q.dispose();
    _name.dispose();
    _phone.dispose();
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    ref.watch(debtCustomersProvider);
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    final customers = ref.read(debtCustomersProvider.notifier).search(_q.text);

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 8, 20, 20 + bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Customer for credit',
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            'Select an existing profile or save as new.',
            style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _q,
            decoration: InputDecoration(
              hintText: 'Search by name or phone…',
              prefixIcon: const Icon(Icons.search_rounded),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          Flexible(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 220),
              child: customers.isEmpty
                  ? Center(
                      child: Text(
                        'No matches — fill details below.',
                        style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
                      ),
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      itemCount: customers.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 6),
                      itemBuilder: (context, i) {
                        final c = customers[i];
                        return ListTile(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(color: theme.colorScheme.outline.withValues(alpha: 0.15)),
                          ),
                          title: Text(
                            c.name,
                            style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          subtitle: Text(c.phoneDisplay.isEmpty ? '—' : c.phoneDisplay),
                          trailing: const Icon(Icons.check_circle_outline_rounded),
                          onTap: () => Navigator.pop(context, c),
                        );
                      },
                    ),
            ),
          ),
          const SizedBox(height: 16),
          Text('New / edit details', style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          TextField(
            controller: _name,
            decoration: InputDecoration(
              labelText: 'Customer name *',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _phone,
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(
              labelText: 'Phone number *',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _notes,
            maxLines: 2,
            decoration: InputDecoration(
              labelText: 'Notes (optional)',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
              const Spacer(),
              FilledButton(
                onPressed: () {
                  final name = _name.text.trim();
                  final phone = _phone.text.trim();
                  if (name.isEmpty || phone.isEmpty) return;
                  final c = ref.read(debtCustomersProvider.notifier).findOrCreate(
                        name: name,
                        phoneDisplay: phone,
                        notes: _notes.text.trim(),
                      );
                  Navigator.pop(context, c);
                },
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                ),
                child: const Text('Use customer'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
