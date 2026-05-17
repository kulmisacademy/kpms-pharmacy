import 'package:flutter/foundation.dart';

/// High-level notification categories (maps to `pharmacy_notifications.kind`).
abstract final class KpmsNotificationKind {
  static const lowStock = 'low_stock';
  static const expiryExpired = 'expiry_expired';
  static const expirySoon7 = 'expiry_soon_7d';
  static const expirySoon30 = 'expiry_soon_30d';
  static const debtCustomerOverdue = 'debt_customer_overdue';
  static const debtSupplierOverdue = 'debt_supplier_overdue';
  static const syncFailed = 'sync_failed';
  static const syncBacklog = 'sync_backlog';
  static const subscriptionWarning = 'subscription_warning';
  static const staffLargeRefund = 'staff_large_refund';
  static const staffSuspicious = 'staff_suspicious';
  static const staffPermissionUpdated = 'staff_permission_updated';
  static const salesMilestone = 'sales_milestone';
  static const saleCompleted = 'sale_completed';
  static const medicineAdded = 'medicine_added';
  static const expenseAdded = 'expense_added';
  static const syncCompleted = 'sync_completed';

  static String groupLabel(String kind) => switch (kind) {
        lowStock => 'Inventory',
        expiryExpired || expirySoon7 || expirySoon30 => 'Expiry',
        debtCustomerOverdue || debtSupplierOverdue => 'Debts',
        syncFailed || syncBacklog => 'Sync',
        subscriptionWarning => 'Subscription',
        staffLargeRefund || staffSuspicious || staffPermissionUpdated => 'Staff',
        salesMilestone || saleCompleted => 'Sales',
        medicineAdded => 'Inventory',
        expenseAdded => 'Finance',
        syncCompleted => 'Sync',
        _ => 'Other',
      };
}

/// Paged notification inbox state (in-memory; realtime refresh reloads first window).
@immutable
class PharmacyNotificationFeedModel {
  const PharmacyNotificationFeedModel({
    required this.items,
    required this.hasMore,
    this.isLoadingMore = false,
  });

  final List<PharmacyNotificationItem> items;
  final bool hasMore;
  final bool isLoadingMore;

  PharmacyNotificationFeedModel copyWith({
    List<PharmacyNotificationItem>? items,
    bool? hasMore,
    bool? isLoadingMore,
  }) {
    return PharmacyNotificationFeedModel(
      items: items ?? this.items,
      hasMore: hasMore ?? this.hasMore,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    );
  }
}

@immutable
class PharmacyNotificationItem {
  const PharmacyNotificationItem({
    required this.id,
    required this.tenantId,
    required this.kind,
    required this.title,
    required this.body,
    required this.payload,
    required this.priority,
    required this.dedupeKey,
    required this.createdAt,
    this.readAt,
  });

  final String id;
  final String tenantId;
  final String kind;
  final String title;
  final String body;
  final Map<String, dynamic> payload;
  final String priority;
  final String dedupeKey;
  final DateTime createdAt;
  final DateTime? readAt;

  bool get isUnread => readAt == null;

  PharmacyNotificationItem copyWith({DateTime? readAt}) {
    return PharmacyNotificationItem(
      id: id,
      tenantId: tenantId,
      kind: kind,
      title: title,
      body: body,
      payload: payload,
      priority: priority,
      dedupeKey: dedupeKey,
      createdAt: createdAt,
      readAt: readAt ?? this.readAt,
    );
  }

  factory PharmacyNotificationItem.fromRow(
    Map<String, dynamic> row, {
    DateTime? readAt,
    required String priorityFromSeverity,
  }) {
    final p = row['metadata'];
    Map<String, dynamic> payload = {};
    if (p is Map<String, dynamic>) {
      payload = Map<String, dynamic>.from(p);
    } else if (p is Map) {
      payload = Map<String, dynamic>.from(p);
    }
    final kindVal = '${row['kind'] ?? ''}'.trim();
    final kindResolved =
        kindVal.isEmpty || kindVal == 'general' ? '${payload['kpms_kind'] ?? 'general'}' : kindVal;
    return PharmacyNotificationItem(
      id: '${row['id']}',
      tenantId: '${row['tenant_id']}',
      kind: kindResolved,
      title: '${row['title']}',
      body: '${row['body'] ?? ''}',
      payload: payload,
      priority: priorityFromSeverity,
      dedupeKey: '${row['client_id']}',
      createdAt: DateTime.tryParse('${row['created_at']}') ?? DateTime.now(),
      readAt: readAt,
    );
  }
}
