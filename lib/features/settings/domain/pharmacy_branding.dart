import 'package:flutter/foundation.dart';

import '../../../core/constants/receipt_branding.dart';
import 'pharmacy_tenant.dart';

/// Receipt / invoice labels resolved from [PharmacyTenant] with safe defaults.
@immutable
class PharmacyBranding {
  const PharmacyBranding({
    required this.businessName,
    required this.addressLine,
    required this.phoneLine,
    required this.taxRateFraction,
    this.receiptFooter,
    this.showReceiptQr = true,
    this.cashierLabel,
    this.logoUrl,
  });

  final String businessName;
  final String addressLine;
  final String phoneLine;
  final double taxRateFraction;
  final String? receiptFooter;
  final bool showReceiptQr;
  final String? cashierLabel;

  /// Public URL from `tenants.settings.logo_url` (Supabase Storage).
  final String? logoUrl;

  static PharmacyBranding fromTenantAndProfile({
    PharmacyTenant? tenant,
    String? profileFullName,
  }) {
    final t = tenant;
    if (t == null) {
      return PharmacyBranding(
        businessName: KpmsReceiptBranding.businessName,
        addressLine: KpmsReceiptBranding.address,
        phoneLine: KpmsReceiptBranding.phone,
        taxRateFraction: 0.05,
        receiptFooter: null,
        showReceiptQr: true,
        cashierLabel: profileFullName ?? KpmsReceiptBranding.defaultCashier,
        logoUrl: null,
      );
    }

    final cashier = () {
      final n = profileFullName?.trim();
      if (n != null && n.isNotEmpty) return n;
      return KpmsReceiptBranding.defaultCashier;
    }();

    return PharmacyBranding(
      businessName: t.name,
      addressLine: t.address ?? '—',
      phoneLine: t.phone ?? '—',
      taxRateFraction: t.taxRateFraction,
      receiptFooter: t.invoiceFooter,
      showReceiptQr: t.showInvoiceQr,
      cashierLabel: cashier,
      logoUrl: t.logoUrl,
    );
  }
}
