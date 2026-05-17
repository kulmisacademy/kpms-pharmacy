import 'package:flutter/material.dart';

import '../../domain/kpms_report_id.dart';
import '../../domain/report_view_filters.dart';
import 'report_filter_toolbar.dart';

typedef ReportFiltersChanged = void Function(ReportViewFilters filters);

/// Bottom sheet wrapper so filters don't permanently crowd the page.
class ReportFiltersSheet extends StatelessWidget {
  const ReportFiltersSheet({
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final viewInsets = MediaQuery.viewInsetsOf(context);
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 12, 16, 16 + viewInsets.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text('Filters', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
                const Spacer(),
                IconButton(
                  tooltip: 'Close',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ReportFilterToolbar(
              reportId: reportId,
              filters: filters,
              onChanged: onChanged,
              supplierOptions: supplierOptions,
              customerOptions: customerOptions,
              medicineOptions: medicineOptions,
              staffOptions: staffOptions,
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Apply'),
            ),
          ],
        ),
      ),
    );
  }
}

