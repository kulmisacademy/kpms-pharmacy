import 'package:flutter/material.dart';

/// Responsive pharmacy logo for UI (invoices, settings). Preserves aspect ratio; never stretches.
class KpmsPharmacyLogo extends StatelessWidget {
  const KpmsPharmacyLogo({
    super.key,
    required this.imageUrl,
    this.maxWidth = 120,
    this.maxHeight = 72,
    this.borderRadius = 12,
    this.compact = false,
  });

  final String? imageUrl;
  final double maxWidth;
  final double maxHeight;
  final double borderRadius;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final mw = compact ? (maxWidth * 0.65).clamp(48.0, maxWidth) : maxWidth;
    final mh = compact ? (maxHeight * 0.65).clamp(32.0, maxHeight) : maxHeight;
    final url = imageUrl?.trim();
    if (url == null || url.isEmpty) {
      return _placeholder(context, scheme, mw, mh);
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: Container(
        constraints: BoxConstraints(maxWidth: mw, maxHeight: mh),
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.35),
        child: Image.network(
          url,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.medium,
          gaplessPlayback: true,
          loadingBuilder: (ctx, child, progress) {
            if (progress == null) return child;
            return SizedBox(
              width: mw,
              height: mh * 0.5,
              child: Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    value: progress.expectedTotalBytes != null
                        ? progress.cumulativeBytesLoaded / progress.expectedTotalBytes!
                        : null,
                  ),
                ),
              ),
            );
          },
          errorBuilder: (_, _, _) => _placeholder(context, scheme, mw, mh),
        ),
      ),
    );
  }

  Widget _placeholder(BuildContext context, ColorScheme scheme, double mw, double mh) {
    final iconSize = (mh * 0.45).clamp(22.0, 40.0);
    return Container(
      constraints: BoxConstraints(maxWidth: mw, maxHeight: mh),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: scheme.outline.withValues(alpha: 0.2)),
      ),
      child: Icon(Icons.local_pharmacy_rounded, size: iconSize, color: scheme.primary),
    );
  }
}
