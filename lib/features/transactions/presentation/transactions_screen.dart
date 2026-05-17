import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/navigation/kpms_breakpoints.dart';
import '../../../core/utils/kpms_feedback.dart';
import '../../../core/widgets/kpms_page_shell.dart';
import '../application/ledger_tx_flat_provider.dart';
import '../../settings/application/pharmacy_settings_providers.dart';
import '../application/transaction_export_service.dart';
import '../domain/ledger_tx_view.dart';
import 'ledger_transaction_actions.dart';

class TransactionsScreen extends ConsumerStatefulWidget {
  const TransactionsScreen({super.key});

  @override
  ConsumerState<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends ConsumerState<TransactionsScreen> {
  final _search = TextEditingController();
  Timer? _searchDebounce;
  String _searchCommitted = '';
  String _type = 'all';
  String _staff = '';
  String _payment = '';
  DateTimeRange? _range;
  int _page = 0;
  static const _pageSize = 25;
  bool _filtersExpanded = false;

  @override
  void initState() {
    super.initState();
    _searchCommitted = _search.text.trim().toLowerCase();
  }

  int _activeFilterCount() {
    var n = 0;
    if (_searchCommitted.isNotEmpty) n++;
    if (_type != 'all') n++;
    if (_staff.isNotEmpty) n++;
    if (_payment.isNotEmpty) n++;
    if (_range != null) n++;
    return n;
  }

  String _filterSummary() {
    final parts = <String>[];
    if (_searchCommitted.isNotEmpty) parts.add('Search');
    if (_type != 'all') {
      parts.add(switch (_type) {
        'sale' => 'Sales',
        'return' => 'Returns',
        'purchase' => 'Purchases',
        _ => _type,
      });
    }
    if (_staff.isNotEmpty) parts.add(_staff);
    if (_payment.isNotEmpty) parts.add('Status');
    if (_range != null) parts.add('Date range');
    return parts.join(' · ');
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _scheduleSearchCommit() {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 220), () {
      final next = _search.text.trim().toLowerCase();
      if (!mounted || next == _searchCommitted) return;
      setState(() {
        _searchCommitted = next;
        _page = 0;
      });
    });
  }

  void _commitSearchImmediate() {
    _searchDebounce?.cancel();
    final next = _search.text.trim().toLowerCase();
    setState(() {
      _searchCommitted = next;
      _page = 0;
    });
  }

  void _onApplyFilters() {
    _searchDebounce?.cancel();
    final next = _search.text.trim().toLowerCase();
    setState(() {
      _searchCommitted = next;
      _page = 0;
      _filtersExpanded = false;
    });
  }

  List<LedgerTxView> _filtered(List<LedgerTxView> all) {
    var rows = all;
    final q = _searchCommitted;
    if (q.isNotEmpty) {
      rows = rows
          .where(
            (r) =>
                r.reference.toLowerCase().contains(q) ||
                r.party.toLowerCase().contains(q) ||
                r.staffLabel.toLowerCase().contains(q) ||
                r.paymentMethod.toLowerCase().contains(q),
          )
          .toList();
    }
    if (_type != 'all') {
      final t = _type.toLowerCase();
      rows = rows.where((r) {
        final k = r.kindLabel.toLowerCase();
        if (t == 'sale') return k == 'sale';
        if (t == 'return') return k.contains('return');
        if (t == 'purchase') return k.contains('purchase');
        return true;
      }).toList();
    }
    if (_staff.isNotEmpty) {
      rows = rows.where((r) => r.staffLabel == _staff).toList();
    }
    if (_payment.isNotEmpty) {
      final p = _payment.toLowerCase();
      rows = rows.where((r) => r.status.toLowerCase().contains(p)).toList();
    }
    if (_range != null) {
      final end = _range!.end.add(const Duration(days: 1)).subtract(const Duration(microseconds: 1));
      rows = rows.where((r) => !r.sortAt.isBefore(_range!.start) && !r.sortAt.isAfter(end)).toList();
    }
    return rows;
  }

  Future<void> _pickRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 1),
      initialDateRange: _range ?? DateTimeRange(start: now.subtract(const Duration(days: 30)), end: now),
    );
    if (picked != null) setState(() => _range = picked);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pad = KpmsBreakpoints.pagePaddingHorizontal(MediaQuery.sizeOf(context).width);
    final branding = ref.watch(pharmacyBrandingProvider);
    final pharmacyName = branding.businessName;

    final all = ref.watch(ledgerTxFlatProvider);
    final staffNames = all.map((e) => e.staffLabel).where((s) => s.trim().isNotEmpty && s != '—').toSet().toList()
      ..sort();
    final filtered = _filtered(all);
    final totalPages = (filtered.length / _pageSize).ceil().clamp(1, 1 << 20);
    if (_page >= totalPages) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _page = totalPages - 1);
      });
    }
    final page = _page >= totalPages ? totalPages - 1 : _page;
    final start = page * _pageSize;
    final pageRows = filtered.skip(start).take(_pageSize).toList();

    return KpmsPageShell(
      title: 'Transactions',
      subtitle: 'Sales · returns · purchases (this device)',
      actions: [
        PopupMenuButton<String>(
          icon: const Icon(Icons.ios_share_rounded),
          tooltip: 'Export',
          onSelected: (v) async {
            try {
              if (v == 'pdf') {
                await TransactionExportService.exportPdf(
                  filtered,
                  pharmacyName: pharmacyName,
                  logoUrl: branding.logoUrl,
                );
              } else if (v == 'csv') {
                await TransactionExportService.exportCsv(filtered, pharmacyName: pharmacyName);
              } else if (v == 'xlsx') {
                await TransactionExportService.exportExcel(filtered, pharmacyName: pharmacyName);
              }
            } catch (e) {
              if (context.mounted) kpmsSnackError(context, e, fallback: 'Export could not be completed.');
            }
          },
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'pdf', child: Text('PDF')),
            PopupMenuItem(value: 'csv', child: Text('CSV')),
            PopupMenuItem(value: 'xlsx', child: Text('Excel')),
          ],
        ),
      ],
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(pad, 0, pad, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _TransactionsFilterToggleBar(
                  theme: theme,
                  expanded: _filtersExpanded,
                  activeCount: _activeFilterCount(),
                  summary: _filterSummary(),
                  onTap: () => setState(() => _filtersExpanded = !_filtersExpanded),
                ),
                AnimatedSize(
                  duration: const Duration(milliseconds: 260),
                  curve: Curves.easeInOutCubic,
                  alignment: Alignment.topCenter,
                  child: _filtersExpanded
                      ? Padding(
                          padding: const EdgeInsets.only(top: 10),
                          child: _TransactionsFilterPanel(
                            theme: theme,
                            searchController: _search,
                            type: _type,
                            staff: _staff,
                            payment: _payment,
                            range: _range,
                            staffNames: staffNames,
                            onSearchSubmitted: _commitSearchImmediate,
                            onSearchChanged: _scheduleSearchCommit,
                            onPickRange: _pickRange,
                            onClearRange: () => setState(() => _range = null),
                            onTypeChanged: (v) => setState(() => _type = v ?? 'all'),
                            onStaffChanged: (v) => setState(() => _staff = v ?? ''),
                            onPaymentChanged: (v) => setState(() => _payment = v ?? ''),
                            onApply: _onApplyFilters,
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: pad),
            child: Text('${filtered.length} rows', style: theme.textTheme.labelMedium),
          ),
          const SizedBox(height: 6),
          Expanded(
            child: pageRows.isEmpty
                ? Center(child: Text('No transactions match filters.', style: theme.textTheme.bodyLarge))
                : ListView.separated(
                    padding: EdgeInsets.fromLTRB(pad, 0, pad, 24),
                    itemCount: pageRows.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (ctx, i) {
                      final r = pageRows[i];
                      final amt = r.amount;
                      final sign = amt < 0 ? '-' : '';
                      final abs = amt.abs().toStringAsFixed(2);
                      return Card(
                        margin: EdgeInsets.zero,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(10, 10, 6, 10),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${r.kindLabel} · ${r.reference}',
                                      style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      r.whenLabel,
                                      style: theme.textTheme.labelMedium?.copyWith(
                                        color: theme.colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(r.party, style: theme.textTheme.bodySmall),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Payment · ${r.paymentMethod}',
                                      style: theme.textTheme.labelSmall?.copyWith(
                                        color: theme.colorScheme.onSurfaceVariant,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    Text(
                                      'Status · ${r.status} · Staff · ${r.staffLabel}',
                                      style: theme.textTheme.labelSmall?.copyWith(
                                        color: theme.colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    '$sign\$$abs',
                                    style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                                  ),
                                  const SizedBox(height: 6),
                                  TextButton.icon(
                                    onPressed: () => showLedgerTransactionActions(context, ref, r),
                                    icon: const Icon(Icons.visibility_outlined, size: 18),
                                    label: const Text('View'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
          if (totalPages > 1)
            Padding(
              padding: EdgeInsets.fromLTRB(pad, 0, pad, 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    onPressed: page > 0 ? () => setState(() => _page = page - 1) : null,
                    icon: const Icon(Icons.chevron_left),
                  ),
                  Text('Page ${page + 1} / $totalPages'),
                  IconButton(
                    onPressed: page < totalPages - 1 ? () => setState(() => _page = page + 1) : null,
                    icon: const Icon(Icons.chevron_right),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Single tappable row — expands the full filter panel below.
class _TransactionsFilterToggleBar extends StatelessWidget {
  const _TransactionsFilterToggleBar({
    required this.theme,
    required this.expanded,
    required this.activeCount,
    required this.summary,
    required this.onTap,
  });

  final ThemeData theme;
  final bool expanded;
  final int activeCount;
  final String summary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final primary = theme.colorScheme.primary;
    final surface = theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.55);

    Widget trailIcon() {
      return Icon(
        expanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
        color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
      );
    }

    return Material(
      color: surface,
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Icon(Icons.tune_rounded, color: primary, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      expanded ? 'Filters' : 'Filter transactions',
                      style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    if (!expanded && summary.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          summary,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              if (activeCount > 0)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      child: Text(
                        '$activeCount active',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: primary,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ),
              trailIcon(),
            ],
          ),
        ),
      ),
    );
  }
}

class _TransactionsFilterPanel extends StatelessWidget {
  const _TransactionsFilterPanel({
    required this.theme,
    required this.searchController,
    required this.type,
    required this.staff,
    required this.payment,
    required this.range,
    required this.staffNames,
    required this.onSearchSubmitted,
    required this.onSearchChanged,
    required this.onPickRange,
    required this.onClearRange,
    required this.onTypeChanged,
    required this.onStaffChanged,
    required this.onPaymentChanged,
    required this.onApply,
  });

  final ThemeData theme;
  final TextEditingController searchController;
  final String type;
  final String staff;
  final String payment;
  final DateTimeRange? range;
  final List<String> staffNames;
  final VoidCallback onSearchSubmitted;
  final VoidCallback onSearchChanged;
  final VoidCallback onPickRange;
  final VoidCallback onClearRange;
  final ValueChanged<String?> onTypeChanged;
  final ValueChanged<String?> onStaffChanged;
  final ValueChanged<String?> onPaymentChanged;
  final VoidCallback onApply;

  static String _rangeButtonLabel(DateTimeRange? r) {
    if (r == null) return 'Date range';
    String m(DateTime d) => '${d.month}/${d.day}/${d.year}';
    return '${m(r.start)} – ${m(r.end)}';
  }

  InputDecoration _inputDecoration({String? hintText, String? labelText, Widget? prefixIcon}) {
    final br = BorderRadius.circular(12);
    final outline = theme.colorScheme.outline.withValues(alpha: 0.28);
    return InputDecoration(
      hintText: hintText,
      labelText: labelText,
      prefixIcon: prefixIcon,
      isDense: true,
      filled: true,
      fillColor: theme.colorScheme.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
      border: OutlineInputBorder(borderRadius: br),
      enabledBorder: OutlineInputBorder(borderRadius: br, borderSide: BorderSide(color: outline)),
      focusedBorder: OutlineInputBorder(
        borderRadius: br,
        borderSide: BorderSide(color: theme.colorScheme.primary, width: 1.5),
      ),
    );
  }

  Widget _dateRangeControls() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        FilledButton.tonalIcon(
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            visualDensity: VisualDensity.compact,
          ),
          onPressed: onPickRange,
          icon: const Icon(Icons.date_range_rounded, size: 20),
          label: Text(_rangeButtonLabel(range)),
        ),
        if (range != null)
          TextButton.icon(
            onPressed: onClearRange,
            icon: const Icon(Icons.close_rounded, size: 18),
            label: const Text('Clear'),
          ),
      ],
    );
  }

  Widget _typeField() {
    return DropdownButtonFormField<String>(
      // ignore: deprecated_member_use — controlled selection (type updates from parent state).
      value: type,
      isExpanded: true,
      decoration: _inputDecoration(labelText: 'Type'),
      items: const [
        DropdownMenuItem(value: 'all', child: Text('All types')),
        DropdownMenuItem(value: 'sale', child: Text('Sales')),
        DropdownMenuItem(value: 'return', child: Text('Returns')),
        DropdownMenuItem(value: 'purchase', child: Text('Purchases')),
      ],
      onChanged: onTypeChanged,
    );
  }

  Widget _staffField() {
    return DropdownButtonFormField<String>(
      // ignore: deprecated_member_use — controlled selection.
      value: staff.isEmpty ? '' : staff,
      isExpanded: true,
      decoration: _inputDecoration(labelText: 'Staff'),
      items: [
        const DropdownMenuItem(value: '', child: Text('All staff')),
        for (final s in staffNames) DropdownMenuItem(value: s, child: Text(s)),
      ],
      onChanged: onStaffChanged,
    );
  }

  Widget _statusField() {
    return DropdownButtonFormField<String>(
      // ignore: deprecated_member_use — controlled selection.
      value: payment.isEmpty ? '' : payment,
      isExpanded: true,
      decoration: _inputDecoration(labelText: 'Status'),
      items: const [
        DropdownMenuItem(value: '', child: Text('All status')),
        DropdownMenuItem(value: 'paid', child: Text('Paid / settled')),
        DropdownMenuItem(value: 'open', child: Text('Open balance')),
        DropdownMenuItem(value: 'partial', child: Text('Partial')),
      ],
      onChanged: onPaymentChanged,
    );
  }

  Widget _applyButton({bool stretch = false}) {
    final btn = FilledButton(
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
        visualDensity: VisualDensity.standard,
      ),
      onPressed: onApply,
      child: const Text('Apply'),
    );
    if (stretch) return SizedBox(width: double.infinity, child: btn);
    return btn;
  }

  @override
  Widget build(BuildContext context) {
    final searchField = TextField(
      controller: searchController,
      decoration: _inputDecoration(
        hintText: 'Search reference, party, or staff…',
        prefixIcon: Icon(Icons.search_rounded, color: theme.colorScheme.primary.withValues(alpha: 0.85)),
      ).copyWith(contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14)),
      onChanged: (_) => onSearchChanged(),
      onSubmitted: (_) => onSearchSubmitted(),
    );

    return Material(
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: LayoutBuilder(
          builder: (context, c) {
            final wide = c.maxWidth >= 900;
            final medium = c.maxWidth >= 540;

            if (wide) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(flex: 3, child: searchField),
                  const SizedBox(width: 12),
                  _dateRangeControls(),
                  const SizedBox(width: 12),
                  SizedBox(width: 152, child: _typeField()),
                  const SizedBox(width: 10),
                  SizedBox(width: 152, child: _staffField()),
                  const SizedBox(width: 10),
                  SizedBox(width: 152, child: _statusField()),
                  const SizedBox(width: 12),
                  _applyButton(),
                ],
              );
            }

            if (medium) {
              final cramped = c.maxWidth < 780;
              if (!cramped) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(child: searchField),
                        const SizedBox(width: 12),
                        _dateRangeControls(),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(child: _typeField()),
                        const SizedBox(width: 10),
                        Expanded(child: _staffField()),
                        const SizedBox(width: 10),
                        Expanded(child: _statusField()),
                        const SizedBox(width: 12),
                        _applyButton(),
                      ],
                    ),
                  ],
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(child: searchField),
                      const SizedBox(width: 12),
                      _dateRangeControls(),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(child: _typeField()),
                      const SizedBox(width: 10),
                      Expanded(child: _staffField()),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(child: _statusField()),
                      const SizedBox(width: 12),
                      _applyButton(),
                    ],
                  ),
                ],
              );
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                searchField,
                const SizedBox(height: 12),
                _dateRangeControls(),
                const SizedBox(height: 14),
                _typeField(),
                const SizedBox(height: 12),
                _staffField(),
                const SizedBox(height: 12),
                _statusField(),
                const SizedBox(height: 14),
                _applyButton(stretch: true),
              ],
            );
          },
        ),
      ),
    );
  }
}
