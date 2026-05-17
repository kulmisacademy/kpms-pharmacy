import 'package:flutter/material.dart';

import '../errors/kpms_user_facing_error.dart';

void kpmsSnack(BuildContext context, String message, {bool isError = false, Duration? duration}) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(
    SnackBar(
      content: Text(message),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      duration: duration ?? Duration(seconds: isError ? 5 : 3),
      backgroundColor: isError ? Theme.of(context).colorScheme.error : null,
    ),
  );
}

void kpmsSnackError(BuildContext context, Object error, {String? fallback}) {
  kpmsSnack(
    context,
    kpmsUserFacingMessage(error, fallback: fallback),
    isError: true,
    duration: const Duration(seconds: 6),
  );
}

void kpmsSnackSuccess(BuildContext context, String message) {
  kpmsSnack(context, message, isError: false);
}
