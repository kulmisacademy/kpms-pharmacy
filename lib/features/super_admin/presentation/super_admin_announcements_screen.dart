import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/navigation/kpms_breakpoints.dart';
import '../../../core/utils/kpms_feedback.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/kpms_platform_admin_shell.dart';
import '../application/platform_admin_providers.dart';

/// Publishes a global in-app notification via `super_admin_publish_global_notification`.
class SuperAdminAnnouncementsScreen extends ConsumerStatefulWidget {
  const SuperAdminAnnouncementsScreen({super.key});

  @override
  ConsumerState<SuperAdminAnnouncementsScreen> createState() => _SuperAdminAnnouncementsScreenState();
}

class _SuperAdminAnnouncementsScreenState extends ConsumerState<SuperAdminAnnouncementsScreen> {
  final _title = TextEditingController();
  final _body = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return KpmsPlatformAdminShell(
      title: 'Announcements',
      subtitle: 'Global in-app banner (platform_settings)',
      body: ListView(
        padding: KpmsBreakpoints.pageScrollPadding(context),
        children: [
          GlassCard(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Compose', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 12),
                TextField(
                  controller: _title,
                  decoration: const InputDecoration(
                    labelText: 'Title',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _body,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Message',
                    alignLabelWithHint: true,
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _busy
                      ? null
                      : () async {
                          if (_title.text.trim().isEmpty || _body.text.trim().isEmpty) {
                            kpmsSnack(context, 'Title and message are required.', isError: true);
                            return;
                          }
                          setState(() => _busy = true);
                          try {
                            await ref.read(platformAdminRepositoryProvider).publishGlobalNotification(
                                  title: _title.text.trim(),
                                  body: _body.text.trim(),
                                );
                            ref.invalidate(superAdminGlobalSettingsProvider);
                            ref.invalidate(superAdminAuditProvider);
                            if (!context.mounted) return;
                            kpmsSnack(context, 'Global notification published.');
                          } catch (e) {
                            if (!context.mounted) return;
                            kpmsSnack(context, '$e', isError: true);
                          } finally {
                            if (mounted) setState(() => _busy = false);
                          }
                        },
                  icon: _busy
                      ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.send_rounded),
                  label: const Text('Publish to all tenants'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text('Note', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text(
            'Pharmacy apps can read the banner via get_public_platform_banner. Wire a top banner in the pharmacy shell when you want it visible to staff.',
            style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor, height: 1.45),
          ),
        ],
      ),
    );
  }
}
