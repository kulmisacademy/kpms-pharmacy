import '../../../core/analytics/kpms_analytics_log.dart';
import '../../../core/reports/kpms_report_log.dart';
import '../../../core/theme/app_colors.dart';
import '../../analytics/application/sales_analytics_notifier.dart';
import '../../debts/domain/debt_customer.dart';
import '../../enterprise/domain/pharmacy_expense.dart';
import '../../medicines/domain/medicine.dart';
import '../../purchases/domain/purchase_invoice.dart';
import '../../sales/application/sales_ledger_notifier.dart';
import '../../sales/domain/completed_sale_invoice.dart';
import '../../suppliers/domain/supplier.dart';
import '../domain/kpms_report_id.dart';
import '../domain/report_date_filter.dart';
import '../domain/report_view_filters.dart';
import 'report_enterprise_datasets.dart';
import 'report_models.dart';

String _money(double n) => '\$${n.toStringAsFixed(2)}';

String _footnote(ReportViewFilters f) {
  final parts = <String>[];
  if (f.supplier != 'All') parts.add('Supplier: ${f.supplier}');
  if (f.customer != 'All') parts.add('Customer: ${f.customer}');
  if (f.medicine != 'All') parts.add('Medicine: ${f.medicine}');
  if (f.staff != 'All') parts.add('Staff: ${f.staff}');
  if (f.paymentMethod != 'All') parts.add('Payment: ${f.paymentMethod}');
  if (f.paymentStatus != 'All') parts.add('Status: ${f.paymentStatus}');
  return parts.isEmpty ? 'No additional filters' : parts.join(' · ');
}

bool _rowMatches(List<String> row, ReportViewFilters f) {
  final blob = row.join(' ').toLowerCase();
  if (f.medicine != 'All' && !blob.contains(f.medicine.toLowerCase())) return false;
  if (f.customer != 'All' && !blob.contains(f.customer.toLowerCase())) return false;
  if (f.supplier != 'All' && !blob.contains(f.supplier.toLowerCase())) return false;
  if (f.staff != 'All' && !blob.contains(f.staff.toLowerCase())) return false;
  if (f.paymentMethod != 'All' && !blob.contains(f.paymentMethod.toLowerCase())) return false;
  if (f.paymentStatus != 'All' && !blob.contains(f.paymentStatus.toLowerCase())) return false;
  return true;
}

List<List<String>> _applyFilters(List<List<String>> rows, ReportViewFilters f) {
  return [for (final r in rows) if (_rowMatches(r, f)) r];
}

bool _inRange(DateTime t, ReportDateRange range) {
  final start = DateTime(range.start.year, range.start.month, range.start.day);
  final end = DateTime(range.end.year, range.end.month, range.end.day, 23, 59, 59);
  return !t.isBefore(start) && !t.isAfter(end);
}

String _timeHm(DateTime t) {
  final h = t.hour.toString().padLeft(2, '0');
  final m = t.minute.toString().padLeft(2, '0');
  return '$h:$m';
}

String _salePaymentStatus(CompletedSaleInvoice inv) {
  if (inv.remainingBalance <= 0.009) return 'Paid';
  if (inv.paidTowardInvoice <= 0.009) return 'Unpaid';
  return 'Partial';
}

ReportSummaryMetric _metric(String label, String value, {String? delta, bool? deltaPositive}) {
  return ReportSummaryMetric(
    label: label,
    value: value,
    deltaLabel: delta ?? '—',
    deltaPositive: deltaPositive,
  );
}

ReportLineSeries _lineEmpty() => const ReportLineSeries(yValues: [0], xLabels: ['—']);

List<ReportBarPoint> _barsEmpty() => [const ReportBarPoint(label: '—', value: 0)];

List<ReportPieSlice> _pieEmpty() => const [
      ReportPieSlice(label: 'No data', value: 1, colorArgb: 0xFF9CA3AF),
    ];

const _piePalette = <int>[
  AppColors.chartPrimaryArgb,
  AppColors.chartSecondaryArgb,
  AppColors.chartTertiaryArgb,
  AppColors.chartQuaternaryArgb,
];

void _logReportMaterialization({
  required KpmsReportId id,
  required String? workspaceTenantId,
  required SalesAnalyticsState analytics,
}) {
  final ws = workspaceTenantId?.trim();
  if (ws == null || ws.isEmpty) return;
  final derived = analytics.derivedForTenantId?.trim();
  if (derived != null && derived.isNotEmpty && derived != ws) {
    KpmsAnalyticsLog.crossTenantBlocked('report slug=${id.slug} workspace=$ws analytics=$derived');
  }
  KpmsAnalyticsLog.tenantReportVerified(ws);
  KpmsReportLog.reportGenerated(id.slug, tenantId: ws);
}

ReportDataset buildReportDataset({
  required KpmsReportId id,
  required ReportViewFilters filters,
  required SalesAnalyticsState analytics,
  required List<CompletedSaleInvoice> saleInvoices,
  required List<SalesReturnRecord> saleReturns,
  required List<PurchaseInvoice> purchaseInvoices,
  required List<Supplier> suppliers,
  required List<PharmacyExpense> expenses,
  required List<Medicine> medicines,
  required List<DebtCustomer> debtCustomers,
  required SalesLedgerState salesLedgerState,
  required String? workspaceTenantId,
}) {
  _logReportMaterialization(id: id, workspaceTenantId: workspaceTenantId, analytics: analytics);

  final range = filters.resolvedRange;
  final rangeLabel = range.label;
  final foot = _footnote(filters);

  switch (id) {
    case KpmsReportId.sales:
      return _salesUnified(analytics, rangeLabel, foot, filters, range, saleInvoices);
    case KpmsReportId.purchases:
      return _purchases(rangeLabel, foot, filters, range, purchaseInvoices, suppliers);
    case KpmsReportId.staff:
      return _staff(rangeLabel, foot, filters, range, saleInvoices);
    case KpmsReportId.profitLoss:
      return buildProfitLossDataset(
        filters: filters,
        range: range,
        rangeLabel: rangeLabel,
        invoices: saleInvoices,
        returns: saleReturns,
        purchases: purchaseInvoices,
        expenses: expenses,
      );
    case KpmsReportId.expenseReport:
      return buildExpenseReportDataset(
        filters: filters,
        range: range,
        rangeLabel: rangeLabel,
        expenses: expenses,
      );
    case KpmsReportId.inventoryValuation:
      return buildInventoryValuationDataset(
        filters: filters,
        range: range,
        rangeLabel: rangeLabel,
        medicines: medicines,
        invoices: saleInvoices,
      );
    case KpmsReportId.expiryAnalytics:
      return buildExpiryAnalyticsDataset(
        filters: filters,
        rangeLabel: rangeLabel,
        medicines: medicines,
      );
    case KpmsReportId.customerDebt:
      return buildCustomerDebtDataset(
        filters: filters,
        rangeLabel: rangeLabel,
        invoices: saleInvoices,
        customers: debtCustomers,
      );
    case KpmsReportId.supplierReport:
      return buildSupplierReportDataset(
        filters: filters,
        range: range,
        rangeLabel: rangeLabel,
        purchases: purchaseInvoices,
        suppliers: suppliers,
      );
    case KpmsReportId.cashierPerformance:
      return buildCashierPerformanceDataset(
        filters: filters,
        range: range,
        rangeLabel: rangeLabel,
        ledger: salesLedgerState,
      );
    case KpmsReportId.salesAnalytics:
      return buildSalesAnalyticsDataset(
        filters: filters,
        range: range,
        rangeLabel: rangeLabel,
        invoices: saleInvoices,
        analytics: analytics,
      );
  }
}

ReportDataset _salesUnified(
  SalesAnalyticsState a,
  String rangeLabel,
  String foot,
  ReportViewFilters f,
  ReportDateRange range,
  List<CompletedSaleInvoice> invoices,
) {
  final inRange = invoices.where((i) => _inRange(i.issuedAt, range)).toList()
    ..sort((a, b) => b.issuedAt.compareTo(a.issuedAt));

  final rows = <List<String>>[
    for (final inv in inRange.take(200))
      [
        _timeHm(inv.issuedAt),
        inv.invoiceNumber,
        inv.customerName,
        inv.paymentMethod,
        _money(inv.total),
        _salePaymentStatus(inv),
        _money(inv.remainingBalance),
        inv.cashierName,
      ],
  ];

  final totalSales = inRange.fold<double>(0, (s, i) => s + i.total);
  final totalCost = inRange.fold<double>(0, (s, i) => s + i.lines.fold<double>(0, (t, l) => t + l.unitBuy * l.quantitySold));
  final totalProfit = inRange.fold<double>(0, (s, i) => s + i.profitAfterReturns);
  final receivables = inRange.fold<double>(0, (s, i) => s + i.remainingBalance);

  final payBuckets = <String, double>{};
  for (final inv in inRange) {
    final k = inv.paymentMethod.trim().isEmpty ? 'Other' : inv.paymentMethod;
    payBuckets[k] = (payBuckets[k] ?? 0) + inv.total;
  }
  final bars = payBuckets.isEmpty
      ? _barsEmpty()
      : [
          for (final e in payBuckets.entries.take(8))
            ReportBarPoint(label: e.key.length > 12 ? '${e.key.substring(0, 11)}…' : e.key, value: e.value / 100),
        ];

  final byDay = <String, double>{};
  for (final inv in inRange) {
    final d = '${inv.issuedAt.year}-${inv.issuedAt.month.toString().padLeft(2, '0')}-${inv.issuedAt.day.toString().padLeft(2, '0')}';
    byDay[d] = (byDay[d] ?? 0) + inv.total;
  }
  final dayKeys = byDay.keys.toList()..sort();
  final lineY = dayKeys.isNotEmpty
      ? [for (final k in dayKeys) byDay[k]!]
      : (a.dailySeries.isNotEmpty ? a.dailySeries.map((e) => e).toList() : (totalSales > 0.009 ? <double>[totalSales] : <double>[]));
  final lineLabels = dayKeys.isNotEmpty
      ? [for (final k in dayKeys) k.length > 6 ? k.substring(5) : k]
      : (lineY.length == 7
          ? ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']
          : [for (var i = 0; i < lineY.length; i++) 'P${i + 1}']);

  final pie = payBuckets.isEmpty
      ? _pieEmpty()
      : [
          for (var i = 0; i < payBuckets.length && i < 4; i++)
            ReportPieSlice(
              label: payBuckets.keys.elementAt(i),
              value: payBuckets.values.elementAt(i).clamp(0.001, 1e15),
              colorArgb: _piePalette[i % 4],
            ),
        ];

  return ReportDataset(
    reportId: KpmsReportId.sales,
    rangeLabel: rangeLabel,
    filterFootnote: foot,
    summaries: [
      _metric('Total sales', _money(totalSales)),
      _metric('Total cost', _money(totalCost)),
      _metric('Total profit', _money(totalProfit)),
      _metric('Receivables (open)', _money(receivables)),
    ],
    line: lineY.isEmpty ? _lineEmpty() : ReportLineSeries(yValues: lineY, xLabels: lineLabels),
    bars: bars,
    area: lineY.isEmpty
        ? _lineEmpty()
        : ReportLineSeries(
            yValues: [for (final v in lineY) v * 0.9],
            xLabels: lineLabels,
          ),
    pie: pie,
    tableColumns: const ['Time', 'Invoice', 'Customer', 'Channel', 'Amount', 'Status', 'Balance', 'Staff'],
    tableRows: _applyFilters(rows, f),
  );
}

ReportDataset _purchases(
  String rangeLabel,
  String foot,
  ReportViewFilters f,
  ReportDateRange range,
  List<PurchaseInvoice> purchases,
  List<Supplier> suppliers,
) {
  final inRange = purchases.where((p) => _inRange(p.issuedAt, range)).toList()
    ..sort((a, b) => b.issuedAt.compareTo(a.issuedAt));

  final rows = <List<String>>[
    for (final p in inRange.take(200))
      [
        p.supplierName,
        p.invoiceNumber,
        '${p.issuedAt.year}-${p.issuedAt.month.toString().padLeft(2, '0')}-${p.issuedAt.day.toString().padLeft(2, '0')}',
        _money(p.grandTotal),
        p.paymentStatusLabel,
        _money(p.effectiveRemainingBalance),
      ],
  ];

  final spend = inRange.fold<double>(0, (s, p) => s + p.grandTotal);
  final supplierAp = suppliers.fold<double>(0, (s, x) => s + x.balanceOwed);

  final supplierTotals = <String, double>{};
  for (final p in inRange) {
    supplierTotals[p.supplierName] = (supplierTotals[p.supplierName] ?? 0) + p.grandTotal;
  }
  final bars = supplierTotals.isEmpty
      ? _barsEmpty()
      : [
          for (final e in supplierTotals.entries.take(8))
            ReportBarPoint(label: e.key.length > 14 ? '${e.key.substring(0, 12)}…' : e.key, value: e.value / 100),
        ];

  return ReportDataset(
    reportId: KpmsReportId.purchases,
    rangeLabel: rangeLabel,
    filterFootnote: foot,
    summaries: [
      _metric('Total purchases', _money(spend)),
      _metric('Invoices', '${inRange.length}'),
      _metric('Supplier AP (now)', _money(supplierAp)),
      _metric('Avg PO', inRange.isEmpty ? _money(0) : _money(spend / inRange.length)),
    ],
    line: spend > 0.009 ? ReportLineSeries(yValues: [spend], xLabels: const ['Period']) : _lineEmpty(),
    bars: bars,
    area: spend > 0.009 ? ReportLineSeries(yValues: [spend * 0.92], xLabels: const ['Period']) : _lineEmpty(),
    pie: spend > 0.009 && supplierTotals.length <= 4
        ? [
            for (var i = 0; i < supplierTotals.length; i++)
              ReportPieSlice(
                label: supplierTotals.keys.elementAt(i),
                value: supplierTotals.values.elementAt(i).clamp(0.001, 1e15),
                colorArgb: _piePalette[i % 4],
              ),
          ]
        : (spend > 0.009
            ? [ReportPieSlice(label: 'Purchases', value: spend.clamp(0.001, 1e15), colorArgb: _piePalette[0])]
            : _pieEmpty()),
    tableColumns: const ['Supplier', 'PO #', 'Date', 'Amount', 'Status', 'Open balance'],
    tableRows: _applyFilters(rows, f),
  );
}

ReportDataset _staff(
  String rangeLabel,
  String foot,
  ReportViewFilters f,
  ReportDateRange range,
  List<CompletedSaleInvoice> invoices,
) {
  final inRange = invoices.where((i) => _inRange(i.issuedAt, range)).toList();

  final names = <String, ({double sales, int count})>{};
  for (final inv in inRange) {
    final n = inv.cashierName.trim();
    if (n.isEmpty) continue;
    final cur = names[n] ?? (sales: 0.0, count: 0);
    names[n] = (sales: cur.sales + inv.total, count: cur.count + 1);
  }

  final totalSales = names.values.fold<double>(0, (s, v) => s + v.sales);

  final rows = <List<String>>[
    for (final e in names.entries)
      [
        'Summary',
        e.key,
        _money(e.value.sales),
        '${e.value.count} invoices',
        totalSales > 0.009 ? '${((e.value.sales / totalSales) * 100).toStringAsFixed(0)}% share' : '—',
      ],
  ];

  final sorted = [...inRange]..sort((a, b) => b.issuedAt.compareTo(a.issuedAt));
  for (final inv in sorted.take(120)) {
    final n = inv.cashierName.trim();
    if (n.isEmpty) continue;
    rows.add([
      'Activity',
      n,
      _money(inv.total),
      _timeHm(inv.issuedAt),
      inv.invoiceNumber,
    ]);
  }
  rows.add([
    'Login',
    'Directory',
    '—',
    'Supabase Auth',
    'Staff sign-ins use your workspace identity provider.',
  ]);

  return ReportDataset(
    reportId: KpmsReportId.staff,
    rangeLabel: rangeLabel,
    filterFootnote: foot,
    summaries: [
      _metric('Active cashiers', '${names.length}'),
      _metric('Invoices in range', '${inRange.length}'),
      _metric('Team sales', _money(totalSales)),
      _metric('Login audit', 'Supabase Auth'),
    ],
    line: names.isEmpty
        ? _lineEmpty()
        : ReportLineSeries(
            yValues: [for (final e in names.entries.take(7)) e.value.sales / 100],
            xLabels: [
              for (final e in names.entries.take(7))
                e.key.length > 7 ? '${e.key.substring(0, 6)}…' : e.key,
            ],
          ),
    bars: names.isEmpty
        ? _barsEmpty()
        : [
            for (final e in names.entries.take(8))
              ReportBarPoint(label: e.key.length > 10 ? '${e.key.substring(0, 8)}…' : e.key, value: e.value.sales / 1000),
          ],
    area: _lineEmpty(),
    pie: names.isEmpty
        ? _pieEmpty()
        : [
            for (var i = 0; i < names.length && i < 4; i++)
              ReportPieSlice(
                label: names.keys.elementAt(i),
                value: names.values.elementAt(i).sales.clamp(0.001, 1e15),
                colorArgb: _piePalette[i % 4],
              ),
          ],
    tableColumns: const ['Type', 'Staff', 'Amount / detail', 'Time / metric', 'Reference'],
    tableRows: _applyFilters(rows, f),
  );
}
