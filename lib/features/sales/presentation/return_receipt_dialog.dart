import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/kpms_light_receipt_theme.dart';
import '../../../core/widgets/kpms_pharmacy_logo.dart';
import '../../settings/domain/pharmacy_branding.dart';
import '../domain/completed_sale_invoice.dart';
import '../domain/sale_invoice.dart';

Future<void> showReturnReceiptDialog(
  BuildContext context,
  SalesReturnRecord record,
  PharmacyBranding branding,
) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => Theme(
      data: kpmsLightReceiptHostTheme(ctx),
      child: Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: Material(
          color: AppColors.surfaceCard,
          elevation: 8,
          shadowColor: Colors.black26,
          borderRadius: BorderRadius.circular(20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420, maxHeight: 620),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(22, 22, 22, 12),
                    child: _ReturnReceiptBody(record: record, branding: branding),
                  ),
                ),
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: const Text('Close'),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class _ReturnReceiptBody extends StatelessWidget {
  const _ReturnReceiptBody({required this.record, required this.branding});

  final SalesReturnRecord record;
  final PharmacyBranding branding;

  static const _grey = AppColors.neutral;
  static const _divider = AppColors.outlineMuted;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = AppColors.primary;
    final dateStr = SaleInvoice.formatReceiptDate(record.issuedAt);
    final timeStr = SaleInvoice.formatReceiptTime(record.issuedAt);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: KpmsPharmacyLogo(
            imageUrl: branding.logoUrl,
            maxWidth: MediaQuery.sizeOf(context).width < 380 ? 80 : 104,
            maxHeight: MediaQuery.sizeOf(context).width < 380 ? 44 : 64,
            compact: MediaQuery.sizeOf(context).width < 380,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          branding.businessName,
          textAlign: TextAlign.center,
          style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
        ),
        if (branding.addressLine != '—')
          Text(
            branding.addressLine,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(color: _grey, height: 1.2),
          ),
        if (branding.phoneLine != '—')
          Text(
            branding.phoneLine,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(color: _grey, height: 1.2),
          ),
        const SizedBox(height: 10),
        Row(
          children: [
            Icon(Icons.assignment_return_rounded, color: accent, size: 36),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Return receipt',
                style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Divider(color: _divider.withValues(alpha: 0.9), height: 1),
        const SizedBox(height: 12),
        _pair(theme, 'Return #', record.returnInvoiceNumber, emphasize: true),
        const SizedBox(height: 6),
        _pair(theme, 'Original invoice', record.originalInvoiceNumber),
        const SizedBox(height: 6),
        _pair(theme, 'Date', '$dateStr · $timeStr'),
        _pair(theme, 'Cashier', record.cashierName),
        _pair(theme, 'Reason', record.reason.label),
        if (record.notes.isNotEmpty) _pair(theme, 'Notes', record.notes),
        const SizedBox(height: 14),
        Text(
          'Returned items',
          style: theme.textTheme.labelSmall?.copyWith(
            fontWeight: FontWeight.w800,
            color: _grey,
          ),
        ),
        const SizedBox(height: 8),
        Divider(color: _divider.withValues(alpha: 0.9), height: 1),
        const SizedBox(height: 8),
        ...record.lines.map((l) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    l.name,
                    style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
                Text(
                  '×${l.quantity}',
                  style: theme.textTheme.bodyMedium?.copyWith(color: _grey),
                ),
                const SizedBox(width: 12),
                Text(
                  '\$${l.lineRefund.toStringAsFixed(2)}',
                  style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
              ],
            ),
          );
        }),
        const SizedBox(height: 8),
        Divider(color: _divider.withValues(alpha: 0.9), height: 1),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Refund total', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
            Text(
              '\$${record.refundTotal.toStringAsFixed(2)}',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w900,
                color: accent,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          'Profit adjustment −\$${record.profitReduction.toStringAsFixed(2)}',
          style: theme.textTheme.bodySmall?.copyWith(color: _grey),
        ),
        const SizedBox(height: 20),
        Center(
          child: Text(
            'Stock restored · ledger updated',
            textAlign: TextAlign.center,
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: _grey,
            ),
          ),
        ),
      ],
    );
  }

  Widget _pair(ThemeData theme, String k, String v, {bool emphasize = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 128,
            child: Text(k, style: theme.textTheme.bodySmall?.copyWith(color: _grey)),
          ),
          Expanded(
            child: Text(
              v,
              style: emphasize
                  ? theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w900)
                  : theme.textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}
