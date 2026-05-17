import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/kpms_light_receipt_theme.dart';
import '../../../core/widgets/kpms_pharmacy_logo.dart';
import '../../medicines/data/medicine_catalog_notifier.dart';
import '../../medicines/domain/medicine.dart';
import '../../settings/application/pharmacy_settings_providers.dart';
import '../domain/purchase_invoice.dart';

Future<void> showPurchaseInvoiceDialog(BuildContext context, PurchaseInvoice invoice) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) {
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
              constraints: const BoxConstraints(maxWidth: 440, maxHeight: 720),
              child: Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                      child: _PurchaseInvoiceBody(invoice: invoice),
                    ),
                  ),
                  Divider(height: 1, color: AppColors.outlineMuted.withValues(alpha: 0.9)),
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      16,
                      12,
                      16,
                      16 + MediaQuery.paddingOf(ctx).bottom,
                    ),
                    child: SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
      );
    },
  );
}

class _PurchaseInvoiceBody extends ConsumerWidget {
  const _PurchaseInvoiceBody({required this.invoice});

  final PurchaseInvoice invoice;

  static const _divider = AppColors.outlineMuted;

  Medicine? _medicineById(WidgetRef ref, String id) {
    for (final m in ref.watch(medicineCatalogProvider)) {
      if (m.id == id) return m;
    }
    return null;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final onSurface = scheme.onSurface;
    final muted = onSurface.withValues(alpha: 0.62);
    final branding = ref.watch(pharmacyBrandingProvider);
    final narrow = MediaQuery.sizeOf(context).width < 380;

    final accent = AppColors.primary;
    final d = invoice.issuedAt;
    final dateStr = '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    final timeStr = '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

    TextStyle labelSmallCaps() => theme.textTheme.labelSmall!.copyWith(
          fontWeight: FontWeight.w800,
          letterSpacing: 0.6,
          color: muted,
          fontSize: 11,
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            KpmsPharmacyLogo(
              imageUrl: branding.logoUrl,
              maxWidth: narrow ? 64 : 88,
              maxHeight: narrow ? 40 : 56,
              compact: narrow,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Purchase invoice',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    branding.businessName,
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: muted,
                    ),
                  ),
                  if (branding.addressLine.trim().isNotEmpty && branding.addressLine != '—')
                    Text(
                      branding.addressLine,
                      style: theme.textTheme.bodySmall?.copyWith(color: muted, height: 1.25),
                    ),
                  if (branding.phoneLine.trim().isNotEmpty && branding.phoneLine != '—')
                    Text(
                      branding.phoneLine,
                      style: theme.textTheme.bodySmall?.copyWith(color: muted, height: 1.25),
                    ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Divider(color: _divider.withValues(alpha: 0.95), height: 1),
        const SizedBox(height: 12),
        _pair(theme, onSurface, muted, 'Invoice #', invoice.invoiceNumber, strong: true),
        _pair(theme, onSurface, muted, 'Supplier', invoice.supplierName),
        _pair(theme, onSurface, muted, 'Supplier phone', invoice.supplierPhone),
        _pair(theme, onSurface, muted, 'Address', invoice.supplierAddress),
        _pair(theme, onSurface, muted, 'Date', '$dateStr · $timeStr'),
        _pair(theme, onSurface, muted, 'Payment status', invoice.paymentStatusLabel),
        _pair(theme, onSurface, muted, 'Payment type', invoice.paymentTypeLabel),
        _pair(theme, onSurface, muted, 'Payment method', invoice.paymentMethod),
        _pair(theme, onSurface, muted, 'Cashier / Admin', invoice.cashierName),
        if (invoice.notes.isNotEmpty) _pair(theme, onSurface, muted, 'Notes', invoice.notes),
        const SizedBox(height: 16),
        Text('LINE ITEMS', style: labelSmallCaps()),
        const SizedBox(height: 8),
        DecoratedBox(
          decoration: BoxDecoration(
            color: scheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _divider.withValues(alpha: 0.85)),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(11),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  child: Row(
                    children: [
                      const SizedBox(width: 36),
                      Expanded(
                        flex: 5,
                        child: Text('ITEM', style: labelSmallCaps()),
                      ),
                      SizedBox(
                        width: 36,
                        child: Text('QTY', textAlign: TextAlign.center, style: labelSmallCaps()),
                      ),
                      SizedBox(
                        width: 64,
                        child: Text('UNIT', textAlign: TextAlign.right, style: labelSmallCaps()),
                      ),
                      SizedBox(
                        width: 76,
                        child: Text('AMOUNT', textAlign: TextAlign.right, style: labelSmallCaps()),
                      ),
                    ],
                  ),
                ),
                Divider(height: 1, color: scheme.outline.withValues(alpha: 0.12)),
                ...(() {
                  final rows = <Widget>[];
                  for (var i = 0; i < invoice.lines.length; i++) {
                    final l = invoice.lines[i];
                    final med = _medicineById(ref, l.medicineId);
                    rows.add(_InvoiceLineRow(line: l, medicine: med, onSurface: onSurface, muted: muted));
                    if (i < invoice.lines.length - 1) {
                      rows.add(Divider(height: 1, indent: 12, endIndent: 12, color: scheme.outline.withValues(alpha: 0.08)));
                    }
                  }
                  return rows;
                })(),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        DecoratedBox(
          decoration: BoxDecoration(
            border: Border.all(color: _divider.withValues(alpha: 0.85)),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'SUMMARY',
                  style: labelSmallCaps(),
                ),
                const SizedBox(height: 12),
                _moneyRow(theme, onSurface, muted, 'Subtotal', invoice.subtotal),
                _moneyRow(theme, onSurface, muted, 'Discount', -invoice.discount, mutedRow: true),
                if (invoice.taxRate > 0)
                  _moneyRow(theme, onSurface, muted, 'Tax (${(invoice.taxRate * 100).toStringAsFixed(0)}%)',
                      invoice.taxAmount),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Grand total',
                      style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900, color: onSurface),
                    ),
                    Text(
                      '\$${invoice.grandTotal.toStringAsFixed(2)}',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                        color: accent,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                _moneyRow(theme, onSurface, muted, 'Paid amount', invoice.paidAmount),
                _moneyRow(theme, onSurface, muted, 'Remaining balance', invoice.remainingBalance,
                    warn: invoice.remainingBalance > 0.009),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        Center(
          child: Text(
            'Thank you — stock updated',
            style: theme.textTheme.labelMedium?.copyWith(color: muted, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }

  Widget _pair(
    ThemeData theme,
    Color onSurface,
    Color muted,
    String k,
    String v, {
    bool strong = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 116,
            child: Text(
              k,
              style: theme.textTheme.bodySmall?.copyWith(color: muted, fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(
            child: Text(
              v,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: strong ? FontWeight.w900 : FontWeight.w600,
                color: onSurface,
                height: 1.25,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _moneyRow(
    ThemeData theme,
    Color onSurface,
    Color muted,
    String label,
    double value, {
    bool mutedRow = false,
    bool warn = false,
  }) {
    final c = warn ? Colors.orange.shade900 : (mutedRow ? muted : onSurface);
    final display = value < 0 ? '-\$${(-value).toStringAsFixed(2)}' : '\$${value.toStringAsFixed(2)}';
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(color: mutedRow ? muted : onSurface.withValues(alpha: 0.75)),
          ),
          Text(
            display,
            style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w800, color: c),
          ),
        ],
      ),
    );
  }
}

class _InvoiceLineRow extends StatelessWidget {
  const _InvoiceLineRow({
    required this.line,
    required this.medicine,
    required this.onSurface,
    required this.muted,
  });

  final PurchaseInvoiceLine line;
  final Medicine? medicine;
  final Color onSurface;
  final Color muted;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final exp = line.expiryDate;
    final expStr = exp == null
        ? '—'
        : '${exp.year}-${exp.month.toString().padLeft(2, '0')}-${exp.day.toString().padLeft(2, '0')}';

    final thumbBg = scheme.surfaceContainerHighest.withValues(alpha: 0.85);

    Widget thumb = ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        width: 36,
        height: 36,
        child: medicine?.imageBytes != null
            ? Image.memory(medicine!.imageBytes!, fit: BoxFit.cover)
            : ColoredBox(
                color: thumbBg,
                child: Icon(Icons.medication_liquid_rounded, size: 20, color: muted),
              ),
      ),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          thumb,
          const SizedBox(width: 8),
          Expanded(
            flex: 5,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  line.name,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: onSurface,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${line.typeLabel} · Exp $expStr',
                  style: theme.textTheme.labelSmall?.copyWith(color: muted, height: 1.35),
                ),
              ],
            ),
          ),
          SizedBox(
            width: 36,
            child: Text(
              '${line.quantity}',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700, color: onSurface),
            ),
          ),
          SizedBox(
            width: 64,
            child: Text(
              '\$${line.buyingPrice.toStringAsFixed(2)}',
              textAlign: TextAlign.right,
              style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600, color: onSurface),
            ),
          ),
          SizedBox(
            width: 76,
            child: Text(
              '\$${line.lineTotal.toStringAsFixed(2)}',
              textAlign: TextAlign.right,
              style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w900, color: onSurface),
            ),
          ),
        ],
      ),
    );
  }
}
