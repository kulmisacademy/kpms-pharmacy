import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_routes.dart';
import '../../../core/navigation/kpms_breakpoints.dart';
import '../../../core/utils/kpms_feedback.dart';
import '../../../core/widgets/kpms_empty_state.dart';
import '../../../core/widgets/kpms_page_shell.dart';
import '../../medicines/data/medicine_catalog_notifier.dart';
import '../../medicines/presentation/widgets/medicine_manage_actions.dart';
import '../../../core/auth/kpms_inventory_permission_provider.dart';
import '../../../core/responsive/responsive_helpers.dart';

/// PRD §5.6 — Inventory (stock, adjustments, expiry, damaged).
class InventoryScreen extends ConsumerStatefulWidget {
  const InventoryScreen({super.key});

  @override
  ConsumerState<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends ConsumerState<InventoryScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return KpmsPageShell(
      title: 'Inventory',
      subtitle: 'Tracking · alerts · history',
      actions: [
        IconButton(
          tooltip: 'Export',
          onPressed: () => kpmsSnack(context, 'Connect reporting storage to export inventory.'),
          icon: const Icon(Icons.download_outlined),
        ),
      ],
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Material(
            color: theme.cardColor,
            child: TabBar(
              controller: _tabs,
              tabs: const [
                Tab(text: 'Stock levels'),
                Tab(text: 'Adjustments'),
                Tab(text: 'Damaged'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: [
                _StockPanel(theme: theme),
                _ComingSoonPanel(
                  theme: theme,
                  title: 'Adjustments',
                  message: 'Reason-coded stock corrections will appear here once connected to your ledger.',
                ),
                _ComingSoonPanel(
                  theme: theme,
                  title: 'Damaged goods',
                  message: 'Quarantine and write-off workflows will be available in a future release.',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StockPanel extends ConsumerWidget {
  const _StockPanel({required this.theme});

  final ThemeData theme;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final meds = ref.watch(medicineCatalogProvider);
    final canManage = ref.watch(kpmsCanManageInventoryProvider);
    final compactActions = isMobile(context);
    if (meds.isEmpty) {
      return KpmsEmptyState(
        icon: Icons.inventory_2_outlined,
        title: 'No stock records yet',
        message: 'Add medicines to the catalog to track quantities, shelves, and alerts.',
        actionLabel: 'Medicines',
        onAction: () => context.push(AppRoutes.medicines),
      );
    }

    return ListView.separated(
      padding: KpmsBreakpoints.pageScrollPadding(context),
      itemCount: meds.length,
      separatorBuilder: (context, index) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        final m = meds[i];
        final alert = m.isLowStock;
        return Card(
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: alert ? const Color(0xFFF59E0B).withValues(alpha: 0.15) : theme.colorScheme.primaryContainer,
              child: Icon(Icons.inventory_2_outlined, color: alert ? const Color(0xFFB45309) : theme.colorScheme.primary),
            ),
            title: Text(m.name),
            subtitle: const Text('Shelf / bin — assign in settings'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('${m.quantity}', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
                    Text(
                      alert ? 'Low' : 'OK',
                      style: theme.textTheme.labelSmall?.copyWith(color: alert ? const Color(0xFFB45309) : theme.hintColor),
                    ),
                  ],
                ),
                if (canManage) ...[
                  const SizedBox(width: 4),
                  MedicineManageActions(medicine: m, compact: compactActions),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ComingSoonPanel extends StatelessWidget {
  const _ComingSoonPanel({required this.theme, required this.title, required this.message});

  final ThemeData theme;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.construction_outlined, size: 48, color: theme.hintColor),
            const SizedBox(height: 16),
            Text(title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(color: theme.hintColor, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}
