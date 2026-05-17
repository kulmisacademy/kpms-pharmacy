import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../application/report_models.dart';

class ReportSummaryHeader extends StatelessWidget {
  const ReportSummaryHeader({super.key, required this.metrics});

  final List<ReportSummaryMetric> metrics;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final outline = theme.colorScheme.outline.withValues(alpha: 0.28);

    return LayoutBuilder(
      builder: (context, c) {
        final n = c.maxWidth > 1100 ? 4 : c.maxWidth > 560 ? 2 : 1;
        final gap = 12.0;
        final tileW = (c.maxWidth - gap * (n - 1)) / n;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final m in metrics)
              SizedBox(
                width: tileW,
                child: _MetricTile(metric: m, outline: outline),
              ),
          ],
        );
      },
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({required this.metric, required this.outline});

  final ReportSummaryMetric metric;
  final Color outline;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Color? deltaColor;
    if (metric.deltaLabel != null) {
      if (metric.deltaPositive == null) {
        deltaColor = theme.hintColor;
      } else {
        deltaColor = metric.deltaPositive! ? const Color(0xFF2E7D32) : const Color(0xFFB71C1C);
      }
    }

    return Material(
      color: theme.colorScheme.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: outline),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    metric.label,
                    style: theme.textTheme.labelSmall?.copyWith(color: theme.hintColor, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    metric.value,
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  if (metric.deltaLabel != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      metric.deltaLabel!,
                      style: theme.textTheme.labelSmall?.copyWith(color: deltaColor, fontWeight: FontWeight.w700),
                    ),
                  ],
                ],
              ),
            ),
            Icon(Icons.analytics_outlined, color: AppColors.primary.withValues(alpha: 0.55)),
          ],
        ),
      ),
    );
  }
}
