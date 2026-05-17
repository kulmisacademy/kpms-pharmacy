import 'package:flutter/material.dart';

class ReportSectionTitle extends StatelessWidget {
  const ReportSectionTitle({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        label,
        style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800, letterSpacing: 0.2),
      ),
    );
  }
}
