import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/kpms_report_id.dart';

/// Compact analytics tile for the reports hub — consistent sizing and clean surfaces.
class KpmsReportHubCard extends StatefulWidget {
  const KpmsReportHubCard({
    super.key,
    required this.report,
    required this.previewLine1,
    required this.previewLine2,
    this.trendPct,
    required this.onTap,
    this.animation,
  });

  final KpmsReportId report;
  final String previewLine1;
  final String previewLine2;
  final double? trendPct;
  final VoidCallback onTap;
  final Animation<double>? animation;

  @override
  State<KpmsReportHubCard> createState() => _KpmsReportHubCardState();
}

class _KpmsReportHubCardState extends State<KpmsReportHubCard> {
  bool _pressed = false;
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final outline = theme.colorScheme.outline.withValues(alpha: 0.22);
    final scale = (_hover || _pressed) ? 1.015 : 1.0;

    Widget card = AnimatedScale(
      scale: scale,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      child: Material(
        color: theme.colorScheme.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: outline),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: widget.onTap,
          onHighlightChanged: (v) => setState(() => _pressed = v),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            decoration: BoxDecoration(
              boxShadow: [
                if (_hover)
                  BoxShadow(
                    color: Colors.black.withValues(alpha: theme.brightness == Brightness.dark ? 0.18 : 0.06),
                    blurRadius: 14,
                    offset: const Offset(0, 8),
                  ),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    color: AppColors.primary.withValues(alpha: theme.brightness == Brightness.dark ? 0.22 : 0.12),
                  ),
                  child: Icon(widget.report.icon, color: AppColors.primary, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              widget.report.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                            ),
                          ),
                          if (widget.trendPct != null) ...[
                            const SizedBox(width: 8),
                            _TrendChip(pct: widget.trendPct!),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.report.description,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor, height: 1.25),
                      ),
                      const Spacer(),
                      Text(
                        widget.previewLine1,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.previewLine2,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelSmall?.copyWith(color: theme.hintColor),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    card = MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: card,
    );

    if (widget.animation != null) {
      card = FadeTransition(
        opacity: widget.animation!,
        child: SlideTransition(
          position: Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero).animate(widget.animation!),
          child: card,
        ),
      );
    }

    return card;
  }
}

class _TrendChip extends StatelessWidget {
  const _TrendChip({required this.pct});

  final double pct;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final up = pct >= 0;
    final color = up ? const Color(0xFF2E7D32) : const Color(0xFFB71C1C);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(up ? Icons.trending_up_rounded : Icons.trending_down_rounded, size: 13, color: color),
          const SizedBox(width: 4),
          Text(
            '${up ? '+' : ''}${pct.toStringAsFixed(1)}%',
            style: theme.textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w800, color: color),
          ),
        ],
      ),
    );
  }
}
