import 'package:flutter/material.dart';

/// Simplified analytics catalog — slug used in routes and exports.
enum KpmsReportId {
  sales('sales'),
  purchases('purchases'),
  staff('staff'),
  profitLoss('profit_loss'),
  expenseReport('expense_report'),
  inventoryValuation('inventory_valuation'),
  expiryAnalytics('expiry'),
  customerDebt('customer_debt'),
  supplierReport('supplier_report'),
  cashierPerformance('cashier_performance'),
  salesAnalytics('sales_analytics');

  const KpmsReportId(this.slug);

  final String slug;

  static KpmsReportId? tryParse(String slug) {
    for (final v in KpmsReportId.values) {
      if (v.slug == slug) return v;
    }
    return null;
  }

  String get title => switch (this) {
        KpmsReportId.sales => 'Sales report',
        KpmsReportId.purchases => 'Purchase report',
        KpmsReportId.staff => 'Staff report',
        KpmsReportId.profitLoss => 'Profit & loss',
        KpmsReportId.expenseReport => 'Expense report',
        KpmsReportId.inventoryValuation => 'Inventory valuation',
        KpmsReportId.expiryAnalytics => 'Expiry analytics',
        KpmsReportId.customerDebt => 'Customer debt',
        KpmsReportId.supplierReport => 'Supplier report',
        KpmsReportId.cashierPerformance => 'Cashier performance',
        KpmsReportId.salesAnalytics => 'Sales analytics',
      };

  String get description => switch (this) {
        KpmsReportId.sales => 'Revenue, cost, profit, and receivables.',
        KpmsReportId.purchases => 'Spend, suppliers, and payables.',
        KpmsReportId.staff => 'Performance, throughput, and activity.',
        KpmsReportId.profitLoss => 'P&L with purchases, expenses, and returns.',
        KpmsReportId.expenseReport => 'Categories, trends, and expense history.',
        KpmsReportId.inventoryValuation => 'Stock value, movement, and risk SKUs.',
        KpmsReportId.expiryAnalytics => 'Expired and expiring inventory timeline.',
        KpmsReportId.customerDebt => 'Balances, partial payments, and history.',
        KpmsReportId.supplierReport => 'Purchases, AP, and supplier analytics.',
        KpmsReportId.cashierPerformance => 'Throughput, revenue, and refunds by cashier.',
        KpmsReportId.salesAnalytics => 'Top products, categories, and peak hours.',
      };

  IconData get icon => switch (this) {
        KpmsReportId.sales => Icons.point_of_sale_rounded,
        KpmsReportId.purchases => Icons.local_shipping_rounded,
        KpmsReportId.staff => Icons.workspace_premium_rounded,
        KpmsReportId.profitLoss => Icons.account_balance_rounded,
        KpmsReportId.expenseReport => Icons.receipt_long_rounded,
        KpmsReportId.inventoryValuation => Icons.inventory_2_outlined,
        KpmsReportId.expiryAnalytics => Icons.event_busy_outlined,
        KpmsReportId.customerDebt => Icons.people_outline_rounded,
        KpmsReportId.supplierReport => Icons.storefront_outlined,
        KpmsReportId.cashierPerformance => Icons.badge_outlined,
        KpmsReportId.salesAnalytics => Icons.insights_rounded,
      };
}
