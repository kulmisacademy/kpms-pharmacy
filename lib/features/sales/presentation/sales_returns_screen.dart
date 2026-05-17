import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/receipt_branding.dart';
import '../../../core/navigation/kpms_breakpoints.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/kpms_feedback.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/kpms_mobile_bottom_nav.dart';
import '../../../core/widgets/kpms_page_shell.dart';
import '../../medicines/data/medicine_catalog_notifier.dart';
import '../../medicines/domain/medicine.dart';
import '../../medicines/domain/medicine_type_style.dart';
import '../../settings/application/pharmacy_settings_providers.dart';
import '../application/sales_ledger_notifier.dart';
import '../domain/completed_sale_invoice.dart';
import 'return_receipt_dialog.dart';

/// Invoice-based sales returns — search, line-level quantities, refund & stock.
class SalesReturnsScreen extends ConsumerStatefulWidget {
  const SalesReturnsScreen({super.key});

  @override
  ConsumerState<SalesReturnsScreen> createState() => _SalesReturnsScreenState();
}

class _SalesReturnsScreenState extends ConsumerState<SalesReturnsScreen> with SingleTickerProviderStateMixin {
  final _searchCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  late final TabController _tabs;
  String _query = '';
  CompletedSaleInvoice? _selected;
  final Map<String, int> _pendingQty = {};
  ReturnReason _reason = ReturnReason.wrongMedicine;

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

  void _selectInvoice(CompletedSaleInvoice? inv) {
    setState(() {
      _selected = inv;
      _pendingQty.clear();
      _notesCtrl.clear();
      _reason = ReturnReason.wrongMedicine;
    });
  }

  void _setPending(String lineId, int value, int maxRem) {
    final v = value.clamp(0, maxRem);
    setState(() {
      if (v == 0) {
        _pendingQty.remove(lineId);
      } else {
        _pendingQty[lineId] = v;
      }
    });
  }

  double _previewRefund(CompletedSaleInvoice inv) {
    var t = 0.0;
    for (final line in inv.lines) {
      final q = _pendingQty[line.lineId] ?? 0;
      t += line.unitSell * q;
    }
    return t;
  }

  double _previewProfitCut(CompletedSaleInvoice inv) {
    var t = 0.0;
    for (final line in inv.lines) {
      final q = _pendingQty[line.lineId] ?? 0;
      t += line.marginPerUnit * q;
    }
    return t;
  }

  Future<void> _submitReturn(CompletedSaleInvoice inv) async {
    final err = ref.read(salesLedgerProvider.notifier).processReturn(
          invoiceNumber: inv.invoiceNumber,
          returnQtyByLineId: Map<String, int>.from(_pendingQty)
            ..removeWhere((_, q) => q <= 0),
          reason: _reason,
          notes: _notesCtrl.text,
          cashierName: KpmsReceiptBranding.defaultCashier,
        );
    if (!mounted) return;
    if (err != null) {
      kpmsSnack(context, err, isError: true);
      return;
    }
    HapticFeedback.mediumImpact();
    final record = ref.read(salesLedgerProvider).returns.first;
    await showReturnReceiptDialog(context, record, ref.read(pharmacyBrandingProvider));
    if (!mounted) return;
    _selectInvoice(null);
    kpmsSnack(context, 'Return processed');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final width = MediaQuery.sizeOf(context).width;
    final wide = width >= 960;
    final pad = KpmsBreakpoints.pagePaddingHorizontal(width);
    final clearance = KpmsMobileBottomNav.scrollClearanceBottom(context);

    ref.watch(salesLedgerProvider);
    final results = ref.read(salesLedgerProvider.notifier).searchInvoices(_query);

    return KpmsPageShell(
      title: 'Sales returns',
      subtitle: 'Invoice lookup · refunds · stock restore',
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
                                  onSelect: _selectInvoice,
                                ),
                              ),
                              const SizedBox(width: 16),
                              const VerticalDivider(width: 1),
                              const SizedBox(width: 16),
                              Expanded(
                                flex: 6,
                                child: _selected == null
                                    ? const _EmptyDetailPlaceholder(wide: true)
                                    : _InvoiceReturnPanel(
                                        invoice: _selected!,
                                        catalog: ref.watch(medicineCatalogProvider),
                                        pendingQty: _pendingQty,
                                        reason: _reason,
                                        notesCtrl: _notesCtrl,
                                        onReason: (r) => setState(() => _reason = r),
                                        onPendingChange: _setPending,
                                        previewRefund: _previewRefund(_selected!),
                                        previewProfitCut: _previewProfitCut(_selected!),
                                        onSubmit: () => _submitReturn(_selected!),
                                        onClose: () => _selectInvoice(null),
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
                                  onSelect: _selectInvoice,
                                  bottomInset: clearance + 16,
                                )
                              : _InvoiceReturnPanel(
                                  invoice: _selected!,
                                  catalog: ref.watch(medicineCatalogProvider),
                                  pendingQty: _pendingQty,
                                  reason: _reason,
                                  notesCtrl: _notesCtrl,
                                  onReason: (r) => setState(() => _reason = r),
                                  onPendingChange: _setPending,
                                  previewRefund: _previewRefund(_selected!),
                                  previewProfitCut: _previewProfitCut(_selected!),
                                  onSubmit: () => _submitReturn(_selected!),
                                  onClose: () => _selectInvoice(null),
                                  wide: false,
                                  bottomInset: clearance + 16,
                                ),
                        ),
                  _ReturnHistoryTab(pad: pad, clearance: clearance),
                ],
              ),
            ),
          ],
        ),
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
  final ValueChanged<String> onQuery;
  final List<CompletedSaleInvoice> results;
  final CompletedSaleInvoice? selected;
  final void Function(CompletedSaleInvoice?) onSelect;
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
            hintText: 'Invoice #, customer name, or phone',
            prefixIcon: const Icon(Icons.search_rounded),
            filled: true,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Matching invoices',
          style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 10),
        Expanded(
          child: results.isEmpty
              ? Center(
                  child: Text(
                    'No invoices yet — complete a sale at checkout.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(color: theme.hintColor),
                  ),
                )
              : ListView.separated(
                  padding: EdgeInsets.only(bottom: bottomInset),
                  itemCount: results.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 10),
                  itemBuilder: (context, i) {
                    final inv = results[i];
                    final isSel = selected?.invoiceNumber == inv.invoiceNumber;
                    return TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: 1),
                      duration: Duration(milliseconds: 220 + i * 24),
                      curve: Curves.easeOutCubic,
                      builder: (context, t, child) => Opacity(
                        opacity: t,
                        child: Transform.translate(offset: Offset(0, 6 * (1 - t)), child: child),
                      ),
                      child: _InvoiceListTile(
                        invoice: inv,
                        selected: isSel,
                        onTap: () => onSelect(inv),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _InvoiceListTile extends StatelessWidget {
  const _InvoiceListTile({
    required this.invoice,
    required this.selected,
    required this.onTap,
  });

  final CompletedSaleInvoice invoice;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final st = invoice.returnStatus;
    final chip = switch (st) {
      InvoiceReturnStatus.none => ('Open', AppColors.primary.withValues(alpha: 0.12), AppColors.primaryDark),
      InvoiceReturnStatus.partial => ('Partial return', Colors.orange.withValues(alpha: 0.15), Colors.orange.shade800),
      InvoiceReturnStatus.fullyReturned => ('Fully returned', theme.colorScheme.surfaceContainerHighest, theme.hintColor),
    };

    return Material(
      color: selected ? AppColors.primary.withValues(alpha: 0.08) : theme.colorScheme.surface,
      elevation: selected ? 0 : 0.5,
      shadowColor: Colors.black12,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
                    const SizedBox(height: 4),
                    Text(
                      invoice.customerName,
                      style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '\$${invoice.total.toStringAsFixed(2)}',
                    style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: chip.$2,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      chip.$1,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: chip.$3,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyDetailPlaceholder extends StatelessWidget {
  const _EmptyDetailPlaceholder({required this.wide});

  final bool wide;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.touch_app_rounded, size: 48, color: theme.hintColor.withValues(alpha: 0.6)),
          const SizedBox(height: 16),
          Text(
            'Select an invoice to start a return',
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: theme.hintColor,
            ),
          ),
          if (wide) ...[
            const SizedBox(height: 8),
            Text(
              'Search by number, customer, or phone.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
            ),
          ],
        ],
      ),
    );
  }
}

class _InvoiceReturnPanel extends StatelessWidget {
  const _InvoiceReturnPanel({
    required this.invoice,
    required this.catalog,
    required this.pendingQty,
    required this.reason,
    required this.notesCtrl,
    required this.onReason,
    required this.onPendingChange,
    required this.previewRefund,
    required this.previewProfitCut,
    required this.onSubmit,
    required this.onClose,
    required this.wide,
    required this.bottomInset,
  });

  final CompletedSaleInvoice invoice;
  final List<Medicine> catalog;
  final Map<String, int> pendingQty;
  final ReturnReason reason;
  final TextEditingController notesCtrl;
  final ValueChanged<ReturnReason> onReason;
  final void Function(String lineId, int value, int maxRem) onPendingChange;
  final double previewRefund;
  final double previewProfitCut;
  final VoidCallback onSubmit;
  final VoidCallback onClose;
  final bool wide;
  final double bottomInset;

  Medicine? _med(String id) {
    for (final m in catalog) {
      if (m.id == id) return m;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fully = invoice.returnStatus == InvoiceReturnStatus.fullyReturned;
    final canSubmit = !fully && previewRefund > 0.009;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!wide)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                IconButton(
                  onPressed: onClose,
                  icon: const Icon(Icons.arrow_back_rounded),
                  tooltip: 'Back',
                ),
                Expanded(
                  child: Text(
                    invoice.invoiceNumber,
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
                  ),
                ),
              ],
            ),
          ),
        Expanded(
          child: ScrollConfiguration(
            behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
            child: SingleChildScrollView(
              padding: EdgeInsets.only(bottom: bottomInset),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _InvoiceHeaderCard(invoice: invoice),
                  const SizedBox(height: 16),
                  if (fully)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Material(
                        color: theme.colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(14),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Row(
                            children: [
                              Icon(Icons.info_outline_rounded, color: theme.hintColor),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'All items on this invoice were returned.',
                                  style: theme.textTheme.bodyMedium,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  Text(
                    'Medicines',
                    style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 10),
                  ...invoice.lines.map((line) {
                    final med = _med(line.medicineId);
                    final pq = pendingQty[line.lineId] ?? 0;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _ReturnLineCard(
                        line: line,
                        medicine: med,
                        pendingReturn: pq,
                        onPendingChange: (v) => onPendingChange(line.lineId, v, line.quantityRemaining),
                      ),
                    );
                  }),
                  const SizedBox(height: 8),
                  _ReturnReasonCard(
                    reason: reason,
                    notesCtrl: notesCtrl,
                    onReason: onReason,
                  ),
                  const SizedBox(height: 16),
                  _RefundSummaryCard(
                    returnedTotal: previewRefund,
                    profitReduction: previewProfitCut,
                  ),
                  SizedBox(height: wide ? 16 : 24),
                  FilledButton.icon(
                    onPressed: canSubmit ? onSubmit : null,
                    icon: const Icon(Icons.assignment_turned_in_rounded),
                    label: const Text('Complete return'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _InvoiceHeaderCard extends StatelessWidget {
  const _InvoiceHeaderCard({required this.invoice});

  final CompletedSaleInvoice invoice;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateStr = '${invoice.issuedAt.year}-${invoice.issuedAt.month.toString().padLeft(2, '0')}-${invoice.issuedAt.day.toString().padLeft(2, '0')}';

    return GlassCard(
      borderRadius: 20,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.local_pharmacy_rounded, color: AppColors.primary, size: 32),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      KpmsReceiptBranding.businessName,
                      style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900),
                    ),
                    Text(
                      KpmsReceiptBranding.address,
                      style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Divider(color: theme.colorScheme.outline.withValues(alpha: 0.12)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 20,
            runSpacing: 12,
            children: [
              _kv(theme, 'Invoice', invoice.invoiceNumber),
              _kv(theme, 'Customer', invoice.customerName),
              _kv(theme, 'Phone', invoice.customerPhone.isEmpty ? '—' : invoice.customerPhone),
              _kv(theme, 'Date', dateStr),
              _kv(theme, 'Payment', invoice.paymentMethod),
              _kv(theme, 'Cashier', invoice.cashierName),
              _kv(theme, 'Total', '\$${invoice.total.toStringAsFixed(2)}'),
              _kv(theme, 'Profit at sale', '\$${invoice.profitAtSale.toStringAsFixed(2)}'),
              _kv(theme, 'Profit (current)', '\$${invoice.profitAfterReturns.toStringAsFixed(2)}'),
              _kv(theme, 'Return status', _statusLabel(invoice.returnStatus)),
            ],
          ),
        ],
      ),
    );
  }

  String _statusLabel(InvoiceReturnStatus s) => switch (s) {
        InvoiceReturnStatus.none => 'None',
        InvoiceReturnStatus.partial => 'Partial',
        InvoiceReturnStatus.fullyReturned => 'Complete',
      };

  Widget _kv(ThemeData theme, String k, String v) {
    return SizedBox(
      width: 160,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(k, style: theme.textTheme.labelSmall?.copyWith(color: theme.hintColor, fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          Text(v, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _ReturnLineCard extends StatelessWidget {
  const _ReturnLineCard({
    required this.line,
    required this.medicine,
    required this.pendingReturn,
    required this.onPendingChange,
  });

  final SoldLineItem line;
  final Medicine? medicine;
  final int pendingReturn;
  final ValueChanged<int> onPendingChange;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = medicine != null ? MedicineTypeStyle.resolve(medicine!) : null;
    final rem = line.quantityRemaining;
    final retAmt = line.unitSell * pendingReturn;

    return GlassCard(
      borderRadius: 18,
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              width: 48,
              height: 48,
              child: medicine?.imageBytes != null
                  ? Image.memory(medicine!.imageBytes!, fit: BoxFit.cover)
                  : DecoratedBox(
                      decoration: BoxDecoration(
                        color: style?.softBg ?? theme.colorScheme.surfaceContainerHighest,
                      ),
                      child: Icon(
                        style?.icon ?? Icons.medication_liquid_rounded,
                        color: style?.accent ?? AppColors.primary,
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  line.name,
                  style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 6),
                Text(
                  'Sold ${line.quantitySold} · Returned ${line.quantityReturned} · Remaining $rem',
                  style: theme.textTheme.labelMedium?.copyWith(color: theme.hintColor),
                ),
                const SizedBox(height: 4),
                Text(
                  'Sell \$${line.unitSell.toStringAsFixed(2)} · Return \$${retAmt.toStringAsFixed(2)}',
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
          Column(
            children: [
              Text(
                'Return qty',
                style: theme.textTheme.labelSmall?.copyWith(color: theme.hintColor),
              ),
              const SizedBox(height: 6),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                child: rem <= 0
                    ? Padding(
                        key: const ValueKey('done'),
                        padding: const EdgeInsets.only(top: 8),
                        child: Text('—', style: theme.textTheme.bodyLarge),
                      )
                    : _QtyStepper(
                        key: ValueKey(line.lineId),
                        value: pendingReturn,
                        max: rem,
                        onChanged: onPendingChange,
                      ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _QtyStepper extends StatelessWidget {
  const _QtyStepper({
    super.key,
    required this.value,
    required this.max,
    required this.onChanged,
  });

  final int value;
  final int max;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            onPressed: value > 0 ? () => onChanged(value - 1) : null,
            icon: const Icon(Icons.remove_rounded, size: 20),
            visualDensity: VisualDensity.compact,
          ),
          SizedBox(
            width: 28,
            child: Text(
              '$value',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900),
            ),
          ),
          IconButton(
            onPressed: value < max ? () => onChanged(value + 1) : null,
            icon: const Icon(Icons.add_rounded, size: 20),
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}

class _ReturnReasonCard extends StatelessWidget {
  const _ReturnReasonCard({
    required this.reason,
    required this.notesCtrl,
    required this.onReason,
  });

  final ReturnReason reason;
  final TextEditingController notesCtrl;
  final ValueChanged<ReturnReason> onReason;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GlassCard(
      borderRadius: 20,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Return reason',
            style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<ReturnReason>(
            key: ValueKey(reason),
            initialValue: reason,
            decoration: InputDecoration(
              labelText: 'Reason',
              filled: true,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
            ),
            items: [
              for (final r in ReturnReason.values)
                DropdownMenuItem(value: r, child: Text(r.label)),
            ],
            onChanged: (v) {
              if (v != null) onReason(v);
            },
          ),
          const SizedBox(height: 12),
          TextField(
            controller: notesCtrl,
            maxLines: 2,
            decoration: InputDecoration(
              labelText: 'Notes (optional)',
              alignLabelWithHint: true,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ],
      ),
    );
  }
}

class _RefundSummaryCard extends StatelessWidget {
  const _RefundSummaryCard({
    required this.returnedTotal,
    required this.profitReduction,
  });

  final double returnedTotal;
  final double profitReduction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GlassCard(
      borderRadius: 20,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.payments_rounded, color: AppColors.primary),
              const SizedBox(width: 10),
              Text(
                'Refund summary',
                style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _row(theme, 'Returned items total', '\$${returnedTotal.toStringAsFixed(2)}', strong: true),
          const SizedBox(height: 8),
          _row(theme, 'Refund amount', '\$${returnedTotal.toStringAsFixed(2)}', muted: true),
          const SizedBox(height: 8),
          _row(theme, 'Profit reduction', '−\$${profitReduction.toStringAsFixed(2)}', warn: true),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 14),
            child: Divider(height: 1),
          ),
          _row(
            theme,
            'Final adjustment',
            '−\$${profitReduction.toStringAsFixed(2)} profit · +\$${returnedTotal.toStringAsFixed(2)} refund',
            strong: true,
          ),
        ],
      ),
    );
  }

  Widget _row(ThemeData theme, String a, String b, {bool strong = false, bool muted = false, bool warn = false}) {
    Color? c;
    if (muted) c = theme.hintColor;
    if (warn) c = Colors.orange.shade800;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          a,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: strong ? FontWeight.w800 : null,
            color: c,
          ),
        ),
        Text(
          b,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w800,
            color: c,
          ),
        ),
      ],
    );
  }
}

class _ReturnHistoryTab extends ConsumerWidget {
  const _ReturnHistoryTab({required this.pad, required this.clearance});

  final double pad;
  final double clearance;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final list = ref.watch(salesLedgerProvider).returns;

    if (list.isEmpty) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(pad),
          child: Text(
            'No returns recorded yet.',
            style: theme.textTheme.bodyLarge?.copyWith(color: theme.hintColor),
          ),
        ),
      );
    }

    return ListView.separated(
      padding: EdgeInsets.fromLTRB(pad, 12, pad, 16 + clearance),
      itemCount: list.length,
      separatorBuilder: (context, index) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        final r = list[i];
        return GlassCard(
          borderRadius: 18,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    r.returnInvoiceNumber,
                    style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900),
                  ),
                  Text(
                    '\$${r.refundTotal.toStringAsFixed(2)}',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'From ${r.originalInvoiceNumber} · ${r.reason.label}',
                style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
              ),
            ],
          ),
        );
      },
    );
  }
}
