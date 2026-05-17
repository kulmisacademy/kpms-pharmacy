import '../../analytics/application/sales_analytics_notifier.dart';
import '../../medicines/domain/medicine.dart';
import '../domain/kpms_report_id.dart';

/// Hub card subtitles — derived from live session state.
({String line1, String line2, double? trendPct}) reportHubPreview({
  required KpmsReportId id,
  required SalesAnalyticsState analytics,
  required List<Medicine> catalog,
  required int purchaseInvoiceCount,
  required int debtCustomerCount,
}) {
  switch (id) {
    case KpmsReportId.sales:
      final t = analytics.dailyTotal;
      final low = catalog.where((m) => m.isLowStock).length;
      return (
        line1: t > 0.009 ? '${t.toStringAsFixed(2)} sales (session)' : 'No sales recorded yet',
        line2: low > 0 ? '$low SKU low stock' : 'Profit, cost, and receivables in one workspace',
        trendPct: null,
      );
    case KpmsReportId.purchases:
      return (
        line1: purchaseInvoiceCount > 0 ? '$purchaseInvoiceCount purchase(s)' : 'No purchases recorded',
        line2: debtCustomerCount > 0 ? '$debtCustomerCount credit customer(s)' : 'Spend trends and supplier balances',
        trendPct: null,
      );
    case KpmsReportId.staff:
      return (
        line1: 'Cashier totals from POS invoices',
        line2: 'Performance and checkout activity',
        trendPct: null,
      );
    case KpmsReportId.profitLoss:
      return (
        line1: 'Net sales, gross profit, expenses',
        line2: 'Returns-aware P&L for the selected period',
        trendPct: null,
      );
    case KpmsReportId.expenseReport:
      return (
        line1: 'Categories & monthly burn',
        line2: 'Operating expenses with trends',
        trendPct: null,
      );
    case KpmsReportId.inventoryValuation:
      final v = catalog.fold<double>(0, (s, m) => s + m.quantity * m.buyingPrice);
      return (
        line1: v > 0.009 ? '${v.toStringAsFixed(0)} stock value' : 'Inventory valuation',
        line2: 'Movement, dead stock, and low-stock alerts',
        trendPct: null,
      );
    case KpmsReportId.expiryAnalytics:
      final expiring = catalog.where((m) {
        final e = m.expiryDate;
        if (e == null) return false;
        final d = DateTime(e.year, e.month, e.day).difference(DateTime.now()).inDays;
        return d >= 0 && d <= 90;
      }).length;
      return (
        line1: expiring > 0 ? '$expiring SKU near expiry' : 'Expiry coverage',
        line2: 'Expired, soon, and timeline risk',
        trendPct: null,
      );
    case KpmsReportId.customerDebt:
      return (
        line1: debtCustomerCount > 0 ? '$debtCustomerCount debtor(s)' : 'Receivables workspace',
        line2: 'Open balances and payment trails',
        trendPct: null,
      );
    case KpmsReportId.supplierReport:
      return (
        line1: purchaseInvoiceCount > 0 ? '$purchaseInvoiceCount PO row(s)' : 'Supplier analytics',
        line2: 'Purchases, AP, and period spend',
        trendPct: null,
      );
    case KpmsReportId.cashierPerformance:
      return (
        line1: 'Refunds and revenue by cashier',
        line2: 'POS throughput for the period',
        trendPct: null,
      );
    case KpmsReportId.salesAnalytics:
      return (
        line1: analytics.topSelling.isEmpty ? 'Top sellers & hours' : 'Top: ${analytics.topSelling.first.$1}',
        line2: 'Products, hours, and mix charts',
        trendPct: null,
      );
  }
}
