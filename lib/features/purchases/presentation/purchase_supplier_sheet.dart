import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/kpms_feedback.dart';
import '../../suppliers/application/suppliers_notifier.dart';
import '../../suppliers/domain/supplier.dart';

/// Minimal add / edit supplier sheet from the purchase workflow.
Future<void> showPurchaseSupplierSheet(
  BuildContext context,
  WidgetRef ref, {
  Supplier? existing,
  void Function(String supplierId)? onSaved,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _SupplierSheetBody(
      existing: existing,
      onDone: (id) {
        Navigator.pop(ctx);
        onSaved?.call(id);
      },
    ),
  );
}

class _SupplierSheetBody extends ConsumerStatefulWidget {
  const _SupplierSheetBody({this.existing, required this.onDone});

  final Supplier? existing;
  final void Function(String supplierId) onDone;

  @override
  ConsumerState<_SupplierSheetBody> createState() => _SupplierSheetBodyState();
}

class _SupplierSheetBodyState extends ConsumerState<_SupplierSheetBody> {
  late final TextEditingController _name;
  late final TextEditingController _phone;
  late final TextEditingController _address;
  late final TextEditingController _notes;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _name = TextEditingController(text: e?.name ?? '');
    _phone = TextEditingController(text: e?.phone ?? '');
    _address = TextEditingController(text: e?.address ?? '');
    _notes = TextEditingController(text: e?.notes ?? '');
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _address.dispose();
    _notes.dispose();
    super.dispose();
  }

  void _save() {
    final name = _name.text.trim();
    if (name.isEmpty) {
      kpmsSnack(context, 'Supplier name is required', isError: true);
      return;
    }
    final phone = _phone.text.trim();
    final address = _address.text.trim();
    final notes = _notes.text.trim();

    if (widget.existing != null) {
      final prev = widget.existing!;
      ref.read(suppliersProvider.notifier).updateSupplier(
            Supplier(
              id: prev.id,
              name: name,
              phone: phone.isEmpty ? '—' : phone,
              address: address.isEmpty ? '—' : address,
              notes: notes,
              balanceOwed: prev.balanceOwed,
            ),
          );
      HapticFeedback.lightImpact();
      widget.onDone(prev.id);
      kpmsSnack(context, 'Supplier updated');
    } else {
      final id = 'sup_${DateTime.now().millisecondsSinceEpoch}';
      ref.read(suppliersProvider.notifier).addSupplier(
            Supplier(
              id: id,
              name: name,
              phone: phone.isEmpty ? '—' : phone,
              address: address.isEmpty ? '—' : address,
              notes: notes,
            ),
          );
      HapticFeedback.lightImpact();
      widget.onDone(id);
      kpmsSnack(context, 'Supplier added');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isEdit = widget.existing != null;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.92,
        ),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 40,
              offset: const Offset(0, -8),
            ),
          ],
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.outline.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                isEdit ? 'Edit supplier' : 'New supplier',
                style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 6),
              Text(
                'Details sync instantly to your supplier list.',
                style: theme.textTheme.bodyMedium?.copyWith(color: theme.hintColor),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _name,
                textCapitalization: TextCapitalization.words,
                decoration: _decoration(theme, 'Supplier name *', Icons.business_rounded),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                decoration: _decoration(theme, 'Phone number', Icons.phone_rounded),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _address,
                textCapitalization: TextCapitalization.sentences,
                maxLines: 2,
                decoration: _decoration(theme, 'Address', Icons.place_outlined),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _notes,
                maxLines: 3,
                decoration: _decoration(theme, 'Notes (optional)', Icons.notes_rounded),
              ),
              const SizedBox(height: 28),
              FilledButton(
                onPressed: _save,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: Text(isEdit ? 'Save changes' : 'Save supplier'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _decoration(ThemeData theme, String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, size: 22),
      filled: true,
      fillColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: theme.colorScheme.outline.withValues(alpha: 0.2)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: theme.colorScheme.outline.withValues(alpha: 0.15)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.4),
      ),
    );
  }
}
