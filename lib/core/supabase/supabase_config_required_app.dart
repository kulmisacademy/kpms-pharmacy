import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kDebugMode, kIsWeb;
import 'package:flutter/material.dart';

import '../config/kpms_environment.dart';
import '../../l10n/app_localizations.dart';
import '../../l10n/kpms_locale_fallback_delegates.dart';

/// Compact screen when Supabase URL / anon key are missing.
class SupabaseConfigRequiredApp extends StatelessWidget {
  const SupabaseConfigRequiredApp({super.key});

  static bool get _isMobile {
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      localizationsDelegates: kpmsLocalizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      onGenerateTitle: (ctx) => AppLocalizations.of(ctx).appTitle,
      home: Builder(
        builder: (context) {
          final scheme = Theme.of(context).colorScheme;
          final l = AppLocalizations.of(context);
          final mobile = _isMobile;
          final issues = KpmsEnvironment.startupIssues;
          final loadErr = KpmsEnvironment.loadError;

          return Scaffold(
            body: SafeArea(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 400),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Icon(Icons.cloud_off_outlined, size: 40, color: scheme.primary),
                        const SizedBox(height: 12),
                        Text(
                          l.supabaseNotConfiguredTitle,
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          l.supabaseNotConfiguredHint,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant, height: 1.35),
                          textAlign: TextAlign.center,
                        ),
                        if (loadErr != null) ...[
                          const SizedBox(height: 12),
                          SelectableText(
                            loadErr,
                            style: TextStyle(fontSize: 11, color: scheme.error, fontFamily: 'monospace'),
                          ),
                        ],
                        if (issues.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          ...issues.map(
                            (s) => Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('• ', style: TextStyle(color: scheme.primary, fontWeight: FontWeight.w800)),
                                  Expanded(child: Text(s, style: Theme.of(context).textTheme.bodySmall?.copyWith(height: 1.35))),
                                ],
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 14),
                        DecoratedBox(
                          decoration: BoxDecoration(
                            color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Text(
                              mobile
                                  ? l.supabaseConfigHelpMobile
                                  : kIsWeb
                                      ? l.supabaseConfigHelpWeb
                                      : l.supabaseConfigHelpDesktop,
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(height: 1.4),
                            ),
                          ),
                        ),
                        if (kDebugMode) ...[
                          const SizedBox(height: 10),
                          Text(
                            l.supabaseConfigConsoleHint,
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(color: scheme.outline),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
