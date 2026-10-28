import 'dart:io';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:path_provider/path_provider.dart';
import '../core/navigation/navigation_service.dart';
import '../models/lead_model.dart';
import '../screens/chat/dm_chat_screen.dart';
import '../screens/chat/group_chat_screen.dart';
import '../screens/concern/concern_screen.dart';
import '../screens/leads/leads_list_screen.dart';
import 'auth_service.dart';

/// Top-level background handler — required by firebase_messaging to be a
/// standalone top-level (or static) function annotated with
/// @pragma('vm:entry-point'), since background/terminated messages run on
/// a separate isolate that doesn't share state with the running app.
/// Registered once in main.dart via FirebaseMessaging.onBackgroundMessage.
///
/// This intentionally does nothing beyond letting the OS show its own
/// system notification (which it already does automatically for any FCM
/// message that includes a `notification` block, exactly what our
/// backend's sendPush always sends) — there's no UI to update while the
/// app isn't running, and re-initializing Firebase here only matters if
/// you need to call OTHER Firebase services in the background, which we
/// don't.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {}

class PushNotificationService {
  PushNotificationService._();
  static final PushNotificationService instance = PushNotificationService._();

  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  /// Call once after a successful login/session-restore. Safe to call
  /// multiple times — only does real work the first time per app run.
  Future<void> initialize() async {
    if (_initialized) {
      // Already set up from an earlier login this session — just make
      // sure the CURRENT user's token is registered (covers the
      // logout-then-login-as-someone-else case without re-attaching
      // duplicate listeners).
      await _registerCurrentToken();
      return;
    }
    _initialized = true;

    await _setupLocalNotifications();

    final messaging = FirebaseMessaging.instance;
    await messaging.requestPermission(alert: true, badge: true, sound: true);

    // iOS suppresses foreground notifications by default — this turns
    // that back on so a banner shows even while the app is open.
    await messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    await _registerCurrentToken();
    messaging.onTokenRefresh.listen((newToken) {
      AuthService.instance.registerFcmToken(newToken);
    });

    // App open and actively in the foreground — the OS won't show its
    // own banner for this case, so show one ourselves.
    FirebaseMessaging.onMessage.listen(_showLocalNotification);

    // App was backgrounded (not terminated) and the user tapped the
    // system notification to bring it back to the foreground.
    FirebaseMessaging.onMessageOpenedApp.listen((message) => _handleTap(message.data));

    // Cold start: the app was fully closed and got launched BY tapping a
    // notification. This is the one case onMessageOpenedApp won't catch.
    final initialMessage = await messaging.getInitialMessage();
    if (initialMessage != null) {
      // Give the widget tree a moment to mount before navigating.
      Future.delayed(const Duration(milliseconds: 800), () => _handleTap(initialMessage.data));
    }
  }

  Future<void> _registerCurrentToken() async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null && token.isNotEmpty) {
        await AuthService.instance.registerFcmToken(token);
      }
    } catch (_) {
      // Non-fatal — e.g. simulator without proper APNs setup. The app
      // works fine without push, it just won't receive any.
    }
  }

  Future<void> _setupLocalNotifications() async {
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings();
    await _localNotifications.initialize(
      settings: const InitializationSettings(android: androidInit, iOS: iosInit),
      onDidReceiveNotificationResponse: (response) {
        // Local notification (foreground banner) tapped — payload was
        // stashed as the notification's `payload` string; reuse the same
        // tap handler as remote taps by decoding it back into a data map.
        final raw = response.payload;
        if (raw == null || raw.isEmpty) return;
        final parts = raw.split('|');
        final data = <String, String>{};
        for (final part in parts) {
          final kv = part.split('=');
          if (kv.length == 2) data[kv[0]] = kv[1];
        }
        _handleTap(data);
      },
    );
  }

  Future<void> _showLocalNotification(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;

    final imageUrl = message.data['imageUrl'];
    final iosAttachment = await _downloadForIosAttachment(imageUrl);
    final androidLargeIcon = await _downloadForAndroidIcon(imageUrl);

    final androidDetails = AndroidNotificationDetails(
      'digital_mitro_default',
      'Digital Mitro',
      channelDescription: 'Messages, tasks, concerns, and callbacks',
      importance: Importance.high,
      priority: Priority.high,
      largeIcon: androidLargeIcon,
    );
    final iosDetails = DarwinNotificationDetails(
      attachments: iosAttachment != null ? [iosAttachment] : null,
    );
    final details = NotificationDetails(android: androidDetails, iOS: iosDetails);

    // Encode the data payload into a flat "k=v|k=v" string since
    // flutter_local_notifications only accepts a single String payload.
    final payload = message.data.entries.map((e) => '${e.key}=${e.value}').join('|');

    await _localNotifications.show(
      id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title: notification.title,
      body :notification.body,
      notificationDetails: details,
      payload: payload,
    );
  }

  /// Fetches raw bytes for the Android large icon (shown next to the
  /// notification text) — no temp file needed, flutter_local_notifications
  /// accepts bytes directly on Android. Returns null (falls back to the
  /// default app icon) on any failure or missing URL, and gives up after 3
  /// seconds rather than delay the notification for a slow image host.
  Future<ByteArrayAndroidBitmap?> _downloadForAndroidIcon(String? url) async {
    if (url == null || url.isEmpty) return null;
    try {
      final dio = Dio();
      final response = await dio.get<List<int>>(
        url,
        options: Options(
          responseType: ResponseType.bytes,
          sendTimeout: const Duration(seconds: 3),
          receiveTimeout: const Duration(seconds: 3),
        ),
      );
      final bytes = response.data;
      if (bytes == null || bytes.isEmpty) return null;
      return ByteArrayAndroidBitmap(Uint8List.fromList(bytes));
    } catch (_) {
      return null;
    }
  }

  /// iOS local-notification attachments need an actual file on disk, unlike
  /// Android which accepts raw bytes — so this downloads to a temp file.
  /// Note this only covers the *foreground* case (app open, this code
  /// actually runs). A background/killed notification is drawn entirely by
  /// iOS itself from the raw push payload, and reliably showing the image
  /// there needs a Notification Service Extension - a small separate native
  /// iOS target that intercepts the push and attaches the image before
  /// display. That's an Xcode project change (new target, entitlements,
  /// Swift code, App Group to share the download) rather than a Flutter
  /// code change, so it isn't included here.
  Future<DarwinNotificationAttachment?> _downloadForIosAttachment(String? url) async {
    if (!Platform.isIOS || url == null || url.isEmpty) return null;
    try {
      final dio = Dio();
      final response = await dio.get<List<int>>(
        url,
        options: Options(
          responseType: ResponseType.bytes,
          sendTimeout: const Duration(seconds: 3),
          receiveTimeout: const Duration(seconds: 3),
        ),
      );
      final bytes = response.data;
      if (bytes == null || bytes.isEmpty) return null;

      final dir = await getTemporaryDirectory();
      final ext = url.contains('.png') ? 'png' : 'jpg';
      final file = File('${dir.path}/push_${DateTime.now().millisecondsSinceEpoch}.$ext');
      await file.writeAsBytes(bytes);
      return DarwinNotificationAttachment(file.path);
    } catch (_) {
      return null;
    }
  }

  void _handleTap(Map<String, dynamic> data) {
    final type = data['type']?.toString();
    switch (type) {
      case 'dm':
        final senderId = data['senderId']?.toString();
        final senderName = data['senderName']?.toString() ?? 'Chat';
        final senderAvatar = data['imageUrl']?.toString() ?? '';
        if (senderId != null && senderId.isNotEmpty) {
          NavigationService.push(DmChatScreen(partnerId: senderId, partnerName: senderName, partnerAvatar: senderAvatar));
        }
        break;

      case 'channel':
      case 'mention':
      case 'task':
        final channelId = data['channelId']?.toString();
        if (channelId != null && channelId.isNotEmpty) {
          // channelName isn't in the push payload — GroupChatScreen
          // fetches and overwrites the real name on load anyway.
          NavigationService.push(GroupChatScreen(channelId: channelId, channelName: 'Channel'));
        }
        break;

      case 'concern':
        NavigationService.push(const ConcernScreen());
        break;

      case 'callback':
        NavigationService.push(const LeadsListScreen(type: LeadType.callback));
        break;
    }
  }
}
