import 'package:flutter/material.dart';

/// Lightweight shimmer-free skeleton block. Uses theme surface tones so it works in
/// light + dark without any extra dependencies.
class KpmsSkeleton extends StatefulWidget {
  const KpmsSkeleton({
    super.key,
    this.width,
    this.height = 14,
    this.radius = 8,
  });

  final double? width;
  final double height;
  final double radius;

  @override
  State<KpmsSkeleton> createState() => _KpmsSkeletonState();
}

class _KpmsSkeletonState extends State<KpmsSkeleton> with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))..repeat(reverse: true);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final base = theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.6);
    final highlight = theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.95);
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final t = Curves.easeInOut.transform(_c.value);
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            color: Color.lerp(base, highlight, t),
            borderRadius: BorderRadius.circular(widget.radius),
          ),
        );
      },
    );
  }
}

/// Vertical list of skeleton rows — used while the catalog/inventory is bootstrapping.
class KpmsListSkeleton extends StatelessWidget {
  const KpmsListSkeleton({super.key, this.rows = 6});

  final int rows;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: rows,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, _) => Row(
        children: [
          const KpmsSkeleton(width: 48, height: 48, radius: 12),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                KpmsSkeleton(width: MediaQuery.sizeOf(context).width * 0.45, height: 14),
                const SizedBox(height: 8),
                const KpmsSkeleton(width: 140, height: 10),
              ],
            ),
          ),
          const SizedBox(width: 12),
          const KpmsSkeleton(width: 56, height: 18),
        ],
      ),
    );
  }
}
