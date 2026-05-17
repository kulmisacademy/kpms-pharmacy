import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../medicines/data/medicine_catalog_notifier.dart';
import '../../medicines/domain/medicine.dart';
import '../../medicines/domain/medicine_form_type.dart';

/// Compact add-to-catalog flow from the purchase screen.
Future<Medicine?> showPurchaseQuickAddMedicineSheet(BuildContext context, WidgetRef ref) {
  return showModalBottomSheet<Medicine>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
    ),
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
      child: _QuickAddBody(
        onSaved: (m) => Navigator.pop(ctx, m),
      ),
    ),
  );
}

class _QuickAddBody extends ConsumerStatefulWidget {
  const _QuickAddBody({required this.onSaved});

  final void Function(Medicine m) onSaved;

  @override
  ConsumerState<_QuickAddBody> createState() => _QuickAddBodyState();
}

class _QuickAddBodyState extends ConsumerState<_QuickAddBody> {
  final _name = TextEditingController();
  final _qty = TextEditingController(text: '1');
  final _buy = TextEditingController();
  final _minStock = TextEditingController(text: '10');
  MedicineFormType _form = MedicineFormType.tablet;
  DateTime? _expiry;

  @override
  void dispose() {
    _name.dispose();
    _qty.dispose();
    _buy.dispose();
    _minStock.dispose();
    super.dispose();
  }

  void _save() {
    final name = _name.text.trim();
    if (name.isEmpty) return;
    final qty = int.tryParse(_qty.text) ?? 0;
    final buy = double.tryParse(_buy.text) ?? 0;
    final minS = int.tryParse(_minStock.text) ?? 10;
    if (qty < 1 || buy <= 0) return;
    final sell = double.parse((buy * 1.25).toStringAsFixed(2));
    if (sell < buy) return;

    final id = 'med_${DateTime.now().millisecondsSinceEpoch}';
    final med = Medicine(
      id: id,
      name: name,
      expiryDate: _expiry,
      formType: _form,
      quantity: 0,
      buyingPrice: buy,
      sellingPrice: sell,
      minimumStockAlert: minS,
    );
    ref.read(medicineCatalogProvider.notifier).addMedicine(med);
    HapticFeedback.lightImpact();
    widget.onSaved(med);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.outline.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Quick add medicine',
            style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          Text(
            'Selling price is set automatically for POS (+25% on cost).',
            style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
          ),
          const SizedBox(height: 18),
          TextField(
            controller: _name,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Name *',
              border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(14))),
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<MedicineFormType>(
            key: ValueKey(_form),
            initialValue: _form,
            decoration: const InputDecoration(
              labelText: 'Type',
              border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(14))),
            ),
            items: [
              for (final t in MedicineFormType.values)
                DropdownMenuItem(value: t, child: Text(t.label)),
            ],
            onChanged: (v) => setState(() => _form = v ?? MedicineFormType.tablet),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _qty,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                    labelText: 'Qty *',
                    border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(14))),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final now = DateTime.now();
                    final d = await showDatePicker(
                      context: context,
                      initialDate: _expiry ?? now.add(const Duration(days: 365)),
                      firstDate: now,
                      lastDate: DateTime(now.year + 8),
                    );
                    if (d != null) setState(() => _expiry = d);
                  },
                  icon: const Icon(Icons.event_rounded, size: 18),
                  label: Text(
                    _expiry == null
                        ? 'Expiry'
                        : '${_expiry!.year}-${_expiry!.month.toString().padLeft(2, '0')}-${_expiry!.day.toString().padLeft(2, '0')}',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _buy,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Buying price *',
              prefixText: r'$ ',
              border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(14))),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _minStock,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Low-stock alert',
              border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(14))),
            ),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _save,
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: const Text('Save & use in purchase'),
          ),
        ],
      ),
    );
  }
}
