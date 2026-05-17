import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/analytics/kpms_analytics_log.dart';
import '../../../core/tenant/kpms_active_tenant_provider.dart';
import '../../../core/tenant/pharmacy_workspace_isolation.dart';
import '../../analytics/application/sales_analytics_notifier.dart';
import '../../debts/application/debt_customers_notifier.dart';
import '../../enterprise/application/pharmacy_expenses_notifier.dart';
import '../../medicines/data/medicine_catalog_notifier.dart';
import '../../purchases/application/purchase_ledger_notifier.dart';
import '../../sales/application/sales_ledger_notifier.dart';
import '../../suppliers/application/suppliers_notifier.dart';
import '../domain/kpms_report_id.dart';
import '../domain/report_view_filters.dart';
import 'report_dataset_builder.dart';
import 'report_models.dart';

typedef ReportQuery = ({KpmsReportId id, ReportViewFilters filters});

final reportDatasetProvider = Provider.autoDispose.family<ReportDataset, ReportQuery>((ref, q) {
  final analytics = ref.watch(salesAnalyticsProvider);
  final ledger = ref.watch(salesLedgerProvider);
  final saleInvoices = ledger.invoices;
  final saleReturns = ledger.returns;
  final purchaseInvoices = ref.watch(purchaseLedgerProvider).invoices;
  final suppliers = ref.watch(suppliersProvider);
  final expenses = ref.watch(pharmacyExpensesProvider);
  final medicines = ref.watch(medicineCatalogProvider);
  final debtCustomers = ref.watch(debtCustomersProvider);
  final tid = ref.watch(kpmsActiveTenantIdProvider).valueOrNull;
  final loaded = ref.watch(kpmsLoadedWorkspaceTenantProvider);

  if (tid != null && tid.isNotEmpty && loaded != null && loaded != tid) {
    KpmsAnalyticsLog.crossTenantBlocked('report_dataset loaded=$loaded active=$tid');
  }

  final dataset = buildReportDataset(
    id: q.id,
    filters: q.filters,
    analytics: analytics,
    saleInvoices: saleInvoices,
    saleReturns: saleReturns,
    purchaseInvoices: purchaseInvoices,
    suppliers: suppliers,
    expenses: expenses,
    medicines: medicines,
    debtCustomers: debtCustomers,
    salesLedgerState: ledger,
    workspaceTenantId: tid,
  );

  if (tid != null && tid.isNotEmpty) {
    KpmsAnalyticsLog.analyticsLoaded(tenantId: tid, reportSlug: q.id.slug);
  }

  return dataset;
});
