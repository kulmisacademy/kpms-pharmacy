import 'package:flutter/material.dart';

import 'report_date_filter.dart';

/// Toolbar filters applied to dataset + exports.
class ReportViewFilters {
  const ReportViewFilters({
    this.datePreset = ReportDatePreset.thisMonth,
    this.customRange,
    this.supplier = 'All',
    this.customer = 'All',
    this.medicine = 'All',
    this.staff = 'All',
    this.paymentMethod = 'All',
    this.paymentStatus = 'All',
  });

  final ReportDatePreset datePreset;
  final DateTimeRange? customRange;
  final String supplier;
  final String customer;
  final String medicine;
  final String staff;
  final String paymentMethod;
  final String paymentStatus;

  ReportDateRange get resolvedRange => ReportDateRange.resolve(
        preset: datePreset,
        custom: customRange,
      );

  ReportViewFilters copyWith({
    ReportDatePreset? datePreset,
    DateTimeRange? customRange,
    bool clearCustomRange = false,
    String? supplier,
    String? customer,
    String? medicine,
    String? staff,
    String? paymentMethod,
    String? paymentStatus,
  }) {
    return ReportViewFilters(
      datePreset: datePreset ?? this.datePreset,
      customRange: clearCustomRange ? null : (customRange ?? this.customRange),
      supplier: supplier ?? this.supplier,
      customer: customer ?? this.customer,
      medicine: medicine ?? this.medicine,
      staff: staff ?? this.staff,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      paymentStatus: paymentStatus ?? this.paymentStatus,
    );
  }
}
