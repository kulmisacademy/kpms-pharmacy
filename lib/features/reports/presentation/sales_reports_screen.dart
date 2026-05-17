import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/navigation/kpms_breakpoints.dart';
import '../../../core/tenant/kpms_active_tenant_provider.dart';
import '../../../core/utils/kpms_feedback.dart';
import '../../../core/widgets/kpms_page_shell.dart';
import '../../debts/application/debt_customers_notifier.dart';
import '../../medicines/data/medicine_catalog_notifier.dart';
import '../../sales/application/sales_ledger_notifier.dart';
import '../../settings/application/pharmacy_settings_providers.dart';
import '../../suppliers/application/suppliers_notifier.dart';
import '../application/report_dataset_provider.dart';
import '../application/report_export_service.dart';
import '../domain/kpms_report_id.dart';
import '../domain/report_view_filters.dart';
import 'widgets/report_charts_panel.dart';
import 'widgets/report_filters_sheet.dart';
import 'widgets/report_section_title.dart';
import 'widgets/report_summary_header.dart';
import 'widgets/report_table_panel.dart';

/// Unified sales report — revenue, cost, profit, receivables, charts, export.
class SalesReportsScreen extends ConsumerStatefulWidget {
  const SalesReportsScreen({super.key});

  @override
  ConsumerState<SalesReportsScreen> createState() => _SalesReportsScreenState();
}

class _SalesReportsScreenState extends ConsumerState<SalesReportsScreen> {
  ReportViewFilters _filters = const ReportViewFilters();
  bool _exporting = false;

  List<String> _supplierOptions() {
    final suppliers = ref.watch(suppliersProvider);
    return ['All', ...suppliers.map((s) => s.name)];
  }

  List<String> _customerOptions() {
    final customers = ref.watch(debtCustomersProvider);
    return ['All', ...customers.map((c) => c.name)];
  }

  List<String> _staffOptions() {
    final cashiers = ref.watch(salesLedgerProvider).invoices.map((i) => i.cashierName.trim()).where((n) => n.isNotEmpty).toSet().toList()..sort();
    return ['All', ...cashiers];
  }

  List<String> _medicineOptions() {
    final meds = ref.watch(medicineCatalogProvider);
    return ['All', ...meds.map((m) => m.name)];
  }

  Future<void> _openFilters() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => SingleChildScrollView(
        child: ReportFiltersSheet(
          reportId: KpmsReportId.sales,
          filters: _filters,
          onChanged: (f) => setState(() => _filters = f),
          supplierOptions: _supplierOptions(),
          customerOptions: _customerOptions(),
          medicineOptions: _medicineOptions(),
          staffOptions: _staffOptions(),
        ),
      ),
    );
  }

  Future<void> _export(String kind) async {
    if (_exporting) return;
    final dataset = ref.read(reportDatasetProvider((id: KpmsReportId.sales, filters: _filters)));
    final branding = ref.read(pharmacyBrandingProvider);
    final tid = (ref.read(kpmsActiveTenantIdProvider).valueOrNull ?? '').trim();
    if (tid.isEmpty) {
      if (mounted) kpmsSnack(context, 'Select a workspace before exporting', isError: true);
      return;
    }
    setState(() => _exporting = true);
    try {
      ReportExportService.logExportStart(slug: KpmsReportId.sales.slug, format: kind, tenantId: tid);
      switch (kind) {
        case 'pdf':
          await ReportExportService.exportPdf(
            dataset,
            pharmacyName: branding.businessName,
            logoUrl: branding.logoUrl,
            tenantId: tid,
          );
          break;
        case 'excel':
          await ReportExportService.exportExcel(dataset, tenantId: tid);
          break;
        case 'csv':
          await ReportExportService.exportCsv(dataset, tenantId: tid);
          break;
      }
      ReportExportService.logExportDone(slug: KpmsReportId.sales.slug, format: kind, tenantId: tid);
      if (mounted) kpmsSnack(context, 'Export ready — share sheet opened');
    } catch (e) {
      if (mounted) kpmsSnack(context, 'Export failed: $e', isError: true);
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dataset = ref.watch(reportDatasetProvider((id: KpmsReportId.sales, filters: _filters)));

    return KpmsPageShell(
      title: 'Sales report',
      subtitle: '${dataset.rangeLabel} · ${_exporting ? 'Preparing export…' : 'Filters & export in toolbar'}',
      actions: [
        IconButton(
          tooltip: 'Filters',
          onPressed: _openFilters,
          icon: const Icon(Icons.tune_rounded),
        ),
        PopupMenuButton<String>(
          tooltip: 'Export',
          enabled: !_exporting,
          onSelected: _export,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: _exporting
                ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.ios_share_rounded),
          ),
          itemBuilder: (ctx) => const [
            PopupMenuItem(value: 'pdf', child: ListTile(leading: Icon(Icons.picture_as_pdf_outlined), title: Text('PDF'))),
            PopupMenuItem(value: 'excel', child: ListTile(leading: Icon(Icons.table_chart_outlined), title: Text('Excel'))),
            PopupMenuItem(value: 'csv', child: ListTile(leading: Icon(Icons.description_outlined), title: Text('CSV'))),
          ],
        ),
      ],
      body: Padding(
        padding: KpmsBreakpoints.pageBodyInsets(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FilledButton.tonalIcon(
              onPressed: _openFilters,
              icon: const Icon(Icons.date_range_rounded, size: 18),
              label: Text('Date & filters · ${dataset.filterFootnote}', maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.only(bottom: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ReportSummaryHeader(metrics: dataset.summaries.take(4).toList()),
                    const SizedBox(height: 22),
                    const ReportSectionTitle(label: 'Charts'),
                    const SizedBox(height: 10),
                    ReportChartsPanel(dataset: dataset),
                    const SizedBox(height: 26),
                    const ReportSectionTitle(label: 'Transactions'),
                    const SizedBox(height: 10),
                    ReportTablePanel(columns: dataset.tableColumns, rows: dataset.tableRows),
                    for (final sec in dataset.extraSections) ...[
                      const SizedBox(height: 22),
                      ReportSectionTitle(label: sec.title),
                      ReportTablePanel(columns: sec.columns, rows: sec.rows),
                    ],
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
