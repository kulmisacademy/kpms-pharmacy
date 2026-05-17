import 'package:flutter/foundation.dart';

import 'staff_feature_access.dart';

/// Enterprise role templates (stored `profiles.role` + JSON `profiles.permissions`).
/// Presets clone/merge safely; tenant owners/admins use admin tier (JSON often ignored).

/// One selectable enterprise role (UI label + `profiles.role` value).
@immutable
class KpmsStaffRoleOption {
  const KpmsStaffRoleOption({required this.label, required this.dbRole});
  final String label;
  final String dbRole;
}

@immutable
abstract final class KpmsRolePresets {
  static Map<String, dynamic> _clinicalPharmacist() => {
        StaffPermissionKeys.accessDashboard: false,
        StaffPermissionKeys.accessSales: false,
        StaffPermissionKeys.accessPos: false,
        StaffPermissionKeys.viewMedicines: true,
        StaffPermissionKeys.viewInventory: true,
        StaffPermissionKeys.manageInventory: true,
        StaffPermissionKeys.viewPurchases: true,
        StaffPermissionKeys.createPurchases: false,
        StaffPermissionKeys.viewReports: false,
        StaffPermissionKeys.viewProfit: false,
        StaffPermissionKeys.viewExpenses: false,
        StaffPermissionKeys.viewCustomers: false,
        StaffPermissionKeys.viewSuppliers: true,
        StaffPermissionKeys.viewDebts: false,
        StaffPermissionKeys.manageStaff: false,
        StaffPermissionKeys.accessSettings: false,
        StaffPermissionKeys.deleteTransactions: false,
        StaffPermissionKeys.editInvoices: false,
        StaffPermissionKeys.viewNotifications: true,
        StaffPermissionKeys.manageNotifications: false,
        StaffPermissionKeys.viewPrescriptions: true,
        StaffPermissionKeys.accessSubscriptions: false,
        StaffPermissionKeys.accessSalesReturns: false,
        StaffPermissionKeys.accessTransactions: false,
      };

  static Map<String, dynamic> _accountant() => {
        StaffPermissionKeys.accessDashboard: true,
        StaffPermissionKeys.accessSales: false,
        StaffPermissionKeys.accessPos: false,
        StaffPermissionKeys.viewMedicines: false,
        StaffPermissionKeys.viewInventory: false,
        StaffPermissionKeys.manageInventory: false,
        StaffPermissionKeys.viewPurchases: false,
        StaffPermissionKeys.createPurchases: false,
        StaffPermissionKeys.viewReports: true,
        StaffPermissionKeys.viewProfit: true,
        StaffPermissionKeys.viewExpenses: true,
        StaffPermissionKeys.viewCustomers: true,
        StaffPermissionKeys.viewSuppliers: false,
        StaffPermissionKeys.viewDebts: true,
        StaffPermissionKeys.manageStaff: false,
        StaffPermissionKeys.accessSettings: false,
        StaffPermissionKeys.deleteTransactions: false,
        StaffPermissionKeys.editInvoices: false,
        StaffPermissionKeys.viewNotifications: true,
        StaffPermissionKeys.manageNotifications: false,
        StaffPermissionKeys.viewPrescriptions: false,
        StaffPermissionKeys.accessSubscriptions: false,
        StaffPermissionKeys.accessSalesReturns: false,
        StaffPermissionKeys.accessTransactions: true,
      };

  static Map<String, dynamic> _inventoryManager() => {
        StaffPermissionKeys.accessDashboard: false,
        StaffPermissionKeys.accessSales: false,
        StaffPermissionKeys.accessPos: false,
        StaffPermissionKeys.viewMedicines: true,
        StaffPermissionKeys.viewInventory: true,
        StaffPermissionKeys.manageInventory: true,
        StaffPermissionKeys.viewPurchases: true,
        StaffPermissionKeys.createPurchases: true,
        StaffPermissionKeys.viewReports: false,
        StaffPermissionKeys.viewProfit: false,
        StaffPermissionKeys.viewExpenses: false,
        StaffPermissionKeys.viewCustomers: false,
        StaffPermissionKeys.viewSuppliers: true,
        StaffPermissionKeys.viewDebts: false,
        StaffPermissionKeys.manageStaff: false,
        StaffPermissionKeys.accessSettings: false,
        StaffPermissionKeys.deleteTransactions: false,
        StaffPermissionKeys.editInvoices: false,
        StaffPermissionKeys.viewNotifications: true,
        StaffPermissionKeys.manageNotifications: false,
        StaffPermissionKeys.viewPrescriptions: false,
        StaffPermissionKeys.accessSubscriptions: false,
        StaffPermissionKeys.accessSalesReturns: false,
        StaffPermissionKeys.accessTransactions: false,
      };

  /// Default permissions when JSON is empty for a non-admin DB role.
  static Map<String, dynamic> defaultsForDbRole(String role) {
    switch (role) {
      case 'pharmacy_admin':
      case 'pharmacy_owner':
        return {};
      case 'accountant':
        return Map<String, dynamic>.from(_accountant());
      case 'inventory_manager':
        return Map<String, dynamic>.from(_inventoryManager());
      case 'clinical_pharmacist':
        return Map<String, dynamic>.from(_clinicalPharmacist());
      case 'manager':
        return Map<String, dynamic>.from(StaffPermissionKeys.defaultManagerTemplate());
      case 'cashier':
      case 'staff':
        return Map<String, dynamic>.from(StaffPermissionKeys.defaultSalesStaffTemplate());
      default:
        return {};
    }
  }

  /// Preset base merged with stored JSON (custom roles / edits inherit then override).
  static Map<String, dynamic> mergeRoleDefaults(String role, Map<String, dynamic>? stored) {
    final base = defaultsForDbRole(role);
    if (base.isEmpty) {
      return Map<String, dynamic>.from(stored ?? {});
    }
    final out = Map<String, dynamic>.from(base);
    if (stored != null) {
      out.addAll(stored);
    }
    return out;
  }

  /// UI: invite / create / edit dropdown entries (label → db role).
  static const List<KpmsStaffRoleOption> enterpriseRoleOptions = [
    KpmsStaffRoleOption(label: 'Cashier', dbRole: 'cashier'),
    KpmsStaffRoleOption(label: 'Staff', dbRole: 'staff'),
    KpmsStaffRoleOption(label: 'Manager', dbRole: 'manager'),
    KpmsStaffRoleOption(label: 'Pharmacist (clinical)', dbRole: 'clinical_pharmacist'),
    KpmsStaffRoleOption(label: 'Pharmacist (admin)', dbRole: 'pharmacist'),
    KpmsStaffRoleOption(label: 'Pharmacy admin', dbRole: 'pharmacy_admin'),
    KpmsStaffRoleOption(label: 'Accountant', dbRole: 'accountant'),
    KpmsStaffRoleOption(label: 'Inventory manager', dbRole: 'inventory_manager'),
  ];

  static void applyRoleTemplate(String dbRole, void Function(Map<String, dynamic> next) apply) {
    final next = mergeRoleDefaults(dbRole, {});
    apply(next);
  }
}
