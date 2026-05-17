import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/kpms_operational_notification_engine.dart';

/// Periodically evaluates inventory / sync / debt rules and upserts deduped cloud notifications.
class KpmsOperationalNotificationsHost extends ConsumerStatefulWidget {
  const KpmsOperationalNotificationsHost({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<KpmsOperationalNotificationsHost> createState() => _KpmsOperationalNotificationsHostState();
}

class _KpmsOperationalNotificationsHostState extends ConsumerState<KpmsOperationalNotificationsHost> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(KpmsOperationalNotificationEngine.run(ref));
    });
    _timer = Timer.periodic(const Duration(seconds: 55), (_) {
      if (!mounted) return;
      unawaited(KpmsOperationalNotificationEngine.run(ref));
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
