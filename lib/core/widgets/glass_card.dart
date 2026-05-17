import 'dart:ui';

import 'package:flutter/material.dart';

/// Soft glass panel — PRD §10 glassmorphism, rounded cards.
class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.borderRadius = 16,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final frost = isDark ? Colors.white.withValues(alpha: 0.06) : Colors.white.withValues(alpha: 0.35);
    final border = isDark ? Colors.white.withValues(alpha: 0.12) : Colors.white.withValues(alpha: 0.6);

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: frost,
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(color: border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.08),
                blurRadius: 32,
                offset: const Offset(0, 18),
              ),
            ],
          ),
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}
