import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/kpms_feedback.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/kpms_empty_state.dart';
import '../../../core/widgets/kpms_page_shell.dart';

/// PRD §5.11 — Prescriptions (images/PDF, doctor info, verification).
class PrescriptionsScreen extends ConsumerWidget {
  const PrescriptionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return KpmsPageShell(
      title: 'Prescriptions',
      subtitle: 'Upload · history · verification',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(0, 10, 0, 12),
            child: GlassCard(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Icon(Icons.cloud_upload_outlined, size: 40, color: theme.colorScheme.primary),
                  const SizedBox(height: 12),
                  Text('Drop prescription image or PDF', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  Text(
                    'Supports PNG, JPG, PDF — ties to customer profile.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: () => kpmsSnack(context, 'Attachments will upload to storage when configured.'),
                    icon: const Icon(Icons.file_upload_outlined),
                    label: const Text('Choose file'),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text('Recent', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
          ),
          Expanded(
            child: KpmsEmptyState(
              icon: Icons.medical_information_outlined,
              title: 'No prescriptions on file',
              message: 'Uploaded scripts will list here with verification status once storage and DB hooks are enabled.',
            ),
          ),
        ],
      ),
    );
  }
}
