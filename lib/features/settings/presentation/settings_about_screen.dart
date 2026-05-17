import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../core/widgets/kpms_page_shell.dart';
import '../../../l10n/app_localizations.dart';

/// Legal, version, and support — localized.
class SettingsAboutScreen extends StatefulWidget {
  const SettingsAboutScreen({super.key});

  @override
  State<SettingsAboutScreen> createState() => _SettingsAboutScreenState();
}

class _SettingsAboutScreenState extends State<SettingsAboutScreen> {
  PackageInfo? _info;

  @override
  void initState() {
    super.initState();
    PackageInfo.fromPlatform().then((v) {
      if (mounted) setState(() => _info = v);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final info = _info;

    return KpmsPageShell(
      title: l.aboutTitle,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          Text(
            l.aboutAppName,
            style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 24),
          if (info != null) ...[
            _AboutRow(label: l.aboutVersionLabel, value: info.version),
            _AboutRow(label: l.aboutBuildLabel, value: info.buildNumber),
            const Divider(height: 32),
          ],
          _AboutRow(label: l.aboutDeveloper, value: l.aboutDeveloperValue),
          const SizedBox(height: 24),
          Text(l.aboutTerms, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          MarkdownBody(data: l.aboutTermsBody),
          const SizedBox(height: 20),
          Text(l.aboutPrivacy, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          MarkdownBody(data: l.aboutPrivacyBody),
          const SizedBox(height: 24),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.mail_outline_rounded, color: theme.colorScheme.primary),
            title: Text(l.aboutContact),
            subtitle: SelectableText(l.aboutContactValue),
          ),
          const SizedBox(height: 24),
          Text(
            l.aboutCopyright,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
          ),
        ],
      ),
    );
  }
}

class _AboutRow extends StatelessWidget {
  const _AboutRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(label, style: theme.textTheme.bodyMedium?.copyWith(color: theme.hintColor)),
          ),
          Expanded(child: Text(value, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }
}
