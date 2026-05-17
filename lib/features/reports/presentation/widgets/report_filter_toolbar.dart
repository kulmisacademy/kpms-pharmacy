import 'package:flutter/material.dart';

import '../../domain/kpms_report_id.dart';
import '../../domain/report_date_filter.dart';
import '../../domain/report_view_filters.dart';

typedef ReportFiltersChanged = void Function(ReportViewFilters filters);

/// ERP-style filter strip: date presets, custom range, contextual dimensions.
class ReportFilterToolbar extends StatelessWidget {
  const ReportFilterToolbar({
    super.key,
    required this.reportId,
    required this.filters,
    required this.onChanged,
    required this.supplierOptions,
    required this.customerOptions,
    required this.medicineOptions,
    required this.staffOptions,
  });

  final KpmsReportId reportId;
  final ReportViewFilters filters;
  final ReportFiltersChanged onChanged;
  final List<String> supplierOptions;
  final List<String> customerOptions;
  final List<String> medicineOptions;
  final List<String> staffOptions;

  static const _payment = ['All', 'Cash', 'EVC Plus', 'E-Dahab', 'Jeeb'];
  static const _status = ['All', 'Paid', 'Partial', 'Open', 'Received', 'Closed'];

  Future<void> _pickCustom(BuildContext context) async {
    final now = DateTime.now();
    final initial = filters.customRange ?? DateTimeRange(start: now.subtract(const Duration(days: 7)), end: now);
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2019),
      lastDate: DateTime(now.year + 1),
      initialDateRange: initial,
    );
    if (picked != null) {
      onChanged(filters.copyWith(datePreset: ReportDatePreset.custom, customRange: picked));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final presets = ReportDatePreset.values.where((p) => p != ReportDatePreset.custom).toList();

    Widget dateChips = Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final p in presets)
          FilterChip(
            label: Text(p.label),
            selected: filters.datePreset == p,
            showCheckmark: false,
            onSelected: (_) => onChanged(filters.copyWith(datePreset: p, clearCustomRange: true)),
          ),
        FilterChip(
          label: const Text('Custom'),
          selected: filters.datePreset == ReportDatePreset.custom,
          showCheckmark: false,
          onSelected: (_) => _pickCustom(context),
        ),
      ],
    );

    Widget dim(String label, String value, List<String> options, void Function(String) onSel) {
      return Padding(
        padding: const EdgeInsets.only(right: 10, bottom: 8),
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: label,
            isDense: true,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              isExpanded: true,
              value: options.contains(value) ? value : options.first,
              items: [for (final o in options) DropdownMenuItem(value: o, child: Text(o, overflow: TextOverflow.ellipsis))],
              onChanged: (v) {
                if (v != null) onSel(v);
              },
            ),
          ),
        ),
      );
    }

    final extras = <Widget>[];
    switch (reportId) {
      case KpmsReportId.purchases:
      case KpmsReportId.supplierReport:
        extras.addAll([
          dim('Supplier', filters.supplier, supplierOptions, (v) => onChanged(filters.copyWith(supplier: v))),
        ]);
        break;
      case KpmsReportId.staff:
      case KpmsReportId.cashierPerformance:
        extras.addAll([
          dim('Staff', filters.staff, staffOptions, (v) => onChanged(filters.copyWith(staff: v))),
        ]);
        break;
      case KpmsReportId.sales:
      case KpmsReportId.salesAnalytics:
        extras.addAll([
          dim('Customer', filters.customer, customerOptions, (v) => onChanged(filters.copyWith(customer: v))),
          dim('Staff', filters.staff, staffOptions, (v) => onChanged(filters.copyWith(staff: v))),
          dim('Medicine', filters.medicine, medicineOptions, (v) => onChanged(filters.copyWith(medicine: v))),
          dim('Payment', filters.paymentMethod, _payment, (v) => onChanged(filters.copyWith(paymentMethod: v))),
          dim('Status', filters.paymentStatus, _status, (v) => onChanged(filters.copyWith(paymentStatus: v))),
        ]);
        break;
      case KpmsReportId.customerDebt:
        extras.addAll([
          dim('Customer', filters.customer, customerOptions, (v) => onChanged(filters.copyWith(customer: v))),
        ]);
        break;
      case KpmsReportId.inventoryValuation:
      case KpmsReportId.expiryAnalytics:
        extras.addAll([
          dim('Medicine', filters.medicine, medicineOptions, (v) => onChanged(filters.copyWith(medicine: v))),
        ]);
        break;
      case KpmsReportId.profitLoss:
      case KpmsReportId.expenseReport:
        break;
    }

    return Material(
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Filters', style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            dateChips,
            if (filters.datePreset == ReportDatePreset.custom && filters.customRange != null) ...[
              const SizedBox(height: 6),
              Text(
                '${filters.customRange!.start.toString().split(' ').first} — ${filters.customRange!.end.toString().split(' ').first}',
                style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
              ),
            ],
            if (extras.isNotEmpty) ...[
              const SizedBox(height: 8),
              LayoutBuilder(
                builder: (context, c) {
                  final w = (c.maxWidth - 10) / 2;
                  return Wrap(
                    children: [
                      for (final e in extras)
                        SizedBox(width: c.maxWidth > 720 ? 220 : w.clamp(140, c.maxWidth), child: e),
                    ],
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}
