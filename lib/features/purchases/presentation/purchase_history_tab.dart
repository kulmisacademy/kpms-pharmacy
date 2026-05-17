import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/navigation/kpms_breakpoints.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/glass_card.dart';
import '../../suppliers/application/suppliers_notifier.dart';
import '../application/purchase_ledger_notifier.dart';
import '../domain/purchase_invoice.dart';
import 'purchase_invoice_dialog.dart';

class PurchaseHistoryTab extends ConsumerStatefulWidget {
  const PurchaseHistoryTab({super.key, required this.bottomInset});

  final double bottomInset;

  @override
  ConsumerState<PurchaseHistoryTab> createState() => _PurchaseHistoryTabState();
}

class _PurchaseHistoryTabState extends ConsumerState<PurchaseHistoryTab> {
  final _searchCtrl = TextEditingController();
  String _query = '';
  String? _supplierFilterId;
  PurchasePaymentFilter _paymentFilter = PurchasePaymentFilter.all;
  _DatePreset _datePreset = _DatePreset.any;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  (DateTime?, DateTime?) _dateBounds() {
    final now = DateTime.now();
    switch (_datePreset) {
      case _DatePreset.any:
        return (null, null);
      case _DatePreset.last7:
        return (now.subtract(const Duration(days: 7)), null);
      case _DatePreset.last30:
        return (now.subtract(const Duration(days: 30)), null);
      case _DatePreset.thisMonth:
        return (DateTime(now.year, now.month, 1), null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final suppliers = ref.watch(suppliersProvider);
    ref.watch(purchaseLedgerProvider);
    final bounds = _dateBounds();
    final list = ref.read(purchaseLedgerProvider.notifier).search(
          query: _query,
          supplierId: _supplierFilterId,
          payment: _paymentFilter,
          fromDate: bounds.$1,
          toDate: bounds.$2,
        );

    final pad = KpmsBreakpoints.pagePaddingHorizontal(MediaQuery.sizeOf(context).width);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(pad, 0, pad, 0),
          child: TextField(
            controller: _searchCtrl,
            onChanged: (v) => setState(() => _query = v),
            decoration: InputDecoration(
              hintText: 'Search invoice # or supplier',
              prefixIcon: const Icon(Icons.search_rounded),
              filled: true,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
            ),
          ),
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: EdgeInsets.symmetric(horizontal: pad),
          child: Row(
            children: [
              SizedBox(
                width: 200,
                child: DropdownButtonFormField<String?>(
                  key: ValueKey(_supplierFilterId ?? 'all'),
                  initialValue: _supplierFilterId,
                  isDense: true,
                  decoration: InputDecoration(
                    labelText: 'Supplier',
                    filled: true,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  items: [
                    const DropdownMenuItem<String?>(value: null, child: Text('All suppliers')),
                    for (final s in suppliers)
                      DropdownMenuItem<String?>(
                        value: s.id,
                        child: Text(s.name, overflow: TextOverflow.ellipsis),
                      ),
                  ],
                  onChanged: (v) => setState(() => _supplierFilterId = v),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 150,
                child: DropdownButtonFormField<PurchasePaymentFilter>(
                  key: ValueKey(_paymentFilter),
                  initialValue: _paymentFilter,
                  isDense: true,
                  decoration: InputDecoration(
                    labelText: 'Payment',
                    filled: true,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  items: [
                    for (final f in PurchasePaymentFilter.values)
                      DropdownMenuItem(value: f, child: Text(f.label)),
                  ],
                  onChanged: (v) {
                    if (v != null) setState(() => _paymentFilter = v);
                  },
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 150,
                child: DropdownButtonFormField<_DatePreset>(
                  key: ValueKey(_datePreset),
                  initialValue: _datePreset,
                  isDense: true,
                  decoration: InputDecoration(
                    labelText: 'Date',
                    filled: true,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  items: const [
                    DropdownMenuItem(value: _DatePreset.any, child: Text('Any time')),
                    DropdownMenuItem(value: _DatePreset.last7, child: Text('Last 7 days')),
                    DropdownMenuItem(value: _DatePreset.last30, child: Text('Last 30 days')),
                    DropdownMenuItem(value: _DatePreset.thisMonth, child: Text('This month')),
                  ],
                  onChanged: (v) {
                    if (v != null) setState(() => _datePreset = v);
                  },
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Expanded(
          child: list.isEmpty
              ? Center(
                  child: Text(
                    'No purchases match your filters.',
                    style: theme.textTheme.bodyLarge?.copyWith(color: theme.hintColor),
                  ),
                )
              : ListView.separated(
                  padding: EdgeInsets.fromLTRB(pad, 0, pad, 16 + widget.bottomInset),
                  itemCount: list.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 10),
                  itemBuilder: (context, i) {
                    final p = list[i];
                    return TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: 1),
                      duration: Duration(milliseconds: 200 + i * 25),
                      curve: Curves.easeOutCubic,
                      builder: (context, t, child) => Opacity(
                        opacity: t,
                        child: Transform.translate(offset: Offset(0, 6 * (1 - t)), child: child),
                      ),
                      child: _HistoryTile(
                        invoice: p,
                        onOpen: () => showPurchaseInvoiceDialog(context, p),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

enum _DatePreset { any, last7, last30, thisMonth }

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({required this.invoice, required this.onOpen});

  final PurchaseInvoice invoice;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final d = invoice.issuedAt;
    final dateStr = '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    final st = invoice.paymentStatusLabel;
    final chipColor = switch (st) {
      'Paid' => AppColors.tertiary,
      'Partial' => Colors.orange.shade700,
      _ => AppColors.primary,
    };

    return GlassCard(
      borderRadius: 18,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(18),
        child: Row(
          children: [
            Icon(Icons.receipt_long_rounded, color: AppColors.primary, size: 28),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    invoice.invoiceNumber,
                    style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900),
                  ),
                  Text(
                    invoice.supplierName,
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
                  ),
                  Text(
                    '$dateStr · ${invoice.lines.length} items',
                    style: theme.textTheme.labelSmall?.copyWith(color: theme.hintColor),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '\$${invoice.grandTotal.toStringAsFixed(2)}',
                  style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: chipColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    st,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: chipColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: onOpen,
                  child: const Text('Print / view'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
