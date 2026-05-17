import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/kpms_feedback.dart';
import '../../purchases/application/purchase_ledger_notifier.dart';
import '../../purchases/presentation/purchase_invoice_dialog.dart';
import '../../sales/application/sales_ledger_notifier.dart';
import '../../sales/data/sale_invoice_from_completed.dart';
import '../../sales/presentation/pharmacy_invoice_dialog.dart';
import '../../settings/application/pharmacy_settings_providers.dart';
import '../application/transaction_export_service.dart';
import '../domain/ledger_tx_view.dart';

/// Bottom sheet: view receipt (when available), share PDF, close.
Future<void> showLedgerTransactionActions(
  BuildContext context,
  WidgetRef ref,
  LedgerTxView row,
) async {
  final branding = ref.read(pharmacyBrandingProvider);
  final theme = Theme.of(context);

  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (ctx) {
      return SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(20, 8, 20, 16 + MediaQuery.paddingOf(ctx).bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                row.reference,
                style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              Text(
                '${row.kindLabel} · ${row.whenLabel}',
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 16),
              switch (row.kind) {
                LedgerTxKind.sale => FilledButton.icon(
                    onPressed: () async {
                      final inv = ref.read(salesLedgerProvider.notifier).invoiceByNumber(row.reference);
                      if (inv == null) {
                        if (context.mounted) {
                          kpmsSnack(context, 'This receipt is no longer available.', isError: true);
                        }
                        return;
                      }
                      final saleInv = saleInvoiceFromCompleted(ledger: inv, branding: branding);
                      Navigator.of(ctx).pop();
                      await Future<void>.delayed(Duration.zero);
                      if (!context.mounted) return;
                      await showPharmacyInvoiceDialog(context, saleInv);
                    },
                    icon: const Icon(Icons.receipt_long_outlined),
                    label: const Text('View receipt'),
                  ),
                LedgerTxKind.purchase => FilledButton.icon(
                    onPressed: () async {
                      final inv = ref.read(purchaseLedgerProvider.notifier).invoiceByNumber(row.reference);
                      if (inv == null) {
                        if (context.mounted) {
                          kpmsSnack(context, 'This invoice is no longer available.', isError: true);
                        }
                        return;
                      }
                      Navigator.of(ctx).pop();
                      await Future<void>.delayed(Duration.zero);
                      if (!context.mounted) return;
                      await showPurchaseInvoiceDialog(context, inv);
                    },
                    icon: const Icon(Icons.inventory_2_outlined),
                    label: const Text('View purchase invoice'),
                  ),
                LedgerTxKind.saleReturn => OutlinedButton.icon(
                    onPressed: () {
                      final r = ref.read(salesLedgerProvider.notifier).returnByNumber(row.reference);
                      if (r == null) {
                        if (context.mounted) {
                          kpmsSnack(context, 'Return details are not available.', isError: true);
                        }
                        return;
                      }
                      Navigator.of(ctx).pop();
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (!context.mounted) return;
                        _showReturnDetailDialog(
                          context,
                          title: 'Sale return',
                          lines: [
                            for (final l in r.lines) '${l.name} × ${l.quantity}  (\$${l.lineRefund.toStringAsFixed(2)})',
                          ],
                          footer: 'Refund total: \$${r.refundTotal.toStringAsFixed(2)}',
                        );
                      });
                    },
                    icon: const Icon(Icons.undo_outlined),
                    label: const Text('View return details'),
                  ),
                LedgerTxKind.purchaseReturn => OutlinedButton.icon(
                    onPressed: () {
                      final r = ref.read(purchaseLedgerProvider.notifier).purchaseReturnByNumber(row.reference);
                      if (r == null) {
                        if (context.mounted) {
                          kpmsSnack(context, 'Return details are not available.', isError: true);
                        }
                        return;
                      }
                      Navigator.of(ctx).pop();
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (!context.mounted) return;
                        _showReturnDetailDialog(
                          context,
                          title: 'Purchase return',
                          lines: [
                            for (final l in r.lines)
                              '${l.medicineName} × ${l.quantity}  (\$${l.lineCredit.toStringAsFixed(2)})',
                          ],
                          footer: 'Credit at cost: \$${r.totalCreditAtCost.toStringAsFixed(2)}',
                        );
                      });
                    },
                    icon: const Icon(Icons.assignment_return_outlined),
                    label: const Text('View return details'),
                  ),
              },
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () async {
                  try {
                    await TransactionExportService.exportSingleRowPdf(
                      row,
                      pharmacyName: branding.businessName,
                      logoUrl: branding.logoUrl,
                    );
                    if (context.mounted) {
                      Navigator.of(ctx).pop();
                      kpmsSnackSuccess(context, 'PDF ready to share');
                    }
                  } catch (e) {
                    if (context.mounted) kpmsSnackError(context, e);
                  }
                },
                icon: const Icon(Icons.picture_as_pdf_outlined),
                label: const Text('Share PDF summary'),
              ),
            ],
          ),
        ),
      );
    },
  );
}

void _showReturnDetailDialog(
  BuildContext context, {
  required String title,
  required List<String> lines,
  required String footer,
}) {
  showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final line in lines) Padding(padding: const EdgeInsets.only(bottom: 6), child: Text(line)),
            const SizedBox(height: 8),
            Text(footer, style: Theme.of(ctx).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
          ],
        ),
      ),
      actions: [
        FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
      ],
    ),
  );
}
