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
import 'report_models.dart';

String _money(double n) => '\$${n.toStringAsFixed(2)}';

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

bool _inRange(DateTime t, ReportDateRange range) {
  final start = DateTime(range.start.year, range.start.month, range.start.day);
  final end = DateTime(range.end.year, range.end.month, range.end.day, 23, 59, 59);
  return !t.isBefore(start) && !t.isAfter(end);
}

CompletedSaleInvoice? _invoiceByNumber(List<CompletedSaleInvoice> invoices, String number) {
  for (final i in invoices) {
    if (i.invoiceNumber == number) return i;
  }
  return null;
}

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// Build chart buckets: daily if span ≤ 40 days, else weekly.
({List<String> labels, List<double> netSales, List<double> profit}) _rangeTrend({
  required ReportDateRange range,
  required List<CompletedSaleInvoice> invoices,
  required List<SalesReturnRecord> returns,
  required double grossProfitTotal,
  required double netSalesTotal,
}) {
  final start = DateTime(range.start.year, range.start.month, range.start.day);
  final end = DateTime(range.end.year, range.end.month, range.end.day);
  final spanDays = end.difference(start).inDays + 1;
  final weekly = spanDays > 40;

  double netForDay(DateTime day) {
    var s = 0.0;
    for (final inv in invoices) {
      if (_sameDay(inv.issuedAt, day)) s += inv.total;
    }
    for (final r in returns) {
      if (_sameDay(r.issuedAt, day)) s -= r.refundTotal;
    }
    return s;
  }

  double profitForDay(DateTime day) {
    var g = 0.0;
    for (final inv in invoices) {
      if (_sameDay(inv.issuedAt, day)) g += inv.profitAfterReturns;
    }
    for (final r in returns) {
      if (!_sameDay(r.issuedAt, day)) continue;
      final orig = _invoiceByNumber(invoices, r.originalInvoiceNumber);
      if (orig == null || !_inRange(orig.issuedAt, range)) {
        g -= r.profitReduction;
      }
    }
    return g;
  }

  final labels = <String>[];
  final netVals = <double>[];
  final profVals = <double>[];

  if (!weekly) {
    for (var d = start; !d.isAfter(end); d = d.add(const Duration(days: 1))) {
      labels.add('${d.month}/${d.day}');
      netVals.add(netForDay(d));
      profVals.add(profitForDay(d));
    }
  } else {
    var cursor = start;
    var w = 0;
    while (!cursor.isAfter(end)) {
      w++;
      final weekEnd = cursor.add(const Duration(days: 6));
      final cap = weekEnd.isAfter(end) ? end : weekEnd;
      var ns = 0.0;
      var gp = 0.0;
      for (var d = cursor; !d.isAfter(cap); d = d.add(const Duration(days: 1))) {
        ns += netForDay(d);
        gp += profitForDay(d);
      }
      labels.add('W$w');
      netVals.add(ns);
      profVals.add(gp);
      cursor = cap.add(const Duration(days: 1));
    }
  }

  if (labels.isEmpty) {
    netVals.add(netSalesTotal);
    profVals.add(grossProfitTotal);
    labels.add('Period');
  }

  return (labels: labels, netSales: netVals, profit: profVals);
}

List<List<String>> _applyFootprint(List<List<String>> rows, ReportViewFilters f) {
  return [for (final r in rows) if (_blobMatchesFootprint(r, f)) r];
}

bool _blobMatchesFootprint(List<String> row, ReportViewFilters f) {
  final blob = row.join(' ').toLowerCase();
  if (f.medicine != 'All' && !blob.contains(f.medicine.toLowerCase())) return false;
  if (f.customer != 'All' && !blob.contains(f.customer.toLowerCase())) return false;
  if (f.supplier != 'All' && !blob.contains(f.supplier.toLowerCase())) return false;
  if (f.staff != 'All' && !blob.contains(f.staff.toLowerCase())) return false;
  return true;
}

String _footnoteEnterprise(ReportViewFilters f) {
  final parts = <String>[];
  if (f.supplier != 'All') parts.add('Supplier: ${f.supplier}');
  if (f.customer != 'All') parts.add('Customer: ${f.customer}');
  if (f.medicine != 'All') parts.add('Medicine: ${f.medicine}');
  if (f.staff != 'All') parts.add('Staff: ${f.staff}');
  return parts.isEmpty ? 'No additional filters' : parts.join(' · ');
}

ReportDataset buildProfitLossDataset({
  required ReportViewFilters filters,
  required ReportDateRange range,
  required String rangeLabel,
  required List<CompletedSaleInvoice> invoices,
  required List<SalesReturnRecord> returns,
  required List<PurchaseInvoice> purchases,
  required List<PharmacyExpense> expenses,
}) {
  final foot = _footnoteEnterprise(filters);
  final invR = invoices.where((i) => _inRange(i.issuedAt, range)).toList();
  final retR = returns.where((r) => _inRange(r.issuedAt, range)).toList();
  final purR = purchases.where((p) => _inRange(p.issuedAt, range)).toList();
  final expR = expenses.where((e) => _inRange(e.issuedAt, range)).toList();

  final totalSales = invR.fold<double>(0, (s, i) => s + i.total);
  final refunds = retR.fold<double>(0, (s, r) => s + r.refundTotal);
  final netSales = totalSales - refunds;

  var grossProfit = invR.fold<double>(0, (s, i) => s + i.profitAfterReturns);
  for (final r in retR) {
    final orig = _invoiceByNumber(invoices, r.originalInvoiceNumber);
    if (orig == null || !_inRange(orig.issuedAt, range)) {
      grossProfit -= r.profitReduction;
    }
  }

  final purchaseCost = purR.fold<double>(0, (s, p) => s + p.grandTotal);
  final expenseTotal = expR.fold<double>(0, (s, e) => s + e.amount);
  final cogs = netSales > 0.009 ? (netSales - grossProfit).clamp(0.0, 1e15) : 0.0;
  final netProfit = grossProfit - expenseTotal;
  final retImpact = '${_money(refunds)} refunds · ${_money(retR.fold(0.0, (s, r) => s + r.profitReduction))} margin impact';

  final trend = _rangeTrend(
    range: range,
    invoices: invoices,
    returns: returns,
    grossProfitTotal: grossProfit,
    netSalesTotal: netSales,
  );

  final rows = <List<String>>[
    ['Summary', 'Net sales', _money(netSales)],
    ['Summary', 'COGS (derived)', _money(cogs)],
    ['Summary', 'Gross profit', _money(grossProfit)],
    ['Summary', 'Inventory purchases (period)', _money(purchaseCost)],
    ['Summary', 'Operating expenses', _money(expenseTotal)],
    ['Summary', 'Net profit (gross − expenses)', _money(netProfit)],
    ['Summary', 'Returns impact', retImpact],
    ...[
      for (final inv in invR.take(120))
        [
          'Sale',
          inv.issuedAt.toIso8601String().split('T').first,
          inv.invoiceNumber,
          _money(inv.total),
          _money(inv.profitAfterReturns),
        ],
    ],
    ...[
      for (final r in retR.take(80))
        [
          'Return',
          r.issuedAt.toIso8601String().split('T').first,
          r.originalInvoiceNumber,
          _money(-r.refundTotal),
          _money(-r.profitReduction),
        ],
    ],
  ];

  return ReportDataset(
    reportId: KpmsReportId.profitLoss,
    rangeLabel: rangeLabel,
    filterFootnote: foot,
    summaries: [
      _metric('Net sales', _money(netSales)),
      _metric('Gross profit', _money(grossProfit)),
      _metric('Expenses', _money(expenseTotal)),
      _metric('Net profit', _money(netProfit)),
    ],
    line: trend.netSales.isEmpty
        ? _lineEmpty()
        : ReportLineSeries(yValues: trend.netSales, xLabels: trend.labels),
    bars: expenseTotal > 0.009 || grossProfit.abs() > 0.009
        ? [
            ReportBarPoint(label: 'Gross', value: grossProfit.abs() / 100),
            ReportBarPoint(label: 'Expense', value: expenseTotal / 100),
          ]
        : _barsEmpty(),
    area: trend.profit.isEmpty
        ? _lineEmpty()
        : ReportLineSeries(yValues: trend.profit, xLabels: trend.labels),
    pie: netSales > 0.009
        ? [
            ReportPieSlice(label: 'Gross profit', value: grossProfit.clamp(0.001, 1e15), colorArgb: _piePalette[0]),
            ReportPieSlice(label: 'Expenses', value: expenseTotal.clamp(0.001, 1e15), colorArgb: _piePalette[1]),
            ReportPieSlice(label: 'COGS', value: cogs.clamp(0.001, 1e15), colorArgb: _piePalette[2]),
          ]
        : _pieEmpty(),
    tableColumns: const ['Type', 'Date', 'Ref', 'Amount', 'Margin'],
    tableRows: _applyFootprint(rows, filters),
    extraSections: [
      ReportTableSection(
        title: 'Expenses (period)',
        columns: const ['Date', 'Category', 'Amount', 'Note'],
        rows: [
          for (final e in expR.take(200))
            [
              e.issuedAt.toIso8601String().split('T').first,
              e.category,
              _money(e.amount),
              e.note,
            ],
        ],
      ),
    ],
  );
}

ReportDataset buildExpenseReportDataset({
  required ReportViewFilters filters,
  required ReportDateRange range,
  required String rangeLabel,
  required List<PharmacyExpense> expenses,
}) {
  final foot = _footnoteEnterprise(filters);
  final expR = expenses.where((e) => _inRange(e.issuedAt, range)).toList()..sort((a, b) => b.issuedAt.compareTo(a.issuedAt));

  final byCat = <String, double>{};
  for (final e in expR) {
    byCat[e.category] = (byCat[e.category] ?? 0) + e.amount;
  }
  final total = expR.fold<double>(0, (s, e) => s + e.amount);

  final monthBuckets = <String, double>{};
  for (final e in expR) {
    final k = '${e.issuedAt.year}-${e.issuedAt.month.toString().padLeft(2, '0')}';
    monthBuckets[k] = (monthBuckets[k] ?? 0) + e.amount;
  }
  final mKeys = monthBuckets.keys.toList()..sort();
  final lineY = mKeys.isNotEmpty ? [for (final k in mKeys) monthBuckets[k]!] : <double>[if (total > 0) total];
  final lineL = mKeys.isNotEmpty ? mKeys : ['Period'];

  final bars = byCat.isEmpty
      ? _barsEmpty()
      : [
          for (final e in byCat.entries.take(8))
            ReportBarPoint(label: e.key.length > 12 ? '${e.key.substring(0, 11)}…' : e.key, value: e.value / 100),
        ];

  final pie = byCat.isEmpty
      ? _pieEmpty()
      : [
          for (var i = 0; i < byCat.length && i < 4; i++)
            ReportPieSlice(
              label: byCat.keys.elementAt(i),
              value: byCat.values.elementAt(i).clamp(0.001, 1e15),
              colorArgb: _piePalette[i % 4],
            ),
        ];

  final catDisplay = <List<String>>[
    for (final e in byCat.entries)
      [PharmacyExpenseCategories.label(e.key), e.key, _money(e.value)],
  ]..sort((a, b) {
      final pa = double.tryParse(a[2].replaceAll(RegExp(r'[^\d.]'), '')) ?? 0;
      final pb = double.tryParse(b[2].replaceAll(RegExp(r'[^\d.]'), '')) ?? 0;
      return pb.compareTo(pa);
    });

  return ReportDataset(
    reportId: KpmsReportId.expenseReport,
    rangeLabel: rangeLabel,
    filterFootnote: foot,
    summaries: [
      _metric('Total expenses', _money(total)),
      _metric('Transactions', '${expR.length}'),
      _metric('Categories', '${byCat.length}'),
      _metric('Avg / txn', expR.isEmpty ? _money(0) : _money(total / expR.length)),
    ],
    line: lineY.isEmpty ? _lineEmpty() : ReportLineSeries(yValues: lineY, xLabels: lineL),
    bars: bars,
    area: lineY.isEmpty ? _lineEmpty() : ReportLineSeries(yValues: [for (final v in lineY) v * 0.85], xLabels: lineL),
    pie: pie,
    tableColumns: const ['Date', 'Category', 'Amount', 'Note', 'Recorded by'],
    tableRows: _applyFootprint([
      for (final e in expR.take(200))
        [
          e.issuedAt.toIso8601String().split('T').first,
          PharmacyExpenseCategories.label(e.category),
          _money(e.amount),
          e.note,
          e.createdBy ?? '—',
        ],
    ], filters),
    extraSections: [
      ReportTableSection(
        title: 'Totals by category',
        columns: const ['Category', 'Key', 'Total'],
        rows: catDisplay,
      ),
    ],
  );
}

ReportDataset buildInventoryValuationDataset({
  required ReportViewFilters filters,
  required ReportDateRange range,
  required String rangeLabel,
  required List<Medicine> medicines,
  required List<CompletedSaleInvoice> invoices,
}) {
  final foot = _footnoteEnterprise(filters);
  final qtySoldByMed = <String, int>{};
  final since90 = DateTime.now().subtract(const Duration(days: 90));
  for (final inv in invoices) {
    if (!_inRange(inv.issuedAt, range)) continue;
    for (final line in inv.lines) {
      qtySoldByMed[line.medicineId] = (qtySoldByMed[line.medicineId] ?? 0) + line.quantitySold;
    }
  }
  final qtySold90d = <String, int>{};
  for (final inv in invoices) {
    if (inv.issuedAt.isBefore(since90)) continue;
    for (final line in inv.lines) {
      qtySold90d[line.medicineId] = (qtySold90d[line.medicineId] ?? 0) + line.quantitySold;
    }
  }

  final totalValue = medicines.fold<double>(0, (s, m) => s + m.quantity * m.buyingPrice);
  final low = medicines.where((m) => m.isLowStock).length;
  final dead = medicines.where((m) => (qtySold90d[m.id] ?? 0) == 0 && m.quantity > 0).length;

  final movement = [
    for (final m in medicines)
      (m, qtySoldByMed[m.id] ?? 0),
  ]..sort((a, b) => b.$2.compareTo(a.$2));

  final topMove = movement.where((x) => x.$2 > 0).take(12).toList();

  final rows = <List<String>>[
    for (final pair in medicines)
      [
        pair.name,
        '${pair.quantity}',
        _money(pair.buyingPrice),
        _money(pair.quantity * pair.buyingPrice),
        pair.isLowStock ? 'Low' : 'OK',
        '${qtySoldByMed[pair.id] ?? 0}',
      ],
  ]..sort((a, b) {
      final pa = double.tryParse(a[3].replaceAll(RegExp(r'[^\d.]'), '')) ?? 0;
      final pb = double.tryParse(b[3].replaceAll(RegExp(r'[^\d.]'), '')) ?? 0;
      return pb.compareTo(pa);
    });

  final bars = topMove.isEmpty
      ? _barsEmpty()
      : [
          for (final t in topMove)
            ReportBarPoint(
              label: t.$1.name.length > 10 ? '${t.$1.name.substring(0, 9)}…' : t.$1.name,
              value: t.$2.toDouble(),
            ),
        ];

  return ReportDataset(
    reportId: KpmsReportId.inventoryValuation,
    rangeLabel: rangeLabel,
    filterFootnote: foot,
    summaries: [
      _metric('Stock valuation', _money(totalValue)),
      _metric('Low-stock SKUs', '$low'),
      _metric('Dead stock SKUs', '$dead'),
      _metric('Catalog SKUs', '${medicines.length}'),
    ],
    line: topMove.isEmpty
        ? _lineEmpty()
        : ReportLineSeries(
            yValues: [for (final t in topMove) t.$2.toDouble()],
            xLabels: [for (final t in topMove) t.$1.name.length > 6 ? '${t.$1.name.substring(0, 5)}…' : t.$1.name],
          ),
    bars: bars,
    area: _lineEmpty(),
    pie: totalValue > 0.009 && topMove.length >= 2
        ? [
            for (var i = 0; i < topMove.length && i < 4; i++)
              ReportPieSlice(
                label: topMove[i].$1.name,
                value: (topMove[i].$1.quantity * topMove[i].$1.buyingPrice).clamp(0.001, 1e15),
                colorArgb: _piePalette[i % 4],
              ),
          ]
        : (totalValue > 0.009
            ? [ReportPieSlice(label: 'Inventory', value: totalValue, colorArgb: _piePalette[0])]
            : _pieEmpty()),
    tableColumns: const ['Medicine', 'Qty', 'Unit cost', 'Value', 'Alert', 'Sold (range)'],
    tableRows: _applyFootprint([for (final r in rows.take(250)) r], filters),
    extraSections: [
      ReportTableSection(
        title: 'High movement (period)',
        columns: const ['Medicine', 'Qty sold'],
        rows: [
          for (final t in topMove) [t.$1.name, '${t.$2}'],
        ],
      ),
    ],
  );
}

ReportDataset buildExpiryAnalyticsDataset({
  required ReportViewFilters filters,
  required String rangeLabel,
  required List<Medicine> medicines,
}) {
  final foot = _footnoteEnterprise(filters);
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);

  var expired = 0;
  var soon30 = 0;
  var soon90 = 0;
  final timeline = <String, int>{'Expired': 0, '0-30d': 0, '31-90d': 0, '91+d': 0, 'No date': 0};

  final rows = <List<String>>[];

  for (final m in medicines) {
    final exp = m.expiryDate;
    if (exp == null) {
      timeline['No date'] = (timeline['No date'] ?? 0) + m.quantity;
      rows.add([m.name, '—', '${m.quantity}', 'No date']);
      continue;
    }
    final d0 = DateTime(exp.year, exp.month, exp.day);
    final diff = d0.difference(today).inDays;
    if (diff < 0) {
      expired++;
      timeline['Expired'] = (timeline['Expired'] ?? 0) + m.quantity;
      rows.add([m.name, exp.toIso8601String().split('T').first, '${m.quantity}', 'Expired']);
    } else if (diff <= 30) {
      soon30++;
      timeline['0-30d'] = (timeline['0-30d'] ?? 0) + m.quantity;
      rows.add([m.name, exp.toIso8601String().split('T').first, '${m.quantity}', '≤30d']);
    } else if (diff <= 90) {
      soon90++;
      timeline['31-90d'] = (timeline['31-90d'] ?? 0) + m.quantity;
      rows.add([m.name, exp.toIso8601String().split('T').first, '${m.quantity}', '31–90d']);
    } else {
      timeline['91+d'] = (timeline['91+d'] ?? 0) + m.quantity;
      rows.add([m.name, exp.toIso8601String().split('T').first, '${m.quantity}', '>90d']);
    }
  }

  rows.sort((a, b) => a[1].compareTo(b[1]));

  final riskScore = expired * 5 + soon30 * 2 + soon90;

  final barLabels = timeline.keys.toList();
  final barVals = [for (final k in barLabels) (timeline[k] ?? 0).toDouble()];

  return ReportDataset(
    reportId: KpmsReportId.expiryAnalytics,
    rangeLabel: rangeLabel,
    filterFootnote: foot,
    summaries: [
      _metric('Expired lines', '$expired'),
      _metric('Expiring ≤30d', '$soon30'),
      _metric('Expiring 31–90d', '$soon90'),
      _metric('Risk score', '$riskScore'),
    ],
    line: barVals.every((v) => v == 0)
        ? _lineEmpty()
        : ReportLineSeries(yValues: barVals, xLabels: barLabels),
    bars: [
      for (var i = 0; i < barLabels.length; i++)
        ReportBarPoint(label: barLabels[i], value: barVals[i]),
    ],
    area: _lineEmpty(),
    pie: _pieEmpty(),
    tableColumns: const ['Medicine', 'Expiry', 'Qty', 'Bucket'],
    tableRows: _applyFootprint([for (final r in rows.take(300)) r], filters),
    extraSections: [],
  );
}

ReportDataset buildCustomerDebtDataset({
  required ReportViewFilters filters,
  required String rangeLabel,
  required List<CompletedSaleInvoice> invoices,
  required List<DebtCustomer> customers,
}) {
  final foot = _footnoteEnterprise(filters);

  final byCustomer = <String, ({double open, double paid, int partial})>{};

  for (final c in customers) {
    byCustomer[c.id] = (open: 0, paid: 0, partial: 0);
  }

  for (final inv in invoices) {
    final cid = inv.debtCustomerId;
    if (cid == null) continue;
    final cur = byCustomer[cid] ?? (open: 0, paid: 0, partial: 0);
    var partial = cur.partial;
    if (inv.remainingBalance > 0.009 && inv.paidTowardInvoice > 0.009) partial++;
    byCustomer[cid] = (
      open: cur.open + inv.remainingBalance,
      paid: cur.paid + inv.paidTowardInvoice,
      partial: partial,
    );
  }

  final rows = <List<String>>[];
  for (final c in customers) {
    final s = byCustomer[c.id] ?? (open: 0, paid: 0, partial: 0);
    rows.add([c.name, c.phoneDisplay, _money(s.open), _money(s.paid), '${s.partial}', c.notes]);
  }
  rows.sort((a, b) {
    final pa = double.tryParse(a[2].replaceAll(RegExp(r'[^\d.]'), '')) ?? 0;
    final pb = double.tryParse(b[2].replaceAll(RegExp(r'[^\d.]'), '')) ?? 0;
    return pb.compareTo(pa);
  });

  final history = <List<String>>[];
  for (final inv in invoices.where((i) => i.debtCustomerId != null).toList()..sort((a, b) => b.issuedAt.compareTo(a.issuedAt))) {
    final st = inv.remainingBalance <= 0.009 ? 'Paid' : (inv.paidTowardInvoice <= 0.009 ? 'Open' : 'Partial');
    history.add([
      inv.invoiceNumber,
      inv.customerName,
      inv.issuedAt.toIso8601String().split('T').first,
      _money(inv.total),
      _money(inv.paidTowardInvoice),
      _money(inv.remainingBalance),
      st,
    ]);
    for (final le in inv.debtLedger.take(20)) {
      history.add([
        'pay',
        inv.invoiceNumber,
        le.recordedAt.toIso8601String().split('T').first,
        _money(le.amount),
        le.label,
        '',
        '',
      ]);
    }
  }

  final totalOpen = byCustomer.values.fold<double>(0, (s, v) => s + v.open);
  final overdue = invoices.where((i) => i.hasOpenDebt && i.issuedAt.isBefore(DateTime.now().subtract(const Duration(days: 30)))).length;

  return ReportDataset(
    reportId: KpmsReportId.customerDebt,
    rangeLabel: rangeLabel,
    filterFootnote: foot,
    summaries: [
      _metric('Open AR', _money(totalOpen)),
      _metric('Credit customers', '${customers.length}'),
      _metric('Stale open (30d+)', '$overdue'),
      _metric('Invoices w/ debt', '${invoices.where((i) => i.debtCustomerId != null).length}'),
    ],
    line: rows.isEmpty
        ? _lineEmpty()
        : ReportLineSeries(
            yValues: [
              for (final r in rows.take(12)) double.tryParse(r[2].replaceAll(RegExp(r'[^\d.]'), '')) ?? 0,
            ],
            xLabels: [for (final r in rows.take(12)) r[0].length > 8 ? '${r[0].substring(0, 7)}…' : r[0]],
          ),
    bars: rows.isEmpty
        ? _barsEmpty()
        : [
            for (final r in rows.take(8))
              ReportBarPoint(
                label: r[0].length > 10 ? '${r[0].substring(0, 9)}…' : r[0],
                value: (double.tryParse(r[2].replaceAll(RegExp(r'[^\d.]'), '')) ?? 0) / 100,
              ),
          ],
    area: _lineEmpty(),
    pie: totalOpen > 0.009 && rows.isNotEmpty
        ? [
            for (var i = 0; i < rows.length && i < 4; i++)
              ReportPieSlice(
                label: rows[i][0],
                value:
                    (double.tryParse(rows[i][2].replaceAll(RegExp(r'[^\d.]'), '')) ?? 0).clamp(0.001, 1e15),
                colorArgb: _piePalette[i % 4],
              ),
          ]
        : _pieEmpty(),
    tableColumns: const ['Customer', 'Phone', 'Open', 'Paid', 'Partials', 'Notes'],
    tableRows: _applyFootprint([for (final r in rows.take(200)) r], filters),
    extraSections: [
      ReportTableSection(
        title: 'Invoice & payment history',
        columns: const ['Ref', 'Name / detail', 'Date', 'Amount', 'Extra', 'Balance', 'Status'],
        rows: [for (final h in history.take(250)) h],
      ),
    ],
  );
}

ReportDataset buildSupplierReportDataset({
  required ReportViewFilters filters,
  required ReportDateRange range,
  required String rangeLabel,
  required List<PurchaseInvoice> purchases,
  required List<Supplier> suppliers,
}) {
  final foot = _footnoteEnterprise(filters);
  final purR = purchases.where((p) => _inRange(p.issuedAt, range)).toList();

  final bySup = <String, double>{};
  for (final p in purR) {
    bySup[p.supplierName] = (bySup[p.supplierName] ?? 0) + p.grandTotal;
  }

  final rows = <List<String>>[
    for (final p in purR.take(200))
      [
        p.supplierName,
        p.invoiceNumber,
        p.issuedAt.toIso8601String().split('T').first,
        _money(p.grandTotal),
        p.paymentStatusLabel,
        _money(p.effectiveRemainingBalance),
      ],
  ];

  final supRows = <List<String>>[
    for (final s in suppliers)
      [
        s.name,
        s.phone,
        _money(s.balanceOwed),
        _money(bySup[s.name] ?? 0),
      ],
  ]..sort((a, b) {
      final pa = double.tryParse(a[2].replaceAll(RegExp(r'[^\d.]'), '')) ?? 0;
      final pb = double.tryParse(b[2].replaceAll(RegExp(r'[^\d.]'), '')) ?? 0;
      return pb.compareTo(pa);
    });

  final totalSpend = purR.fold<double>(0, (s, p) => s + p.grandTotal);
  final totalAp = suppliers.fold<double>(0, (s, x) => s + x.balanceOwed);

  final bars = bySup.isEmpty
      ? _barsEmpty()
      : [
          for (final e in bySup.entries.take(8))
            ReportBarPoint(label: e.key.length > 12 ? '${e.key.substring(0, 11)}…' : e.key, value: e.value / 100),
        ];

  return ReportDataset(
    reportId: KpmsReportId.supplierReport,
    rangeLabel: rangeLabel,
    filterFootnote: foot,
    summaries: [
      _metric('Purchases (period)', _money(totalSpend)),
      _metric('Invoices', '${purR.length}'),
      _metric('Supplier AP', _money(totalAp)),
      _metric('Suppliers', '${suppliers.length}'),
    ],
    line: totalSpend > 0.009
        ? ReportLineSeries(yValues: [totalSpend], xLabels: const ['Period'])
        : _lineEmpty(),
    bars: bars,
    area: _lineEmpty(),
    pie: bySup.length <= 4 && bySup.isNotEmpty
        ? [
            for (var i = 0; i < bySup.length; i++)
              ReportPieSlice(
                label: bySup.keys.elementAt(i),
                value: bySup.values.elementAt(i).clamp(0.001, 1e15),
                colorArgb: _piePalette[i % 4],
              ),
          ]
        : _pieEmpty(),
    tableColumns: const ['Supplier', 'Invoice', 'Date', 'Amount', 'Status', 'Open'],
    tableRows: _applyFootprint(rows, filters),
    extraSections: [
      ReportTableSection(
        title: 'Supplier balances & period spend',
        columns: const ['Supplier', 'Phone', 'AP balance', 'Purchases (range)'],
        rows: supRows,
      ),
    ],
  );
}

ReportDataset buildCashierPerformanceDataset({
  required ReportViewFilters filters,
  required ReportDateRange range,
  required String rangeLabel,
  required SalesLedgerState ledger,
}) {
  final foot = _footnoteEnterprise(filters);
  final invoices = ledger.invoices.where((i) => _inRange(i.issuedAt, range)).toList();
  final returns = ledger.returns.where((r) => _inRange(r.issuedAt, range)).toList();

  final byName = <String, ({double rev, int sales, double refunds, int retCount})>{};
  for (final inv in invoices) {
    final n = inv.cashierName.trim().isEmpty ? '—' : inv.cashierName.trim();
    final c = byName[n] ?? (rev: 0, sales: 0, refunds: 0, retCount: 0);
    byName[n] = (rev: c.rev + inv.total, sales: c.sales + 1, refunds: c.refunds, retCount: c.retCount);
  }
  for (final r in returns) {
    final n = r.cashierName.trim().isEmpty ? '—' : r.cashierName.trim();
    final c = byName[n] ?? (rev: 0, sales: 0, refunds: 0, retCount: 0);
    byName[n] = (rev: c.rev, sales: c.sales, refunds: c.refunds + r.refundTotal, retCount: c.retCount + 1);
  }

  final rows = <List<String>>[
    for (final e in byName.entries)
      [
        e.key,
        '${e.value.sales}',
        _money(e.value.rev),
        _money(e.value.refunds),
        '${e.value.retCount}',
        e.value.sales > 0 ? _money(e.value.rev / e.value.sales) : '—',
      ],
  ]..sort((a, b) {
      final pa = double.tryParse(a[2].replaceAll(RegExp(r'[^\d.]'), '')) ?? 0;
      final pb = double.tryParse(b[2].replaceAll(RegExp(r'[^\d.]'), '')) ?? 0;
      return pb.compareTo(pa);
    });

  final totalRev = byName.values.fold<double>(0, (s, v) => s + v.rev);

  return ReportDataset(
    reportId: KpmsReportId.cashierPerformance,
    rangeLabel: rangeLabel,
    filterFootnote: foot,
    summaries: [
      _metric('Cashiers', '${byName.length}'),
      _metric('Sales txns', '${invoices.length}'),
      _metric('Gross revenue', _money(totalRev)),
      _metric('Refunds', _money(returns.fold(0.0, (s, r) => s + r.refundTotal))),
    ],
    line: byName.isEmpty
        ? _lineEmpty()
        : ReportLineSeries(
            yValues: [for (final e in byName.entries.take(10)) e.value.rev / 100],
            xLabels: [for (final e in byName.entries.take(10)) e.key.length > 6 ? '${e.key.substring(0, 5)}…' : e.key],
          ),
    bars: byName.isEmpty
        ? _barsEmpty()
        : [
            for (final e in byName.entries.take(8))
              ReportBarPoint(label: e.key.length > 10 ? '${e.key.substring(0, 9)}…' : e.key, value: e.value.sales.toDouble()),
          ],
    area: _lineEmpty(),
    pie: byName.isEmpty
        ? _pieEmpty()
        : [
            for (var i = 0; i < byName.length && i < 4; i++)
              ReportPieSlice(
                label: byName.keys.elementAt(i),
                value: byName.values.elementAt(i).rev.clamp(0.001, 1e15),
                colorArgb: _piePalette[i % 4],
              ),
          ],
    tableColumns: const ['Cashier', 'Sales #', 'Revenue', 'Refunds', 'Returns #', 'Avg sale'],
    tableRows: _applyFootprint([for (final r in rows.take(200)) r], filters),
    extraSections: [],
  );
}

ReportDataset buildSalesAnalyticsDataset({
  required ReportViewFilters filters,
  required ReportDateRange range,
  required String rangeLabel,
  required List<CompletedSaleInvoice> invoices,
  required SalesAnalyticsState analytics,
}) {
  final foot = _footnoteEnterprise(filters);
  final invR = invoices.where((i) => _inRange(i.issuedAt, range)).toList();

  final productQty = <String, ({String name, int qty, double rev})>{};
  final hourCount = <int, int>{};

  for (final inv in invR) {
    hourCount[inv.issuedAt.hour] = (hourCount[inv.issuedAt.hour] ?? 0) + 1;
    for (final line in inv.lines) {
      final cur = productQty[line.medicineId] ?? (name: line.name, qty: 0, rev: 0);
      productQty[line.medicineId] = (
        name: line.name,
        qty: cur.qty + line.quantitySold,
        rev: cur.rev + line.lineSaleTotal,
      );
    }
  }

  final topProd = productQty.entries.toList()..sort((a, b) => b.value.qty.compareTo(a.value.qty));

  final peakHour = hourCount.entries.isEmpty
      ? 0
      : hourCount.entries.reduce((a, b) => a.value >= b.value ? a : b).key;

  final hourSorted = hourCount.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
  final peakBars = hourSorted.isEmpty
      ? _barsEmpty()
      : [
          for (final e in hourSorted.take(12))
            ReportBarPoint(label: '${e.key}:00', value: e.value.toDouble()),
        ];

  final rows = <List<String>>[
    for (final e in topProd.take(50))
      [e.value.name, '${e.value.qty}', _money(e.value.rev)],
  ];

  return ReportDataset(
    reportId: KpmsReportId.salesAnalytics,
    rangeLabel: rangeLabel,
    filterFootnote: foot,
    summaries: [
      _metric('Invoices', '${invR.length}'),
      _metric('Peak hour', '$peakHour:00'),
      _metric('Distinct SKUs', '${productQty.length}'),
      _metric('Session top-qty', analytics.topSelling.isEmpty ? '—' : analytics.topSelling.first.$1),
    ],
    line: topProd.length >= 3
        ? ReportLineSeries(
            yValues: [for (final e in topProd.take(12)) e.value.rev],
            xLabels: [for (final e in topProd.take(12)) e.value.name.length > 8 ? '${e.value.name.substring(0, 7)}…' : e.value.name],
          )
        : _lineEmpty(),
    bars: peakBars,
    area: analytics.dailySeries.isNotEmpty
        ? ReportLineSeries(
            yValues: analytics.dailySeries,
            xLabels: const ['D-6', 'D-5', 'D-4', 'D-3', 'D-2', 'D-1', 'Today'],
          )
        : _lineEmpty(),
    pie: topProd.isEmpty
        ? _pieEmpty()
        : [
            for (var i = 0; i < topProd.length && i < 4; i++)
              ReportPieSlice(
                label: topProd[i].value.name,
                value: topProd[i].value.rev.clamp(0.001, 1e15),
                colorArgb: _piePalette[i % 4],
              ),
          ],
    tableColumns: const ['Product', 'Qty sold', 'Revenue'],
    tableRows: _applyFootprint(rows, filters),
    extraSections: [],
  );
}
