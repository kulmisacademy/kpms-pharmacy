import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/permission_providers.dart';
import '../notifications/kpms_notification_log.dart';
import '../supabase/supabase_bootstrap.dart';
import '../tenant/kpms_active_tenant_provider.dart';
import '../../features/notifications/data/pharmacy_notification_repository.dart';
import '../../firebase_options.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../notifications/pharmacy_notification_signal_provider.dart';

/// Must be top-level for background isolate.
@pragma('vm:entry-point')
Future<void> kpmsFirebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  KpmsNotificationLog.notificationReceived(source: 'fcm_background', id: message.messageId ?? '—');
}

final _androidChannel = const AndroidNotificationChannel(
  'kpms_alerts',
  'KPMS alerts',
  description: 'Operational and subscription notifications',
  importance: Importance.high,
);

final _localPlugin = FlutterLocalNotificationsPlugin();

abstract final class KpmsPushMessagingService {
  static bool _initialized = false;
  static bool _listenersBound = false;

  static Future<void> initializeForApp() async {
    if (_initialized) return;
    try {
      await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
      FirebaseMessaging.onBackgroundMessage(kpmsFirebaseMessagingBackgroundHandler);

      await _localPlugin.initialize(
        const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          iOS: DarwinInitializationSettings(),
        ),
      );

      await _localPlugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(_androidChannel);

      _initialized = true;
    } catch (e) {
      KpmsNotificationLog.pushFailed('firebase_init $e');
    }
  }

  static Future<void> requestPermissionAndSync(WidgetRef ref) async {
    if (!_initialized) return;
    final client = SupabaseBootstrap.clientOrNull;
    final tid = ref.read(kpmsActiveTenantIdProvider).valueOrNull;
    final uid = ref.read(supabaseAuthUserIdProvider).valueOrNull;
    if (client == null || tid == null || tid.isEmpty || uid == null) return;

    try {
      await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
    } catch (e) {
      KpmsNotificationLog.pushFailed('fcm_permission $e');
    }

    await syncTokenAndListeners(ref);
  }

  static Future<void> syncTokenAndListeners(WidgetRef ref) async {
    if (!_initialized) return;
    final client = SupabaseBootstrap.clientOrNull;
    final tid = ref.read(kpmsActiveTenantIdProvider).valueOrNull;
    final uid = ref.read(supabaseAuthUserIdProvider).valueOrNull;
    if (client == null || tid == null || tid.isEmpty || uid == null) return;

    try {
      final t = await FirebaseMessaging.instance.getToken();
      if (t != null && t.isNotEmpty) {
        await PharmacyNotificationRepository.registerPushToken(
          tenantId: tid,
          userId: uid,
          token: t,
          platform: 'android',
        );
      }
    } catch (e) {
      KpmsNotificationLog.pushFailed('token_sync $e');
    }

    if (_listenersBound) return;
    _listenersBound = true;

    FirebaseMessaging.instance.onTokenRefresh.listen((t) {
      final rtid = ref.read(kpmsActiveTenantIdProvider).valueOrNull;
      final ruid = ref.read(supabaseAuthUserIdProvider).valueOrNull;
      if (rtid == null || rtid.isEmpty || ruid == null) return;
      unawaited(
        PharmacyNotificationRepository.registerPushToken(
          tenantId: rtid,
          userId: ruid,
          token: t,
          platform: 'android',
        ),
      );
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage m) {
      KpmsNotificationLog.notificationReceived(source: 'fcm_opened', id: m.messageId ?? '—');
      ref.read(pharmacyCloudNotificationSignalProvider.notifier).state++;
    });

    FirebaseMessaging.onMessage.listen((RemoteMessage m) {
      KpmsNotificationLog.notificationReceived(source: 'fcm_foreground', id: m.messageId ?? '—');
      final n = m.notification;
      final title = n?.title ?? m.data['title']?.toString() ?? 'KPMS';
      final body = n?.body ?? m.data['body']?.toString() ?? '';
      unawaited(
        _localPlugin.show(
          m.hashCode,
          title,
          body,
          NotificationDetails(
            android: AndroidNotificationDetails(
              _androidChannel.id,
              _androidChannel.name,
              channelDescription: _androidChannel.description,
              importance: Importance.high,
              priority: Priority.high,
              icon: '@mipmap/ic_launcher',
            ),
          ),
        ),
      );
      ref.read(pharmacyCloudNotificationSignalProvider.notifier).state++;
    });
  }
}

/// Binds FCM after auth + tenant resolve (not on splash/login).
class KpmsPushMessagingHost extends ConsumerStatefulWidget {
  const KpmsPushMessagingHost({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<KpmsPushMessagingHost> createState() => _KpmsPushMessagingHostState();
}

class _KpmsPushMessagingHostState extends ConsumerState<KpmsPushMessagingHost> {
  bool _initStarted = false;

  Future<void> _maybeInitPush() async {
    if (_initStarted) return;
    final uid = ref.read(supabaseAuthUserIdProvider).valueOrNull;
    final tid = ref.read(kpmsActiveTenantIdProvider).valueOrNull;
    if (uid == null || tid == null || tid.isEmpty) return;
    _initStarted = true;
    await KpmsPushMessagingService.initializeForApp();
    if (!mounted) return;
    await KpmsPushMessagingService.requestPermissionAndSync(ref);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(kpmsActiveTenantIdProvider, (_, next) {
      if (next.valueOrNull != null && next.valueOrNull!.isNotEmpty) {
        unawaited(_maybeInitPush());
      }
    });

    final uid = ref.watch(supabaseAuthUserIdProvider).valueOrNull;
    final tid = ref.watch(kpmsActiveTenantIdProvider).valueOrNull;
    if (uid != null && tid != null && tid.isNotEmpty && !_initStarted) {
      WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(_maybeInitPush()));
    }

    return widget.child;
  }
}
