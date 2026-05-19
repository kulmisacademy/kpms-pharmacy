import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../pharmacy_cloud/application/sync_integrity_diagnostics_provider.dart';
import '../../../../providers/pharmacy_local_workspace.dart';

/// Tenant sync integrity diagnostics (search `[kpms.sync]` for related logs).
class SyncIntegrityCard extends ConsumerWidget {
  const SyncIntegrityCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final async = ref.watch(syncIntegrityDiagnosticsProvider);
    final headerStyle = theme.textTheme.labelSmall?.copyWith(
      fontWeight: FontWeight.w700,
      color: theme.colorScheme.onSurfaceVariant,
    );

    return async.when(
      loading: () => const ListTile(
        leading: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)),
        title: Text('Sync integrity'),
        subtitle: Text('Loading diagnostics…'),
      ),
      error: (e, _) => ListTile(
        leading: Icon(Icons.warning_amber_rounded, color: theme.colorScheme.error),
        title: const Text('Sync integrity'),
        subtitle: Text('$e'),
        trailing: IconButton(
          icon: const Icon(Icons.refresh_rounded),
          onPressed: () => ref.invalidate(syncIntegrityDiagnosticsProvider),
        ),
      ),
      data: (snap) {
        if (snap == null) {
          return const ListTile(
            title: Text('Sync integrity'),
            subtitle: Text('Sign in to a pharmacy to view sync diagnostics.'),
          );
        }
        final tenantShort = snap.tenantId.length > 8
            ? '${snap.tenantId.substring(0, 8)}…'
            : snap.tenantId;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ListTile(
              leading: Icon(Icons.cloud_sync_outlined, color: theme.colorScheme.primary),
              title: const Text('Sync integrity'),
              subtitle: Text(
                'Tenant $tenantShort · bootstrap ${snap.bootstrapReady ? 'ready' : 'pending'}',
              ),
              trailing: IconButton(
                icon: const Icon(Icons.refresh_rounded),
                tooltip: 'Refresh',
                onPressed: () {
                  ref.invalidate(syncIntegrityDiagnosticsProvider);
                  ref.invalidate(pharmacyWorkspaceBootstrapProvider);
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Table(
                columnWidths: const {
                  0: FlexColumnWidth(2),
                  1: FlexColumnWidth(1),
                  2: FlexColumnWidth(1),
                  3: FlexColumnWidth(1),
                },
                defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                children: [
                  TableRow(
                    children: [
                      Text('Metric', style: headerStyle),
                      Text('Cloud', style: headerStyle, textAlign: TextAlign.end),
                      Text('Disk', style: headerStyle, textAlign: TextAlign.end),
                      Text('Memory', style: headerStyle, textAlign: TextAlign.end),
                    ],
                  ),
                  _row(theme, 'Sales', snap.cloudSales, snap.localSales, snap.memorySales),
                  _row(theme, 'Purchases', snap.cloudPurchases, snap.localPurchases, snap.memoryPurchases),
                  _row(theme, 'Medicines', snap.cloudMedicines, snap.localMedicines, snap.memoryMedicines),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(
                'Last cloud pull: ${snap.lastPullIso ?? 'never'}\n'
                'Outbox pending: ${snap.pendingOutbox} · failed: ${snap.failedOutbox}',
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: OutlinedButton.icon(
                onPressed: () async {
                  await flushPharmacyWorkspacePersistence(ref, reason: 'settings_manual_flush');
                  ref.invalidate(syncIntegrityDiagnosticsProvider);
                },
                icon: const Icon(Icons.upload_rounded, size: 18),
                label: const Text('Flush workspace to cloud'),
              ),
            ),
          ],
        );
      },
    );
  }

  TableRow _row(ThemeData theme, String label, int cloud, int disk, int memory) {
    final mismatch = cloud != disk || disk != memory;
    return TableRow(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: mismatch ? theme.colorScheme.error : null,
            ),
          ),
        ),
        Text('$cloud', textAlign: TextAlign.end),
        Text('$disk', textAlign: TextAlign.end),
        Text('$memory', textAlign: TextAlign.end),
      ],
    );
  }
}
