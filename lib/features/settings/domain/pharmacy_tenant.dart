import 'dart:convert';

import 'package:flutter/foundation.dart';

/// Row from `public.tenants` plus parsed sales/receipt options from [settings] JSON.
@immutable
class PharmacyTenant {
  const PharmacyTenant({
    required this.id,
    required this.name,
    this.address,
    this.phone,
    this.licenseNumber,
    this.ownerName,
    required this.settingsJson,
  });

  final String id;
  final String name;
  final String? address;
  final String? phone;
  final String? licenseNumber;
  final String? ownerName;

  /// Raw `tenants.settings` JSON (tax, invoice footer, QR, etc.).
  final Map<String, dynamic> settingsJson;

  factory PharmacyTenant.fromRow(Map<String, dynamic> row) {
    final raw = row['settings'];
    Map<String, dynamic> settings = {};
    if (raw is Map<String, dynamic>) {
      settings = raw;
    } else if (raw is String && raw.trim().isNotEmpty) {
      try {
        final d = jsonDecode(raw);
        if (d is Map<String, dynamic>) settings = d;
      } catch (_) {}
    }

    return PharmacyTenant(
      id: '${row['id']}',
      name: '${row['name'] ?? ''}'.trim().isEmpty ? 'Pharmacy' : '${row['name']}'.trim(),
      address: _trimmed(row['address']),
      phone: _trimmed(row['phone']),
      licenseNumber: _trimmed(row['license_number']),
      ownerName: _trimmed(row['owner_name']),
      settingsJson: settings,
    );
  }

  static String? _trimmed(dynamic v) {
    if (v == null) return null;
    final s = '$v'.trim();
    return s.isEmpty ? null : s;
  }

  /// Tax applied on taxable amount at checkout (e.g. 0.05 = 5%).
  double get taxRateFraction {
    final v = settingsJson['tax_rate_percent'];
    if (v is num) return (v.toDouble() / 100).clamp(0.0, 1.0);
    return 0.05;
  }

  String? get invoiceFooter {
    final v = settingsJson['invoice_footer'];
    if (v == null) return null;
    final s = '$v'.trim();
    return s.isEmpty ? null : s;
  }

  bool get showInvoiceQr => settingsJson['show_invoice_qr'] != false;

  String? get contactEmail {
    final v = settingsJson['contact_email'];
    if (v == null) return null;
    final s = '$v'.trim();
    return s.isEmpty ? null : s;
  }

  String get currencyCode {
    final v = settingsJson['currency_code'];
    if (v == null) return 'USD';
    final s = '$v'.trim();
    return s.isEmpty ? 'USD' : s.toUpperCase();
  }

  String get timezoneId {
    final v = settingsJson['timezone_id'];
    if (v == null) return 'UTC';
    final s = '$v'.trim();
    return s.isEmpty ? 'UTC' : s;
  }

  String get regionCode {
    final v = settingsJson['region_code'];
    if (v == null) return 'device';
    final s = '$v'.trim();
    return s.isEmpty ? 'device' : s;
  }

  String get dateFormatId {
    final v = settingsJson['date_format'];
    if (v == null) return 'system';
    final s = '$v'.trim();
    return s.isEmpty ? 'system' : s;
  }

  String get numberFormatId {
    final v = settingsJson['number_format'];
    if (v == null) return 'system';
    final s = '$v'.trim();
    return s.isEmpty ? 'system' : s;
  }

  double get defaultProfitMarginPercent {
    final v = settingsJson['default_profit_margin_percent'];
    if (v is num) return v.toDouble().clamp(0, 99.99);
    return 0;
  }

  int get priceDecimalPlaces {
    final v = settingsJson['price_decimal_places'];
    if (v is int) return v.clamp(0, 6);
    if (v is num) return v.toInt().clamp(0, 6);
    return 2;
  }

  String get discountBehavior {
    final v = settingsJson['discount_behavior'];
    final s = v == null ? 'line' : '$v'.trim();
    return s == 'total' ? 'total' : 'line';
  }

  bool get taxInclusiveDisplay => settingsJson['tax_inclusive'] == true;

  bool get notifLowStock => settingsJson['notif_low_stock'] != false;

  bool get notifExpiry => settingsJson['notif_expiry'] != false;

  bool get notifDebt => settingsJson['notif_debt'] != false;

  bool get notifSound => settingsJson['notif_sound'] != false;

  bool get notifVibrate => settingsJson['notif_vibrate'] != false;

  String get receiptPaperSize {
    final v = settingsJson['receipt_paper_size'];
    final s = v == null ? 'default' : '$v'.trim();
    return s.isEmpty ? 'default' : s;
  }

  String get receiptPrintQuality {
    final v = settingsJson['receipt_print_quality'];
    final s = v == null ? 'normal' : '$v'.trim();
    return s.isEmpty ? 'normal' : s;
  }

  String? get logoUrl {
    final v = settingsJson['logo_url'];
    if (v == null) return null;
    final s = '$v'.trim();
    return s.isEmpty ? null : s;
  }

  /// Top-level merge into [settingsJson]. Use `null` values in [patch] to remove keys.
  Map<String, dynamic> mergeSettingsJson(Map<String, Object?> patch) {
    final m = Map<String, dynamic>.from(settingsJson);
    for (final e in patch.entries) {
      if (e.value == null) {
        m.remove(e.key);
      } else {
        m[e.key] = e.value;
      }
    }
    return m;
  }

  Map<String, dynamic> copySettingsJsonWith({
    double? taxRatePercent,
    bool? taxInclusive,
    String? invoiceFooterText,
    bool? showInvoiceQr,
  }) {
    final m = Map<String, dynamic>.from(settingsJson);
    if (taxRatePercent != null) m['tax_rate_percent'] = taxRatePercent;
    if (taxInclusive != null) m['tax_inclusive'] = taxInclusive;
    if (invoiceFooterText != null) {
      final t = invoiceFooterText.trim();
      if (t.isEmpty) {
        m.remove('invoice_footer');
      } else {
        m['invoice_footer'] = t;
      }
    }
    if (showInvoiceQr != null) m['show_invoice_qr'] = showInvoiceQr;
    return m;
  }

  Map<String, dynamic> toUpdatePayload({
    required String name,
    String? address,
    String? phone,
    String? licenseNumber,
    String? ownerName,
    Map<String, dynamic>? settingsOverride,
  }) {
    return <String, dynamic>{
      'name': name.trim(),
      'address': address?.trim(),
      'phone': phone?.trim(),
      'license_number': licenseNumber?.trim(),
      'owner_name': ownerName?.trim(),
      'settings': settingsOverride ?? settingsJson,
    };
  }
}
