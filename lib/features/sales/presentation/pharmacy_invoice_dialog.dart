import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/kpms_light_receipt_theme.dart';
import '../../../core/widgets/kpms_pharmacy_logo.dart';
import '../domain/sale_invoice.dart';

/// Full sale invoice / receipt matching pharmacy POS branding.
Future<void> showPharmacyInvoiceDialog(BuildContext context, SaleInvoice invoice) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) {
      final maxBody = MediaQuery.sizeOf(ctx).height * 0.68;
      return Theme(
        data: kpmsLightReceiptHostTheme(ctx),
        child: Dialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: Material(
            color: AppColors.surfaceCard,
            elevation: 8,
            shadowColor: Colors.black26,
            borderRadius: BorderRadius.circular(16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ConstrainedBox(
                    constraints: BoxConstraints(maxHeight: maxBody),
                    child: ListView(
                      shrinkWrap: true,
                      physics: const ClampingScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
                      children: [
                        _PharmacyInvoiceBody(invoice: invoice),
                      ],
                    ),
                  ),
                  Divider(height: 1, color: AppColors.outlineMuted.withValues(alpha: 0.9)),
                  Padding(
                    padding: EdgeInsets.fromLTRB(16, 12, 16, 16 + MediaQuery.paddingOf(ctx).bottom),
                    child: SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('Done'),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}

class _PharmacyInvoiceBody extends StatelessWidget {
  const _PharmacyInvoiceBody({required this.invoice});

  final SaleInvoice invoice;

  static const _grey = AppColors.neutral;
  static const _divider = AppColors.outlineMuted;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = AppColors.primary;
    final dateStr = SaleInvoice.formatReceiptDate(invoice.issuedAt);
    final timeStr = SaleInvoice.formatReceiptTime(invoice.issuedAt);
    final taxPct = (invoice.taxRate * 100).round();

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: KpmsPharmacyLogo(
            imageUrl: invoice.logoUrl,
            maxWidth: MediaQuery.sizeOf(context).width < 380 ? 88 : 120,
            maxHeight: MediaQuery.sizeOf(context).width < 380 ? 48 : 72,
            compact: MediaQuery.sizeOf(context).width < 380,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          invoice.pharmacyName,
          textAlign: TextAlign.center,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w900,
            letterSpacing: 0.6,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          invoice.addressLine,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall?.copyWith(color: _grey),
        ),
        Text(
          invoice.phoneLine,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall?.copyWith(color: _grey),
        ),
        const SizedBox(height: 16),
        Divider(color: _divider.withValues(alpha: 0.9), height: 1),
        const SizedBox(height: 14),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  RichText(
                    text: TextSpan(
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
                        fontWeight: FontWeight.w600,
                      ),
                      children: [
                        const TextSpan(text: 'Invoice #: '),
                        TextSpan(
                          text: invoice.invoiceNumber,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w900,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text('Date: $dateStr', style: theme.textTheme.bodySmall?.copyWith(color: _grey)),
                ],
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('Time: $timeStr', style: theme.textTheme.bodySmall?.copyWith(color: _grey)),
                  const SizedBox(height: 8),
                  Text(
                    'Cashier: ${invoice.cashierLabel}',
                    style: theme.textTheme.bodySmall?.copyWith(color: _grey),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        DecoratedBox(
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  invoice.customerName,
                  style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
                if (invoice.customerPhone.trim().isNotEmpty && invoice.customerPhone != '—')
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      invoice.customerPhone,
                      style: theme.textTheme.bodySmall?.copyWith(color: _grey),
                    ),
                  ),
                const SizedBox(height: 6),
                Text(
                  'Payment · ${invoice.paymentMethod}',
                  style: theme.textTheme.labelMedium?.copyWith(color: _grey, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        DecoratedBox(
          decoration: BoxDecoration(
            border: Border.all(color: _divider.withValues(alpha: 0.85)),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                child: Row(
                  children: [
                    Expanded(
                      flex: 5,
                      child: Text(
                        'ITEM',
                        style: theme.textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: _grey,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        'QTY',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: _grey,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 3,
                      child: Text(
                        'AMOUNT',
                        textAlign: TextAlign.right,
                        style: theme.textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: _grey,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: theme.colorScheme.outline.withValues(alpha: 0.12)),
              ...invoice.lines.asMap().entries.map((e) {
                final line = e.value;
                final isLast = e.key == invoice.lines.length - 1;
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: EdgeInsets.fromLTRB(10, isLast ? 8 : 6, 10, isLast ? 8 : 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 5,
                            child: Text(
                              line.itemName,
                              style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              '${line.quantity}',
                              textAlign: TextAlign.center,
                              style: theme.textTheme.bodyMedium,
                            ),
                          ),
                          Expanded(
                            flex: 3,
                            child: Text(
                              '\$${line.amount.toStringAsFixed(2)}',
                              textAlign: TextAlign.right,
                              style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (!isLast)
                      Divider(
                        height: 1,
                        indent: 10,
                        endIndent: 10,
                        color: theme.colorScheme.outline.withValues(alpha: 0.08),
                      ),
                  ],
                );
              }),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _moneyRow(theme, 'Subtotal', invoice.subtotal, grey: true),
        const SizedBox(height: 8),
        _moneyRow(theme, 'Tax ($taxPct%)', invoice.taxAmount, grey: true),
        const SizedBox(height: 8),
        _moneyRow(
          theme,
          invoice.discountLabel,
          -invoice.discountAmount,
          accentPurple: invoice.discountAmount > 0.009,
        ),
        const SizedBox(height: 12),
        Divider(color: _divider.withValues(alpha: 0.9), height: 1),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              'Total',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
            ),
            Text(
              '\$${invoice.total.toStringAsFixed(2)}',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w900,
                color: accent,
                letterSpacing: -0.5,
              ),
            ),
          ],
        ),
        if (invoice.paidTowardBill != null) ...[
          const SizedBox(height: 10),
          _moneyRow(theme, 'Paid now', invoice.paidTowardBill!, grey: true),
          if (invoice.balanceDueAfterSale != null && invoice.balanceDueAfterSale! > 0.009)
            _moneyRow(theme, 'Balance due', invoice.balanceDueAfterSale!, warn: true),
          if (invoice.creditStatusLabel != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                invoice.creditStatusLabel!,
                style: theme.textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: _grey,
                ),
              ),
            ),
        ],
        const SizedBox(height: 22),
        if (invoice.receiptFooter != null && invoice.receiptFooter!.trim().isNotEmpty) ...[
          Text(
            invoice.receiptFooter!.trim(),
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: _grey,
              height: 1.35,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 14),
        ],
        Text(
          'Thank you for your business!',
          textAlign: TextAlign.center,
          style: theme.textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w800,
            color: _grey,
          ),
        ),
        if (invoice.showReceiptQr) ...[
          const SizedBox(height: 14),
          DecoratedBox(
            decoration: BoxDecoration(
              color: _divider.withValues(alpha: 0.45),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
              child: SizedBox(
                height: 40,
                child: _InvoiceBarcode(seed: invoice.invoiceNumber),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _moneyRow(
    ThemeData theme,
    String label,
    double value, {
    bool grey = false,
    bool accentPurple = false,
    bool warn = false,
  }) {
    final emphasis = AppColors.primary;
    final color = warn ? Colors.orange.shade900 : (accentPurple ? emphasis : (grey ? _grey : null));
    final display = value < -0.009
        ? '-\$${(-value).toStringAsFixed(2)}'
        : '\$${value.toStringAsFixed(2)}';

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: color,
            fontWeight: accentPurple ? FontWeight.w700 : null,
          ),
        ),
        Text(
          display,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: color,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _InvoiceBarcode extends StatelessWidget {
  const _InvoiceBarcode({required this.seed});

  final String seed;

  @override
  Widget build(BuildContext context) {
    final hash = seed.hashCode.abs();
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: List.generate(52, (i) {
        final w = 1.0 + ((hash >> (i % 19)) + i * 7) % 3;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 0.35),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.82),
              borderRadius: BorderRadius.circular(0.5),
            ),
            child: SizedBox(width: w),
          ),
        );
      }),
    );
  }
}
