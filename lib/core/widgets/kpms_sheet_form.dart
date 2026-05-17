import 'package:flutter/material.dart';

import '../responsive/responsive_helpers.dart';
import '../theme/app_theme.dart';
import 'kpms_responsive_dialog.dart';

/// Bottom sheet scaffold with drag handle, title, and Save/Cancel — consistent UX.
Future<T?> showKpmsSheetForm<T>(
  BuildContext context, {
  required String title,
  required List<Widget> fields,
  required String submitLabel,
  VoidCallback? onSubmit,
}) {
  Widget formBody(BuildContext ctx, {required bool showDragHandle}) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (showDragHandle)
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Theme.of(ctx).dividerColor.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              if (showDragHandle) const SizedBox(height: 16),
              Text(title, style: Theme.of(ctx).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 20),
              ...fields,
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: () {
                        Navigator.of(ctx).pop();
                        onSubmit?.call();
                      },
                      child: Text(submitLabel),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  if (isMobile(context)) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppTheme.radiusCard + 4)),
      ),
      builder: (ctx) => formBody(ctx, showDragHandle: true),
    );
  }

  return showKpmsAdaptiveSheet<T>(
    context: context,
    dialogMaxWidth: kpmsDesktopDialogMaxWidth,
    builder: (ctx) => formBody(ctx, showDragHandle: false),
  );
}
