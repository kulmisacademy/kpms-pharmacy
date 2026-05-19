import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'pharmacy_admin_actions.dart';

/// Operator action menu for a pharmacy directory row.
class PharmacyRowActionMenu extends ConsumerWidget {
  const PharmacyRowActionMenu({
    super.key,
    required this.tenantId,
    required this.row,
    this.compact = false,
  });

  final String tenantId;
  final Map<String, dynamic> row;
  final bool compact;

  bool get _suspended => row['operational_status'] == 'suspended';
  bool get _archived => row['operational_status'] == 'archived';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PopupMenuButton<String>(
      tooltip: 'Actions',
      icon: Icon(compact ? Icons.more_vert_rounded : Icons.tune_rounded, size: compact ? 22 : 20),
      onSelected: (v) => _handle(context, ref, v),
      itemBuilder: (ctx) => [
        const PopupMenuItem(value: 'view', child: _Item(Icons.visibility_outlined, 'View pharmacy')),
        const PopupMenuItem(value: 'analytics', child: _Item(Icons.insights_outlined, 'View analytics')),
        const PopupMenuItem(value: 'subscription', child: _Item(Icons.subscriptions_outlined, 'Manage subscription')),
        const PopupMenuItem(value: 'staff', child: _Item(Icons.groups_outlined, 'View staff')),
        const PopupMenuDivider(),
        if (!_archived && !_suspended)
          const PopupMenuItem(value: 'suspend', child: _Item(Icons.block_rounded, 'Suspend')),
        if (_suspended && !_archived)
          const PopupMenuItem(value: 'activate', child: _Item(Icons.check_circle_outline, 'Activate')),
        const PopupMenuItem(value: 'edit', child: _Item(Icons.edit_outlined, 'Edit pharmacy')),
        if (!_archived)
          const PopupMenuItem(value: 'archive', child: _Item(Icons.archive_outlined, 'Archive (soft delete)')),
        const PopupMenuDivider(),
        if (!_archived) ...[
          const PopupMenuItem(value: 'force_logout', child: _Item(Icons.logout_rounded, 'Force logout staff')),
          const PopupMenuItem(value: 'reset_sync', child: _Item(Icons.sync_problem_rounded, 'Reset sync / cache')),
          const PopupMenuItem(value: 'announce', child: _Item(Icons.campaign_outlined, 'Send announcement')),
          const PopupMenuItem(value: 'audit', child: _Item(Icons.history_edu_outlined, 'Activity logs')),
        ],
      ],
    );
  }

  Future<void> _handle(BuildContext context, WidgetRef ref, String action) async {
    switch (action) {
      case 'view':
        await PharmacyAdminActions.viewPharmacy(context, tenantId);
      case 'analytics':
        PharmacyAdminActions.viewAnalytics(context, tenantId);
      case 'subscription':
        PharmacyAdminActions.manageSubscription(context, tenantId);
      case 'staff':
        PharmacyAdminActions.viewStaff(context, tenantId);
      case 'suspend':
        await PharmacyAdminActions.suspend(context, ref, tenantId, row: row);
      case 'activate':
        await PharmacyAdminActions.reactivate(context, ref, tenantId);
      case 'edit':
        final tenant = {
          'name': row['pharmacy_name'],
          'address': row['address'],
          'phone': row['pharmacy_phone'] ?? row['owner_phone'],
          'license_number': row['license_number'],
          'owner_name': row['owner_name'] ?? row['owner_name_display'],
        };
        await PharmacyAdminActions.editPharmacy(context, ref, tenantId, tenant);
      case 'archive':
        await PharmacyAdminActions.archiveSoftDelete(context, ref, tenantId);
      case 'force_logout':
        await PharmacyAdminActions.forceLogout(context, ref, tenantId);
      case 'reset_sync':
        await PharmacyAdminActions.resetSyncCache(context, ref, tenantId);
      case 'announce':
        PharmacyAdminActions.sendAnnouncement(context);
      case 'audit':
        PharmacyAdminActions.viewAudit(context, ref, tenantId);
    }
  }
}

class _Item extends StatelessWidget {
  const _Item(this.icon, this.label);

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20),
        const SizedBox(width: 10),
        Expanded(child: Text(label)),
      ],
    );
  }
}
