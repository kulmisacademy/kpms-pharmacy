import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/navigation/kpms_breakpoints.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/kpms_feedback.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/kpms_mobile_bottom_nav.dart';
import '../../../core/widgets/kpms_page_shell.dart';
import '../application/purchase_ledger_notifier.dart';
import '../domain/purchase_invoice.dart';
import '../domain/purchase_return.dart';

String _money(double n) => '\$${n.toStringAsFixed(2)}';

/// Invoice-based purchase returns — supplier credit, stock reversal, AP updates.
class PurchaseReturnsScreen extends ConsumerStatefulWidget {
  const PurchaseReturnsScreen({super.key});

  @override
  ConsumerState<PurchaseReturnsScreen> createState() => _PurchaseReturnsScreenState();
}

class _PurchaseReturnsScreenState extends ConsumerState<PurchaseReturnsScreen> with SingleTickerProviderStateMixin {
  final _searchCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  late final TabController _tabs;
  String _query = '';
  PurchaseInvoice? _selected;
  final Map<String, int> _pendingQty = {};
  PurchaseReturnReason _reason = PurchaseReturnReason.damaged;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    _searchCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  void _select(PurchaseInvoice? inv) {
    setState(() {
      _selected = inv;
      _pendingQty.clear();
      _notesCtrl.clear();
      _reason = PurchaseReturnReason.damaged;
    });
  }

  void _setPending(String medicineId, int value, int maxRem) {
    final v = value.clamp(0, maxRem);
    setState(() {
      if (v == 0) {
        _pendingQty.remove(medicineId);
      } else {
        _pendingQty[medicineId] = v;
      }
    });
  }

  double _previewCost(PurchaseInvoice inv) {
    var t = 0.0;
    for (final line in inv.lines) {
      final q = _pendingQty[line.medicineId] ?? 0;
      t += line.buyingPrice * q;
    }
    return t;
  }

  Future<void> _submit(PurchaseInvoice inv) async {
    final err = ref.read(purchaseLedgerProvider.notifier).processPurchaseReturn(
          purchaseInvoiceNumber: inv.invoiceNumber,
          returnQtyByMedicineId: Map<String, int>.from(_pendingQty)..removeWhere((_, q) => q <= 0),
          reason: _reason,
          notes: _notesCtrl.text,
        );
    if (!mounted) return;
    if (err != null) {
      kpmsSnack(context, err, isError: true);
      return;
    }
    HapticFeedback.mediumImpact();
    final rec = ref.read(purchaseLedgerProvider).returns.first;
    await _showReturnSummaryDialog(context, rec);
    if (!mounted) return;
    _select(null);
    kpmsSnack(context, 'Return posted · stock & balances updated');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final width = MediaQuery.sizeOf(context).width;
    final wide = width >= 960;
    final pad = KpmsBreakpoints.pagePaddingHorizontal(width);
    final clearance = KpmsMobileBottomNav.scrollClearanceBottom(context);

    ref.watch(purchaseLedgerProvider);
    final all = ref.read(purchaseLedgerProvider.notifier).search(query: _query);
    final results = [...all]..sort((a, b) => b.issuedAt.compareTo(a.issuedAt));

    return KpmsPageShell(
      title: 'Purchase returns',
      subtitle: 'Supplier RMA · credits · stock reversal',
      constrainContentWidth: false,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Material(
            color: theme.colorScheme.surface,
            child: TabBar(
              controller: _tabs,
              labelStyle: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800),
              tabs: const [
                Tab(text: 'Process return'),
                Tab(text: 'Return history'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: [
                  wide
                      ? Padding(
                          padding: EdgeInsets.fromLTRB(pad, 12, pad, 16),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Expanded(
                                flex: 5,
                                child: _SearchAndList(
                                  searchCtrl: _searchCtrl,
                                  onQuery: (q) => setState(() => _query = q),
                                  results: results,
                                  selected: _selected,
                                  onSelect: _select,
                                ),
                              ),
                              const SizedBox(width: 16),
                              const VerticalDivider(width: 1),
                              const SizedBox(width: 16),
                              Expanded(
                                flex: 6,
                                child: _selected == null
                                    ? const _EmptyDetail(wide: true)
                                    : _ReturnInvoicePanel(
                                        invoice: _selected!,
                                        pendingQty: _pendingQty,
                                        reason: _reason,
                                        notesCtrl: _notesCtrl,
                                        onReason: (r) => setState(() => _reason = r),
                                        onPendingChange: _setPending,
                                        previewCost: _previewCost(_selected!),
                                        onSubmit: () => _submit(_selected!),
                                        onClose: () => _select(null),
                                        wide: true,
                                        bottomInset: 0,
                                      ),
                              ),
                            ],
                          ),
                        )
                      : Padding(
                          padding: EdgeInsets.fromLTRB(pad, 12, pad, 0),
                          child: _selected == null
                              ? _SearchAndList(
                                  searchCtrl: _searchCtrl,
                                  onQuery: (q) => setState(() => _query = q),
                                  results: results,
                                  selected: _selected,
                                  onSelect: _select,
                                  bottomInset: clearance + 16,
                                )
                              : _ReturnInvoicePanel(
                                  invoice: _selected!,
                                  pendingQty: _pendingQty,
                                  reason: _reason,
                                  notesCtrl: _notesCtrl,
                                  onReason: (r) => setState(() => _reason = r),
                                  onPendingChange: _setPending,
                                  previewCost: _previewCost(_selected!),
                                  onSubmit: () => _submit(_selected!),
                                  onClose: () => _select(null),
                                  wide: false,
                                  bottomInset: clearance + 16,
                                ),
                        ),
                  _HistoryTab(bottomInset: clearance + 16),
                ],
              ),
            ),
          ],
        ),
    );
  }
}

class _HistoryTab extends ConsumerWidget {
  const _HistoryTab({required this.bottomInset});

  final double bottomInset;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final pad = KpmsBreakpoints.pagePaddingHorizontal(MediaQuery.sizeOf(context).width);
    final returns = ref.watch(purchaseLedgerProvider).returns;

    if (returns.isEmpty) {
      return ListView(
        padding: EdgeInsets.fromLTRB(pad, 48, pad, bottomInset),
        children: [
          Icon(Icons.history_rounded, size: 48, color: theme.hintColor),
          const SizedBox(height: 16),
          Text(
            'No purchase returns yet',
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            'Posted returns appear here with credit and balance details.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
          ),
        ],
      );
    }

    return ListView.separated(
      padding: EdgeInsets.fromLTRB(pad, 12, pad, bottomInset),
      itemCount: returns.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        final r = returns[i];
        return GlassCard(
          padding: const EdgeInsets.all(16),
          child: InkWell(
            onTap: () => _showReturnSummaryDialog(context, r),
            borderRadius: BorderRadius.circular(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.receipt_long_rounded, color: AppColors.secondary, size: 22),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        r.returnInvoiceNumber,
                        style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                      ),
                    ),
                    Text(
                      _money(r.totalCreditAtCost),
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: AppColors.secondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  '${r.sourcePurchaseNumber} · ${r.supplierName}',
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
                ),
                const SizedBox(height: 8),
                Text(
                  r.reason.label,
                  style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SearchAndList extends StatelessWidget {
  const _SearchAndList({
    required this.searchCtrl,
    required this.onQuery,
    required this.results,
    required this.selected,
    required this.onSelect,
    this.bottomInset = 0,
  });

  final TextEditingController searchCtrl;
  final void Function(String) onQuery;
  final List<PurchaseInvoice> results;
  final PurchaseInvoice? selected;
  final void Function(PurchaseInvoice?) onSelect;
  final double bottomInset;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: searchCtrl,
          onChanged: onQuery,
          decoration: InputDecoration(
            hintText: 'Search purchase # or supplier',
            prefixIcon: const Icon(Icons.search_rounded),
            filled: true,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: results.isEmpty
              ? Center(
                  child: Text(
                    'No matching purchases',
                    style: theme.textTheme.bodyMedium?.copyWith(color: theme.hintColor),
                  ),
                )
              : ListView.separated(
                  padding: EdgeInsets.only(bottom: bottomInset),
                  itemCount: results.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    final p = results[i];
                    final sel = selected?.invoiceNumber == p.invoiceNumber;
                    return Material(
                      color: sel
                          ? AppColors.secondary.withValues(alpha: 0.12)
                          : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(14),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () => onSelect(p),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      p.invoiceNumber,
                                      style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                                    ),
                                    Text(
                                      p.supplierName,
                                      style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
                                    ),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    _money(p.grandTotal),
                                    style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800),
                                  ),
                                  Text(
                                    'Owed ${_money(p.effectiveRemainingBalance)}',
                                    style: theme.textTheme.labelSmall?.copyWith(color: theme.hintColor),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _EmptyDetail extends StatelessWidget {
  const _EmptyDetail({required this.wide});

  final bool wide;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.touch_app_rounded, size: wide ? 40 : 36, color: theme.hintColor),
            const SizedBox(height: 12),
            Text(
              'Select a purchase invoice',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(
              'Choose lines and quantities to return to the supplier.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReturnInvoicePanel extends StatelessWidget {
  const _ReturnInvoicePanel({
    required this.invoice,
    required this.pendingQty,
    required this.reason,
    required this.notesCtrl,
    required this.onReason,
    required this.onPendingChange,
    required this.previewCost,
    required this.onSubmit,
    required this.onClose,
    required this.wide,
    required this.bottomInset,
  });

  final PurchaseInvoice invoice;
  final Map<String, int> pendingQty;
  final PurchaseReturnReason reason;
  final TextEditingController notesCtrl;
  final void Function(PurchaseReturnReason) onReason;
  final void Function(String medicineId, int value, int maxRem) onPendingChange;
  final double previewCost;
  final VoidCallback onSubmit;
  final VoidCallback onClose;
  final bool wide;
  final double bottomInset;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasQty = pendingQty.values.any((q) => q > 0);

    return SingleChildScrollView(
      padding: EdgeInsets.only(bottom: bottomInset + 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              if (!wide)
                IconButton(
                  tooltip: 'Back',
                  onPressed: onClose,
                  icon: const Icon(Icons.arrow_back_rounded),
                ),
              Expanded(
                child: Text(
                  invoice.invoiceNumber,
                  style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900, letterSpacing: -0.5),
                ),
              ),
              if (wide)
                TextButton.icon(
                  onPressed: onClose,
                  icon: const Icon(Icons.close_rounded, size: 18),
                  label: const Text('Close'),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            invoice.supplierName,
            style: theme.textTheme.bodyMedium?.copyWith(color: theme.hintColor),
          ),
          const SizedBox(height: 6),
          Text(
            'Balance after credits: ${_money(invoice.effectiveRemainingBalance)}',
            style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 18),
          Text('Lines', style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          for (final line in invoice.lines) _LineRow(
            line: line,
            invoice: invoice,
            pendingQty: pendingQty,
            onPendingChange: onPendingChange,
          ),
          const SizedBox(height: 20),
          Text('Reason', style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final r in PurchaseReturnReason.values)
                ChoiceChip(
                  label: Text(r.label, style: theme.textTheme.labelSmall),
                  selected: reason == r,
                  onSelected: (_) => onReason(r),
                ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: notesCtrl,
            maxLines: 2,
            decoration: InputDecoration(
              labelText: 'Notes (optional)',
              alignLabelWithHint: true,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
          const SizedBox(height: 20),
          GlassCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Summary', style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 10),
                _SummaryRow(label: 'Return value (cost)', value: _money(previewCost)),
                _SummaryRow(
                  label: 'Max credit to invoice',
                  value: _money(previewCost.clamp(0, invoice.effectiveRemainingBalance)),
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: hasQty ? onSubmit : null,
                  icon: const Icon(Icons.check_rounded),
                  label: const Text('Post supplier return'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LineRow extends StatelessWidget {
  const _LineRow({
    required this.line,
    required this.invoice,
    required this.pendingQty,
    required this.onPendingChange,
  });

  final PurchaseInvoiceLine line;
  final PurchaseInvoice invoice;
  final Map<String, int> pendingQty;
  final void Function(String medicineId, int value, int maxRem) onPendingChange;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final maxRem = invoice.remainingReturnableQty(line);
    final cur = pendingQty[line.medicineId] ?? 0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(line.name, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                Text(
                  'Received ${line.quantity} · ${_money(line.buyingPrice)} cost',
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
                ),
                Text(
                  'Returnable: $maxRem',
                  style: theme.textTheme.labelSmall?.copyWith(color: AppColors.secondary, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                visualDensity: VisualDensity.compact,
                onPressed: cur > 0 ? () => onPendingChange(line.medicineId, cur - 1, maxRem) : null,
                icon: const Icon(Icons.remove_circle_outline_rounded),
              ),
              SizedBox(
                width: 28,
                child: Text(
                  '$cur',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                onPressed: cur < maxRem ? () => onPendingChange(line.medicineId, cur + 1, maxRem) : null,
                icon: const Icon(Icons.add_circle_outline_rounded),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Expanded(child: Text(label, style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor))),
          Text(value, style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

Future<void> _showReturnSummaryDialog(BuildContext context, PurchaseReturnRecord r) {
  final theme = Theme.of(context);
  return showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(r.returnInvoiceNumber, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Source: ${r.sourcePurchaseNumber}', style: theme.textTheme.bodySmall),
            Text(r.supplierName, style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor)),
            const SizedBox(height: 12),
            Text(r.reason.label, style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700)),
            if (r.notes.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(r.notes, style: theme.textTheme.bodySmall),
            ],
            const Divider(height: 24),
            for (final l in r.lines)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Expanded(child: Text('${l.medicineName} ×${l.quantity}')),
                    Text(_money(l.lineCredit), style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
            const Divider(height: 20),
            _SummaryRow(label: 'Total (cost)', value: _money(r.totalCreditAtCost)),
            _SummaryRow(label: 'Applied to invoice AP', value: _money(r.creditAppliedToInvoice)),
            _SummaryRow(label: 'Supplier balance reduced', value: _money(r.supplierBalanceReduced)),
          ],
        ),
      ),
      actions: [
        FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('Done')),
      ],
    ),
  );
}
