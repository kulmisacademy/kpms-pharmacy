import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/kpms_feedback.dart';
import '../../sales/application/sales_ledger_notifier.dart';

Future<void> showPayCustomerDebtSheet(
  BuildContext context,
  WidgetRef ref, {
  required String debtCustomerId,
  required String customerName,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (ctx) => _PayDebtBody(
      debtCustomerId: debtCustomerId,
      customerName: customerName,
    ),
  );
}

class _PayDebtBody extends ConsumerStatefulWidget {
  const _PayDebtBody({
    required this.debtCustomerId,
    required this.customerName,
  });

  final String debtCustomerId;
  final String customerName;

  @override
  ConsumerState<_PayDebtBody> createState() => _PayDebtBodyState();
}

class _PayDebtBodyState extends ConsumerState<_PayDebtBody> {
  final _amount = TextEditingController();
  final _note = TextEditingController();

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    ref.watch(salesLedgerProvider);
    final open = ref
        .read(salesLedgerProvider.notifier)
        .openDebtTotalForCustomer(widget.debtCustomerId);
    final bottom = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 8, 20, 20 + bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Pay debt',
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            widget.customerName,
            style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            'Open balance: \$${open.toStringAsFixed(2)}',
            style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _amount,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}'))],
            decoration: InputDecoration(
              labelText: 'Amount *',
              prefixText: r'$ ',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _note,
            maxLines: 2,
            decoration: InputDecoration(
              labelText: 'Note (optional)',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Oldest unpaid invoices are paid first.',
            style: theme.textTheme.labelSmall?.copyWith(color: theme.hintColor),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
              const Spacer(),
              FilledButton(
                onPressed: () {
                  final amt = double.tryParse(_amount.text.trim()) ?? 0;
                  if (amt <= 0) return;
                  final err = ref.read(salesLedgerProvider.notifier).applyCustomerDebtPayment(
                        debtCustomerId: widget.debtCustomerId,
                        amount: amt,
                        note: _note.text.trim(),
                      );
                  if (!context.mounted) return;
                  if (err != null) {
                    kpmsSnack(context, err, isError: true);
                    return;
                  }
                  Navigator.pop(context);
                  kpmsSnack(context, 'Payment recorded');
                },
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                ),
                child: const Text('Record payment'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
