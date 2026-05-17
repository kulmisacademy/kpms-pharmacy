import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../../providers/app_locale_provider.dart';
import '../utils/kpms_feedback.dart';

/// App UI language (Somali / English / Arabic) — updates instantly via [appLocaleProvider].
Future<void> showKpmsLanguagePickerSheet(BuildContext parentContext, WidgetRef ref) {
  return showModalBottomSheet<void>(
    context: parentContext,
    useRootNavigator: false,
    showDragHandle: true,
    builder: (ctx) {
      final l = AppLocalizations.of(ctx);
      final current = ref.read(appLocaleProvider);
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l.languageSheetTitle, style: Theme.of(ctx).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Text(l.languageSheetHint, style: Theme.of(ctx).textTheme.bodySmall?.copyWith(color: Theme.of(ctx).hintColor)),
              const SizedBox(height: 12),
              RadioGroup<String>(
                groupValue: current.languageCode,
                onChanged: (v) async {
                  if (v == null) return;
                  await ref.read(appLocaleProvider.notifier).setLocale(Locale(v));
                  if (ctx.mounted) Navigator.pop(ctx);
                  if (parentContext.mounted) kpmsSnack(parentContext, l.snackLocaleUpdated);
                },
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    RadioListTile<String>(title: Text(l.languageEnglish), value: 'en'),
                    RadioListTile<String>(title: Text(l.languageSomali), value: 'so'),
                    RadioListTile<String>(title: Text(l.languageArabic), value: 'ar'),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
