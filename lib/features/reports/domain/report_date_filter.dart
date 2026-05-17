import 'package:flutter/material.dart' show DateTimeRange;

/// Preset windows for report analytics and exports.
enum ReportDatePreset {
  today,
  yesterday,
  thisWeek,
  thisMonth,
  lastMonth,
  thisYear,
  custom,
  allTime,
}

extension ReportDatePresetLabel on ReportDatePreset {
  String get label => switch (this) {
        ReportDatePreset.today => 'Today',
        ReportDatePreset.yesterday => 'Yesterday',
        ReportDatePreset.thisWeek => 'This Week',
        ReportDatePreset.thisMonth => 'This Month',
        ReportDatePreset.lastMonth => 'Last Month',
        ReportDatePreset.thisYear => 'This Year',
        ReportDatePreset.custom => 'Custom Range',
        ReportDatePreset.allTime => 'All Time',
      };
}

/// Resolved window for queries and export footers.
class ReportDateRange {
  const ReportDateRange({
    required this.start,
    required this.end,
    required this.label,
  });

  final DateTime start;
  final DateTime end;
  final String label;

  static ReportDateRange resolve({
    required ReportDatePreset preset,
    DateTimeRange? custom,
    DateTime? now,
  }) {
    final n = now ?? DateTime.now();
    final todayStart = DateTime(n.year, n.month, n.day);
    final todayEnd = n;

    switch (preset) {
      case ReportDatePreset.today:
        return ReportDateRange(start: todayStart, end: todayEnd, label: preset.label);
      case ReportDatePreset.yesterday:
        final y = todayStart.subtract(const Duration(days: 1));
        return ReportDateRange(
          start: y,
          end: DateTime(y.year, y.month, y.day, 23, 59, 59),
          label: preset.label,
        );
      case ReportDatePreset.thisWeek:
        final wd = n.weekday;
        final monday = todayStart.subtract(Duration(days: wd - DateTime.monday));
        return ReportDateRange(start: monday, end: todayEnd, label: preset.label);
      case ReportDatePreset.thisMonth:
        return ReportDateRange(
          start: DateTime(n.year, n.month),
          end: todayEnd,
          label: preset.label,
        );
      case ReportDatePreset.lastMonth:
        final firstThis = DateTime(n.year, n.month);
        final lastMonthEnd = firstThis.subtract(const Duration(days: 1));
        final lastMonthStart = DateTime(lastMonthEnd.year, lastMonthEnd.month);
        return ReportDateRange(
          start: lastMonthStart,
          end: DateTime(lastMonthEnd.year, lastMonthEnd.month, lastMonthEnd.day, 23, 59, 59),
          label: preset.label,
        );
      case ReportDatePreset.thisYear:
        return ReportDateRange(
          start: DateTime(n.year),
          end: todayEnd,
          label: preset.label,
        );
      case ReportDatePreset.custom:
        if (custom != null) {
          final a = DateTime(custom.start.year, custom.start.month, custom.start.day);
          final b = DateTime(custom.end.year, custom.end.month, custom.end.day, 23, 59, 59);
          return ReportDateRange(
            start: a,
            end: b,
            label: '${_fmt(a)} — ${_fmt(b)}',
          );
        }
        return ReportDateRange(start: todayStart, end: todayEnd, label: 'Custom');
      case ReportDatePreset.allTime:
        return ReportDateRange(
          start: DateTime(2020, 1, 1),
          end: todayEnd,
          label: preset.label,
        );
    }
  }

  static String _fmt(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
