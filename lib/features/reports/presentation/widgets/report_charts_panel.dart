import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../application/report_models.dart';

class ReportChartsPanel extends StatelessWidget {
  const ReportChartsPanel({super.key, required this.dataset});

  final ReportDataset dataset;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final outline = theme.colorScheme.outline.withValues(alpha: 0.28);
    final spots = [
      for (var i = 0; i < dataset.line.yValues.length; i++)
        FlSpot(i.toDouble(), dataset.line.yValues[i]),
    ];
    final areaSpots = [
      for (var i = 0; i < dataset.area.yValues.length; i++)
        FlSpot(i.toDouble(), dataset.area.yValues[i]),
    ];
    final barGroups = [
      for (var i = 0; i < dataset.bars.length; i++)
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: dataset.bars[i].value,
              width: 14,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [
                  AppColors.primary.withValues(alpha: 0.55),
                  AppColors.primary,
                ],
              ),
            ),
          ],
        ),
    ];
    final pieTotal = dataset.pie.fold<double>(0, (a, b) => a + b.value);
    final pieSections = [
      for (var i = 0; i < dataset.pie.length; i++)
        PieChartSectionData(
          value: dataset.pie[i].value,
          title: pieTotal > 0 ? '${((dataset.pie[i].value / pieTotal) * 100).round()}%' : '',
          radius: 52,
          titleStyle: theme.textTheme.labelSmall?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            shadows: const [Shadow(color: Colors.black45, blurRadius: 4)],
          ),
          color: Color(dataset.pie[i].colorArgb),
        ),
    ];

    Widget shell(String title, Widget child) => _ChartCard(outline: outline, title: title, child: child);

    final lineChart = shell(
      'Trend',
      SizedBox(
        height: 220,
        child: LineChart(
          LineChartData(
            minX: 0,
            maxX: (spots.length - 1).toDouble().clamp(0, 999),
            gridData: FlGridData(show: true, drawVerticalLine: false, horizontalInterval: null),
            borderData: FlBorderData(show: false),
            titlesData: FlTitlesData(
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 28,
                  getTitlesWidget: (v, m) {
                    final i = v.round();
                    if (i < 0 || i >= dataset.line.xLabels.length) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        dataset.line.xLabels[i],
                        style: theme.textTheme.labelSmall?.copyWith(color: theme.hintColor),
                      ),
                    );
                  },
                ),
              ),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 44,
                  getTitlesWidget: (v, m) => Text(
                    v >= 1000 ? '${(v / 1000).toStringAsFixed(1)}k' : v.toStringAsFixed(0),
                    style: theme.textTheme.labelSmall?.copyWith(color: theme.hintColor),
                  ),
                ),
              ),
              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            ),
            lineTouchData: LineTouchData(enabled: true),
            lineBarsData: [
              LineChartBarData(
                spots: spots,
                isCurved: true,
                curveSmoothness: 0.28,
                barWidth: 3,
                color: AppColors.primary,
                dotData: const FlDotData(show: false),
                belowBarData: BarAreaData(
                  show: true,
                  color: AppColors.primary.withValues(alpha: isDark ? 0.18 : 0.12),
                ),
              ),
            ],
          ),
          duration: const Duration(milliseconds: 650),
          curve: Curves.easeOutCubic,
        ),
      ),
    );

    final barChart = shell(
      'Composition',
      SizedBox(
        height: 220,
        child: BarChart(
          BarChartData(
            gridData: FlGridData(show: true, drawVerticalLine: false),
            borderData: FlBorderData(show: false),
            titlesData: FlTitlesData(
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 30,
                  getTitlesWidget: (v, m) {
                    final i = v.toInt();
                    if (i < 0 || i >= dataset.bars.length) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        dataset.bars[i].label,
                        style: theme.textTheme.labelSmall?.copyWith(color: theme.hintColor),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  },
                ),
              ),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 40,
                  getTitlesWidget: (v, m) => Text(
                    v.toStringAsFixed(0),
                    style: theme.textTheme.labelSmall?.copyWith(color: theme.hintColor),
                  ),
                ),
              ),
              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            ),
            barGroups: barGroups,
            alignment: BarChartAlignment.spaceAround,
          ),
          duration: const Duration(milliseconds: 650),
          curve: Curves.easeOutCubic,
        ),
      ),
    );

    final areaChart = shell(
      'Velocity',
      SizedBox(
        height: 220,
        child: LineChart(
          LineChartData(
            minX: 0,
            maxX: (areaSpots.length - 1).toDouble().clamp(0, 999),
            gridData: FlGridData(show: true, drawVerticalLine: false),
            borderData: FlBorderData(show: false),
            titlesData: FlTitlesData(
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 28,
                  getTitlesWidget: (v, m) {
                    final i = v.round();
                    if (i < 0 || i >= dataset.area.xLabels.length) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        dataset.area.xLabels[i],
                        style: theme.textTheme.labelSmall?.copyWith(color: theme.hintColor),
                      ),
                    );
                  },
                ),
              ),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 44,
                  getTitlesWidget: (v, m) => Text(
                    v >= 1000 ? '${(v / 1000).toStringAsFixed(1)}k' : v.toStringAsFixed(0),
                    style: theme.textTheme.labelSmall?.copyWith(color: theme.hintColor),
                  ),
                ),
              ),
              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            ),
            lineBarsData: [
              LineChartBarData(
                spots: areaSpots,
                isCurved: true,
                curveSmoothness: 0.32,
                barWidth: 0,
                color: AppColors.secondary,
                dotData: const FlDotData(show: false),
                belowBarData: BarAreaData(
                  show: true,
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      AppColors.secondary.withValues(alpha: isDark ? 0.35 : 0.22),
                      AppColors.secondary.withValues(alpha: 0.02),
                    ],
                  ),
                ),
              ),
            ],
          ),
          duration: const Duration(milliseconds: 650),
          curve: Curves.easeOutCubic,
        ),
      ),
    );

    final pieChart = shell(
      'Mix',
      SizedBox(
        height: 240,
        child: Row(
          children: [
            Expanded(
              flex: 3,
              child: PieChart(
                PieChartData(
                  sectionsSpace: 2,
                  centerSpaceRadius: 36,
                  sections: pieSections,
                  pieTouchData: PieTouchData(enabled: true),
                ),
                duration: const Duration(milliseconds: 650),
                curve: Curves.easeOutCubic,
              ),
            ),
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (final s in dataset.pie)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: Color(s.colorArgb),
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              s.label,
                              style: theme.textTheme.labelSmall,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    return LayoutBuilder(
      builder: (context, c) {
        final wide = c.maxWidth > 900;
        if (wide) {
          return Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: lineChart),
                  const SizedBox(width: 12),
                  Expanded(child: barChart),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: areaChart),
                  const SizedBox(width: 12),
                  Expanded(child: pieChart),
                ],
              ),
            ],
          );
        }
        return Column(
          children: [
            lineChart,
            const SizedBox(height: 12),
            barChart,
            const SizedBox(height: 12),
            areaChart,
            const SizedBox(height: 12),
            pieChart,
          ],
        );
      },
    );
  }
}

class _ChartCard extends StatelessWidget {
  const _ChartCard({required this.outline, required this.title, required this.child});

  final Color outline;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: outline),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            child,
          ],
        ),
      ),
    );
  }
}
