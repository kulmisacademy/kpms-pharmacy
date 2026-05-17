import '../domain/kpms_report_id.dart';

/// KPI strip on report detail pages.
class ReportSummaryMetric {
  const ReportSummaryMetric({
    required this.label,
    required this.value,
    this.deltaLabel,
    this.deltaPositive,
  });

  final String label;
  final String value;
  /// e.g. "+12.4% vs prior"
  final String? deltaLabel;
  final bool? deltaPositive;
}

/// Chart-friendly primitives (UI maps to [fl_chart]).
class ReportLineSeries {
  const ReportLineSeries({required this.yValues, required this.xLabels});

  final List<double> yValues;
  final List<String> xLabels;
}

class ReportBarPoint {
  const ReportBarPoint({required this.label, required this.value});

  final String label;
  final double value;
}

class ReportPieSlice {
  const ReportPieSlice({required this.label, required this.value, required this.colorArgb});

  final String label;
  final double value;
  /// 0xAARRGGBB
  final int colorArgb;
}

/// Optional block appended in Excel (and PDF detail tail) after the primary table.
class ReportTableSection {
  const ReportTableSection({
    required this.title,
    required this.columns,
    required this.rows,
  });

  final String title;
  final List<String> columns;
  final List<List<String>> rows;
}

/// Full payload for one report + filter snapshot.
class ReportDataset {
  const ReportDataset({
    required this.reportId,
    required this.rangeLabel,
    required this.filterFootnote,
    required this.summaries,
    required this.line,
    required this.bars,
    required this.area,
    required this.pie,
    required this.tableColumns,
    required this.tableRows,
    this.extraSections = const [],
  });

  final KpmsReportId reportId;
  final String rangeLabel;
  final String filterFootnote;
  final List<ReportSummaryMetric> summaries;
  final ReportLineSeries line;
  final List<ReportBarPoint> bars;
  final ReportLineSeries area;
  final List<ReportPieSlice> pie;
  final List<String> tableColumns;
  final List<List<String>> tableRows;
  final List<ReportTableSection> extraSections;
}
