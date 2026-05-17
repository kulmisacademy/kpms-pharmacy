import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/navigation/kpms_breakpoints.dart';
import '../../../core/utils/kpms_feedback.dart';
import '../../../core/widgets/kpms_platform_admin_shell.dart';
import '../application/platform_admin_providers.dart';

class SuperAdminGlobalSettingsScreen extends ConsumerWidget {
  const SuperAdminGlobalSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(superAdminGlobalSettingsProvider);
    return KpmsPlatformAdminShell(
      title: 'Global settings',
      subtitle: 'Branding · maintenance · trials',
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh_rounded),
          onPressed: () => ref.invalidate(superAdminGlobalSettingsProvider),
        ),
      ],
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (s) => _SettingsForm(
          initial: s,
          onSave: (payload) async {
            try {
              await ref.read(platformAdminRepositoryProvider).setGlobalSettings(
                    brandingAppName: payload.brandingAppName,
                    brandingTagline: payload.brandingTagline,
                    maintenanceMode: payload.maintenanceMode,
                    maintenanceMessage: payload.maintenanceMessage,
                    globalNotificationTitle: payload.globalNotificationTitle,
                    globalNotificationBody: payload.globalNotificationBody,
                    globalNotificationActive: payload.globalNotificationActive,
                    defaultTrialDays: payload.defaultTrialDays,
                  );
              ref.invalidate(superAdminGlobalSettingsProvider);
              if (context.mounted) kpmsSnack(context, 'Settings saved.');
            } catch (e) {
              if (context.mounted) kpmsSnack(context, '$e', isError: true);
            }
          },
        ),
      ),
    );
  }
}

class _SettingsPayload {
  const _SettingsPayload({
    required this.brandingAppName,
    required this.brandingTagline,
    required this.maintenanceMode,
    required this.maintenanceMessage,
    required this.globalNotificationTitle,
    required this.globalNotificationBody,
    required this.globalNotificationActive,
    required this.defaultTrialDays,
  });

  final String? brandingAppName;
  final String? brandingTagline;
  final bool? maintenanceMode;
  final String? maintenanceMessage;
  final String? globalNotificationTitle;
  final String? globalNotificationBody;
  final bool? globalNotificationActive;
  final int? defaultTrialDays;
}

class _SettingsForm extends StatefulWidget {
  const _SettingsForm({required this.initial, required this.onSave});

  final Map<String, dynamic> initial;
  final Future<void> Function(_SettingsPayload payload) onSave;

  @override
  State<_SettingsForm> createState() => _SettingsFormState();
}

class _SettingsFormState extends State<_SettingsForm> {
  late final TextEditingController _brandName;
  late final TextEditingController _tagline;
  late final TextEditingController _maintMsg;
  late final TextEditingController _notifTitle;
  late final TextEditingController _notifBody;
  late final TextEditingController _trialDays;
  bool _maint = false;
  bool _notifActive = false;

  @override
  void initState() {
    super.initState();
    final s = widget.initial;
    _brandName = TextEditingController(text: s['branding_app_name']?.toString() ?? '');
    _tagline = TextEditingController(text: s['branding_tagline']?.toString() ?? '');
    _maintMsg = TextEditingController(text: s['maintenance_message']?.toString() ?? '');
    _notifTitle = TextEditingController(text: s['global_notification_title']?.toString() ?? '');
    _notifBody = TextEditingController(text: s['global_notification_body']?.toString() ?? '');
    _trialDays = TextEditingController(text: '${s['default_trial_days'] ?? 14}');
    _maint = s['maintenance_mode'] == true;
    _notifActive = s['global_notification_active'] == true;
  }

  @override
  void dispose() {
    _brandName.dispose();
    _tagline.dispose();
    _maintMsg.dispose();
    _notifTitle.dispose();
    _notifBody.dispose();
    _trialDays.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: KpmsBreakpoints.pageScrollPadding(context),
      children: [
        Text('Branding', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        TextField(controller: _brandName, decoration: const InputDecoration(labelText: 'App display name', border: OutlineInputBorder())),
        const SizedBox(height: 12),
        TextField(controller: _tagline, decoration: const InputDecoration(labelText: 'Tagline', border: OutlineInputBorder())),
        const SizedBox(height: 24),
        Text('Maintenance', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
        SwitchListTile(
          title: const Text('Maintenance mode'),
          subtitle: const Text('Blocks pharmacy workspace for all tenants'),
          value: _maint,
          onChanged: (v) => setState(() => _maint = v),
        ),
        TextField(
          controller: _maintMsg,
          maxLines: 2,
          decoration: const InputDecoration(labelText: 'Maintenance message', border: OutlineInputBorder()),
        ),
        const SizedBox(height: 24),
        Text('Notifications', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
        SwitchListTile(
          title: const Text('Global in-app notification'),
          value: _notifActive,
          onChanged: (v) => setState(() => _notifActive = v),
        ),
        TextField(controller: _notifTitle, decoration: const InputDecoration(labelText: 'Title', border: OutlineInputBorder())),
        const SizedBox(height: 12),
        TextField(
          controller: _notifBody,
          maxLines: 3,
          decoration: const InputDecoration(labelText: 'Body', border: OutlineInputBorder()),
        ),
        const SizedBox(height: 24),
        TextField(
          controller: _trialDays,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Default trial days (new pharmacies)', border: OutlineInputBorder()),
        ),
        const SizedBox(height: 24),
        FilledButton(
          onPressed: () async {
            final days = int.tryParse(_trialDays.text.trim());
            await widget.onSave(
              _SettingsPayload(
                brandingAppName: _brandName.text.trim(),
                brandingTagline: _tagline.text.trim(),
                maintenanceMode: _maint,
                maintenanceMessage: _maintMsg.text.trim(),
                globalNotificationTitle: _notifTitle.text.trim(),
                globalNotificationBody: _notifBody.text.trim(),
                globalNotificationActive: _notifActive,
                defaultTrialDays: days,
              ),
            );
          },
          child: const Text('Save settings'),
        ),
      ],
    );
  }
}
