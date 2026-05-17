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

class ReportDetailScreen extends ConsumerStatefulWidget {
  const ReportDetailScreen({super.key, required this.reportSlug});

  final String reportSlug;

  @override
  ConsumerState<ReportDetailScreen> createState() => _ReportDetailScreenState();
}

class _ReportDetailScreenState extends ConsumerState<ReportDetailScreen> {
  ReportViewFilters _filters = const ReportViewFilters();
  bool _exporting = false;

  List<String> _supplierOptions(WidgetRef ref) {
    final suppliers = ref.watch(suppliersProvider);
    return ['All', ...suppliers.map((s) => s.name)];
  }

  List<String> _customerOptions(WidgetRef ref) {
    final customers = ref.watch(debtCustomersProvider);
    return ['All', ...customers.map((c) => c.name)];
  }

  List<String> _staffOptions(WidgetRef ref) {
    final cashiers = ref.watch(salesLedgerProvider).invoices.map((i) => i.cashierName.trim()).where((n) => n.isNotEmpty).toSet().toList()..sort();
    return ['All', ...cashiers];
  }

  List<String> _medicineOptions(WidgetRef ref) {
    final meds = ref.read(medicineCatalogProvider);
    return ['All', ...meds.map((m) => m.name)];
  }

  Future<void> _openFilters(KpmsReportId id) async {
    final medOpts = _medicineOptions(ref);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => SingleChildScrollView(
        child: ReportFiltersSheet(
          reportId: id,
          filters: _filters,
          onChanged: (f) => setState(() => _filters = f),
          supplierOptions: _supplierOptions(ref),
          customerOptions: _customerOptions(ref),
          medicineOptions: medOpts,
          staffOptions: _staffOptions(ref),
        ),
      ),
    );
  }

  Future<void> _export(String kind) async {
    final id = KpmsReportId.tryParse(widget.reportSlug);
    if (id == null || _exporting) return;
    final dataset = ref.read(reportDatasetProvider((id: id, filters: _filters)));
    final branding = ref.read(pharmacyBrandingProvider);
    final tid = (ref.read(kpmsActiveTenantIdProvider).valueOrNull ?? '').trim();
    if (tid.isEmpty) {
      if (mounted) kpmsSnack(context, 'Select a workspace before exporting', isError: true);
      return;
    }
    setState(() => _exporting = true);
    try {
      ReportExportService.logExportStart(slug: id.slug, format: kind, tenantId: tid);
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
      ReportExportService.logExportDone(slug: id.slug, format: kind, tenantId: tid);
      if (mounted) kpmsSnack(context, 'Export ready — share sheet opened');
    } catch (e) {
      if (mounted) kpmsSnack(context, 'Export failed: $e', isError: true);
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final id = KpmsReportId.tryParse(widget.reportSlug);
    if (id == null) {
      return KpmsPageShell(
        title: 'Report',
        subtitle: 'Not found',
        body: Center(
          child: Padding(
            padding: KpmsBreakpoints.pageBodyInsets(context),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline_rounded, size: 48),
                const SizedBox(height: 12),
                Text('Unknown report “${widget.reportSlug}”.', textAlign: TextAlign.center),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Back to hub'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final dataset = ref.watch(reportDatasetProvider((id: id, filters: _filters)));

    return KpmsPageShell(
      title: id.title,
      subtitle: '${dataset.rangeLabel} · ${_exporting ? 'Preparing export…' : 'Analytics workspace'}',
      actions: [
        PopupMenuButton<String>(
          tooltip: 'Export',
          enabled: !_exporting,
          onSelected: _export,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: _exporting
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
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
            LayoutBuilder(
              builder: (context, c) {
                final narrow = c.maxWidth < 560;
                final filterBtn = FilledButton.tonal(
                  onPressed: () => _openFilters(id),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.tune_rounded, size: 18),
                      SizedBox(width: 8),
                      Text('Filters'),
                    ],
                  ),
                );
                final range = Text(
                  dataset.rangeLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(color: Theme.of(context).hintColor),
                );
                if (narrow) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Align(alignment: Alignment.centerLeft, child: filterBtn),
                      const SizedBox(height: 8),
                      range,
                    ],
                  );
                }
                return Row(
                  children: [
                    filterBtn,
                    const SizedBox(width: 12),
                    Expanded(child: range),
                  ],
                );
              },
            ),
            const SizedBox(height: 16),
            Expanded(
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.only(bottom: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ReportSummaryHeader(metrics: dataset.summaries),
                    const SizedBox(height: 22),
                    const ReportSectionTitle(label: 'Charts'),
                    ReportChartsPanel(dataset: dataset),
                    const SizedBox(height: 26),
                    ReportTablePanel(
                      columns: dataset.tableColumns,
                      rows: dataset.tableRows,
                    ),
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
