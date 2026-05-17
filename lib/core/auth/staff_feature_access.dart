import 'package:flutter/foundation.dart';

import '../constants/app_routes.dart';

/// JSON keys stored in `profiles.permissions` (snake_case).
@immutable
abstract final class StaffPermissionKeys {
  static const accessDashboard = 'access_dashboard';
  static const accessSales = 'access_sales';
  static const accessPos = 'access_pos';
  static const viewInventory = 'view_inventory';
  static const manageInventory = 'manage_inventory';
  static const viewPurchases = 'view_purchases';
  static const createPurchases = 'create_purchases';
  static const viewReports = 'view_reports';
  static const viewProfit = 'view_profit';
  static const viewExpenses = 'view_expenses';
  static const viewCustomers = 'view_customers';
  static const viewSuppliers = 'view_suppliers';
  static const viewDebts = 'view_debts';
  static const manageStaff = 'manage_staff';
  static const accessSettings = 'access_settings';
  static const deleteTransactions = 'delete_transactions';
  static const editInvoices = 'edit_invoices';
  static const viewNotifications = 'view_notifications';
  static const viewPrescriptions = 'view_prescriptions';
  static const accessSubscriptions = 'access_subscriptions';
  static const viewMedicines = 'view_medicines';
  static const accessSalesReturns = 'access_sales_returns';
  static const accessTransactions = 'access_transactions';

  static const manageNotifications = 'manage_notifications';
  /// Aligns with enterprise "manage_expenses" (write access); mirrors [viewExpenses] until split in UI.
  static const manageExpenses = 'manage_expenses';

  /// Enterprise spec aliases — same underlying JSON keys as [accessDashboard], [accessSales], etc.
  static const viewDashboard = accessDashboard;
  static const manageSales = accessSales;
  static const deleteSales = deleteTransactions;
  static const managePurchases = createPurchases;
  static const exportReports = viewReports;
  static const manageSettings = accessSettings;
  static const manageSubscriptions = accessSubscriptions;

  /// Default map for a new invite (tunable in UI before send) — **strict POS-focused cashier**.
  static Map<String, dynamic> defaultSalesStaffTemplate() => {
        accessDashboard: false,
        accessSales: true,
        accessPos: true,
        viewInventory: false,
        manageInventory: false,
        viewPurchases: false,
        createPurchases: false,
        viewReports: false,
        viewProfit: false,
        viewExpenses: false,
        viewCustomers: true,
        viewSuppliers: false,
        viewDebts: false,
        manageStaff: false,
        accessSettings: false,
        deleteTransactions: false,
        editInvoices: true,
        viewNotifications: true,
        viewPrescriptions: false,
        accessSubscriptions: false,
        viewMedicines: true,
        accessSalesReturns: true,
        accessTransactions: true,
      };

  /// **Deny-by-default** when `permissions` is missing or `{}` (legacy rows).
  /// Only POS/customer/sales-adjacent surfaces; no reports, dashboard, or finance.
  static Map<String, dynamic> strictStaffDefaultsWhenUnset() => Map<String, dynamic>.from(defaultSalesStaffTemplate());

  /// Preset for `manager` role when JSON is empty — operations without owner-only areas.
  static Map<String, dynamic> defaultManagerTemplate() => {
        accessDashboard: true,
        accessSales: true,
        accessPos: true,
        viewInventory: true,
        manageInventory: true,
        viewPurchases: true,
        createPurchases: false,
        viewReports: true,
        viewProfit: false,
        viewExpenses: true,
        viewCustomers: true,
        viewSuppliers: true,
        viewDebts: true,
        manageStaff: false,
        accessSettings: false,
        deleteTransactions: false,
        editInvoices: true,
        viewNotifications: true,
        viewPrescriptions: true,
        accessSubscriptions: false,
        viewMedicines: true,
        accessSalesReturns: true,
        accessTransactions: true,
      };
}

/// Effective feature access for pharmacy users (tenant admins = full access).
@immutable
class StaffFeatureAccess {
  const StaffFeatureAccess._({
    required bool fullTenantAdmin,
    required Map<String, dynamic> raw,
  })  : _raw = raw,
        _full = fullTenantAdmin;

  /// Pharmacy owner / pharmacist — all modules & financials (JSON ignored for gates).
  factory StaffFeatureAccess.tenantAdmin() => const StaffFeatureAccess._(fullTenantAdmin: true, raw: {});

  /// Platform operator — only super-admin routes (caller handles route prefix).
  factory StaffFeatureAccess.platform() => const StaffFeatureAccess._(fullTenantAdmin: true, raw: {});

  /// Staff / cashier / manager — permissions from JSON.
  /// [whenEmptyUseManagerPreset] picks defaults for `manager` role vs `staff`/`cashier`.
  factory StaffFeatureAccess.fromPermissionsMap(
    Map<String, dynamic>? map, {
    bool whenEmptyUseManagerPreset = false,
  }) {
    if (map == null || map.isEmpty) {
      final base = whenEmptyUseManagerPreset
          ? StaffPermissionKeys.defaultManagerTemplate()
          : StaffPermissionKeys.strictStaffDefaultsWhenUnset();
      return StaffFeatureAccess._(fullTenantAdmin: false, raw: base);
    }
    return StaffFeatureAccess._(fullTenantAdmin: false, raw: Map<String, dynamic>.from(map));
  }

  final bool _full;
  final Map<String, dynamic> _raw;

  bool _bool(String key) {
    if (_full) return true;
    final v = _raw[key];
    if (v is bool) return v;
    if (v is num) return v != 0;
    if (v is String) return v == '1' || v.toLowerCase() == 'true';
    return false;
  }

  bool get _canViewNotifications =>
      _bool(StaffPermissionKeys.viewNotifications) || _bool(StaffPermissionKeys.manageNotifications);

  bool get _canUseExpenses =>
      _bool(StaffPermissionKeys.viewExpenses) || _bool(StaffPermissionKeys.manageExpenses);

  bool get canViewFinancialMetrics => _bool(StaffPermissionKeys.viewProfit);

  bool get canManageStaffDirectory => _full || _bool(StaffPermissionKeys.manageStaff);

  bool canAccessRoute(String location) {
    if (_full) {
      return !location.startsWith(AppRoutes.superAdmin);
    }
    if (location.startsWith(AppRoutes.superAdmin)) return false;

    if (location == AppRoutes.home) return _bool(StaffPermissionKeys.accessDashboard);

    if (location == AppRoutes.addMedicine) {
      return _bool(StaffPermissionKeys.manageInventory);
    }
    if (location.startsWith(AppRoutes.medicines)) {
      return _bool(StaffPermissionKeys.viewMedicines) || _bool(StaffPermissionKeys.manageInventory);
    }

    if (location.startsWith(AppRoutes.inventory)) {
      return _bool(StaffPermissionKeys.viewInventory) || _bool(StaffPermissionKeys.manageInventory);
    }
    if (location.startsWith(AppRoutes.pos) || location.startsWith(AppRoutes.checkout)) {
      return _bool(StaffPermissionKeys.accessPos) || _bool(StaffPermissionKeys.accessSales);
    }
    if (location.startsWith(AppRoutes.salesReturns)) return _bool(StaffPermissionKeys.accessSalesReturns);
    if (location.startsWith(AppRoutes.debts) || location.startsWith(AppRoutes.supplierFinance)) {
      return _bool(StaffPermissionKeys.viewDebts);
    }
    if (location.startsWith(AppRoutes.purchases) || location.startsWith(AppRoutes.purchaseReturns)) {
      return _bool(StaffPermissionKeys.viewPurchases) || _bool(StaffPermissionKeys.createPurchases);
    }
    if (location.startsWith(AppRoutes.suppliers)) return _bool(StaffPermissionKeys.viewSuppliers);
    if (location.startsWith(AppRoutes.customers)) return _bool(StaffPermissionKeys.viewCustomers);
    if (location.startsWith(AppRoutes.prescriptions)) return _bool(StaffPermissionKeys.viewPrescriptions);
    if (location.startsWith(AppRoutes.staff)) return _bool(StaffPermissionKeys.manageStaff);
    if (location.startsWith(AppRoutes.reports)) return _bool(StaffPermissionKeys.viewReports);
    if (location.startsWith(AppRoutes.expenses)) return _canUseExpenses;
    if (location.startsWith(AppRoutes.medicineCategories)) {
      return _bool(StaffPermissionKeys.manageInventory) || _bool(StaffPermissionKeys.viewInventory);
    }
    if (location.startsWith(AppRoutes.subscriptions)) return _bool(StaffPermissionKeys.accessSubscriptions);
    if (location.startsWith(AppRoutes.settings)) return _bool(StaffPermissionKeys.accessSettings);
    if (location.startsWith(AppRoutes.profile)) return true;
    if (location.startsWith(AppRoutes.notifications)) return _canViewNotifications;
    if (location.startsWith(AppRoutes.barcodeScanner)) {
      return _bool(StaffPermissionKeys.accessPos) ||
          _bool(StaffPermissionKeys.viewInventory) ||
          _bool(StaffPermissionKeys.manageInventory);
    }
    if (location.startsWith(AppRoutes.transactions)) {
      return _bool(StaffPermissionKeys.accessTransactions);
    }
    return false;
  }

  /// First sensible home route for this user.
  String get defaultWorkspaceRoute {
    if (_full) return AppRoutes.home;
    if (_bool(StaffPermissionKeys.viewReports) &&
        !_bool(StaffPermissionKeys.accessPos) &&
        !_bool(StaffPermissionKeys.accessSales)) {
      return AppRoutes.reports;
    }
    if (_bool(StaffPermissionKeys.accessPos) || _bool(StaffPermissionKeys.accessSales)) {
      return AppRoutes.pos;
    }
    if (_bool(StaffPermissionKeys.accessDashboard)) return AppRoutes.home;
    if (_bool(StaffPermissionKeys.viewMedicines)) return AppRoutes.medicines;
    if (_bool(StaffPermissionKeys.viewInventory) || _bool(StaffPermissionKeys.manageInventory)) {
      return AppRoutes.inventory;
    }
    if (_bool(StaffPermissionKeys.viewCustomers)) return AppRoutes.customers;
    if (_canViewNotifications) return AppRoutes.notifications;
    return AppRoutes.pos;
  }

  Map<String, dynamic> toJson() => Map<String, dynamic>.from(_raw);

  static Map<String, dynamic> mergeDefaults(Map<String, dynamic> edited) {
    final base = StaffPermissionKeys.defaultSalesStaffTemplate();
    base.addAll(edited);
    return base;
  }
}
