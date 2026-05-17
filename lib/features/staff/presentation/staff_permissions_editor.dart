import 'package:flutter/material.dart';

import '../../../core/auth/staff_feature_access.dart';

/// Grouped toggles for [StaffPermissionKeys] — compact, enterprise-style.
class StaffPermissionsEditor extends StatelessWidget {
  const StaffPermissionsEditor({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final Map<String, dynamic> value;
  final ValueChanged<Map<String, dynamic>> onChanged;

  bool _read(String key) {
    final v = value[key];
    if (v is bool) return v;
    if (v is num) return v != 0;
    if (v is String) return v == '1' || v.toLowerCase() == 'true';
    return false;
  }

  void _write(String key, bool enabled) {
    final next = Map<String, dynamic>.from(value);
    next[key] = enabled;
    onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final groups = _groups;

    return Column(
      children: [
        for (var gi = 0; gi < groups.length; gi++) ...[
          if (gi > 0) const SizedBox(height: 12),
          Material(
            color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(color: theme.colorScheme.outline.withValues(alpha: 0.18)),
            ),
            clipBehavior: Clip.antiAlias,
            child: Theme(
              data: theme.copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                initiallyExpanded: gi == 0,
                tilePadding: const EdgeInsets.fromLTRB(16, 4, 12, 4),
                childrenPadding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
                title: Text(
                  groups[gi].title,
                  style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                ),
                subtitle: Text(
                  groups[gi].subtitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.62),
                  ),
                ),
                children: [
                  for (final item in groups[gi].items)
                    SwitchListTile.adaptive(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                      title: Text(item.label, style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600)),
                      value: _read(item.key),
                      onChanged: (v) => _write(item.key, v),
                    ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _Group {
  const _Group({required this.title, required this.subtitle, required this.items});
  final String title;
  final String subtitle;
  final List<({String key, String label})> items;
}

const List<_Group> _groups = [
  _Group(
    title: 'Workspace',
    subtitle: 'Landing & overview',
    items: [
      (key: StaffPermissionKeys.accessDashboard, label: 'Dashboard overview'),
    ],
  ),
  _Group(
    title: 'Sales & POS',
    subtitle: 'Checkout, receipts, returns',
    items: [
      (key: StaffPermissionKeys.accessSales, label: 'Sales workspace'),
      (key: StaffPermissionKeys.accessPos, label: 'POS & checkout'),
      (key: StaffPermissionKeys.editInvoices, label: 'Edit invoices'),
      (key: StaffPermissionKeys.deleteTransactions, label: 'Delete / void transactions'),
      (key: StaffPermissionKeys.accessSalesReturns, label: 'Sales returns'),
      (key: StaffPermissionKeys.accessTransactions, label: 'Transactions history & exports'),
    ],
  ),
  _Group(
    title: 'Catalog & stock',
    subtitle: 'Medicines and inventory',
    items: [
      (key: StaffPermissionKeys.viewMedicines, label: 'View medicines'),
      (key: StaffPermissionKeys.viewInventory, label: 'View inventory'),
      (key: StaffPermissionKeys.manageInventory, label: 'Manage inventory & adjustments'),
    ],
  ),
  _Group(
    title: 'Purchasing',
    subtitle: 'Supplier orders',
    items: [
      (key: StaffPermissionKeys.viewPurchases, label: 'View purchases'),
      (key: StaffPermissionKeys.createPurchases, label: 'Create purchases & receiving'),
    ],
  ),
  _Group(
    title: 'Finance & analytics',
    subtitle: 'Sensitive business metrics',
    items: [
      (key: StaffPermissionKeys.viewReports, label: 'Reports & exports'),
      (key: StaffPermissionKeys.viewProfit, label: 'Profit, margins & revenue analytics'),
      (key: StaffPermissionKeys.viewExpenses, label: 'Expenses'),
    ],
  ),
  _Group(
    title: 'Relationships',
    subtitle: 'Customers, suppliers, credit',
    items: [
      (key: StaffPermissionKeys.viewCustomers, label: 'Customers'),
      (key: StaffPermissionKeys.viewSuppliers, label: 'Suppliers'),
      (key: StaffPermissionKeys.viewDebts, label: 'Debts & supplier finance'),
    ],
  ),
  _Group(
    title: 'Operations',
    subtitle: 'Notifications & subscriptions',
    items: [
      (key: StaffPermissionKeys.viewNotifications, label: 'View notifications'),
      (key: StaffPermissionKeys.manageNotifications, label: 'Manage notification inbox'),
      (key: StaffPermissionKeys.viewPrescriptions, label: 'Prescriptions'),
      (key: StaffPermissionKeys.accessSubscriptions, label: 'Subscription & billing'),
    ],
  ),
  _Group(
    title: 'Administration',
    subtitle: 'Tenant configuration',
    items: [
      (key: StaffPermissionKeys.manageStaff, label: 'Manage staff & permissions'),
      (key: StaffPermissionKeys.accessSettings, label: 'Settings'),
      (key: StaffPermissionKeys.manageExpenses, label: 'Expense management (edit/approve)'),
    ],
  ),
];
