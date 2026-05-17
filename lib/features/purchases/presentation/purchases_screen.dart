import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_routes.dart';
import '../../../core/navigation/kpms_breakpoints.dart';
import '../../../core/widgets/kpms_mobile_bottom_nav.dart';
import '../../../core/widgets/kpms_page_shell.dart';
import 'purchase_create_tab.dart';
import 'purchase_history_tab.dart';

/// Purchases — receiving invoices, history, supplier balances (wired to backend next).
class PurchasesScreen extends ConsumerWidget {
  const PurchasesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final width = MediaQuery.sizeOf(context).width;
    final pad = KpmsBreakpoints.pagePaddingHorizontal(width);
    final clearance =
        KpmsMobileBottomNav.scrollClearanceBottom(context) + MediaQuery.viewInsetsOf(context).bottom;

    return DefaultTabController(
      length: 2,
      child: KpmsPageShell(
        title: 'Purchases',
        subtitle: 'Receiving · supplier invoices · stock',
        constrainContentWidth: false,
        actions: [
          IconButton(
            tooltip: 'Purchase returns',
            onPressed: () => context.push(AppRoutes.purchaseReturns),
            icon: const Icon(Icons.keyboard_return_outlined),
          ),
        ],
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Material(
              color: Theme.of(context).colorScheme.surface,
              child: TabBar(
                labelStyle: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800),
                tabs: const [
                  Tab(text: 'New purchase'),
                  Tab(text: 'History'),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: EdgeInsets.fromLTRB(pad, 12, pad, 0),
                child: TabBarView(
                  children: [
                    PurchaseCreateTab(bottomInset: clearance),
                    PurchaseHistoryTab(bottomInset: clearance),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
