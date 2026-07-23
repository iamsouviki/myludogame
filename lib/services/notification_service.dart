import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../models/app_notification.dart';
import '../ui/screens/home_screen.dart';
import '../ui/screens/notification_center_screen.dart';

class AppNavigation {
  static final navigatorKey = GlobalKey<NavigatorState>();
}

Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Background isolates cannot rely on widgets, so we only hydrate the payload.
  await NotificationService.instance.initialize();
  await NotificationService.instance.handleRemoteMessage(message, fromBackground: true);
}

class NotificationService {
  NotificationService._();
  static final instance = NotificationService._();

  final _bannerController = StreamController<AppNotification>.broadcast();
  final _notificationsController = StreamController<List<AppNotification>>.broadcast();
  final List<AppNotification> _items = [];
  final FlutterLocalNotificationsPlugin _local = FlutterLocalNotificationsPlugin();

  Stream<AppNotification> get bannerStream => _bannerController.stream;
  Stream<List<AppNotification>> get notificationsStream => _notificationsController.stream;
  List<AppNotification> get items => List.unmodifiable(_items);
  int get unreadCount => _items.where((n) => !n.isRead).length;

  bool _initialized = false;
  String? _token;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings();
    const settings = InitializationSettings(android: android, iOS: ios);
    await _local.initialize(settings, onDidReceiveNotificationResponse: (response) {
      _handleDeepLink(response.payload);
    });

    final supportedMobile = !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS ||
            defaultTargetPlatform == TargetPlatform.macOS);
    if (supportedMobile) {
      await FirebaseMessaging.instance.requestPermission(alert: true, badge: true, sound: true);
      _token = await FirebaseMessaging.instance.getToken();
      FirebaseMessaging.instance.onTokenRefresh.listen((token) => _token = token);
      FirebaseMessaging.onMessage.listen((message) => handleRemoteMessage(message));
      FirebaseMessaging.onMessageOpenedApp.listen((message) => _handleDeepLink(message.data['deepLink'] as String?));
      final initial = await FirebaseMessaging.instance.getInitialMessage();
      if (initial != null) {
        _handleDeepLink(initial.data['deepLink'] as String?);
      }
    }
  }

  String? get token => _token;

  Future<void> handleRemoteMessage(RemoteMessage message, {bool fromBackground = false}) async {
    final data = message.data;
    final notification = AppNotification.fromRemote({
      'id': data['id'] ?? message.messageId ?? DateTime.now().microsecondsSinceEpoch.toString(),
      'title': data['title'] ?? message.notification?.title ?? 'Notification',
      'body': data['body'] ?? message.notification?.body ?? '',
      'category': data['category'] ?? 'general',
      'timestamp': data['timestamp'] ?? DateTime.now().millisecondsSinceEpoch,
      'deepLink': data['deepLink'],
      'imageUrl': data['imageUrl'],
      'senderName': data['senderName'],
    });
    push(notification, showSystem: !fromBackground);
  }

  Future<void> push(
    AppNotification notification, {
    bool showSystem = false,
  }) async {
    _items.insert(0, notification);
    if (_items.length > 100) {
      _items.removeRange(100, _items.length);
    }
    _notificationsController.add(List.unmodifiable(_items));
    _bannerController.add(notification);

    if (showSystem) {
      const androidDetails = AndroidNotificationDetails(
        'my_ludo_channel',
        'My Ludo Notifications',
        channelDescription: 'Game, chat, and reward notifications',
        importance: Importance.max,
        priority: Priority.high,
        playSound: true,
        enableVibration: true,
      );
      const iosDetails = DarwinNotificationDetails(presentAlert: true, presentBadge: true, presentSound: true);
      await _local.show(
        notification.id.hashCode,
        notification.title,
        notification.body,
        const NotificationDetails(android: androidDetails, iOS: iosDetails),
        payload: notification.deepLink,
      );
    }
  }

  void markAllRead() {
    for (final item in _items) {
      item.isRead = true;
    }
    _notificationsController.add(List.unmodifiable(_items));
  }

  void markRead(String id) {
    final idx = _items.indexWhere((n) => n.id == id);
    if (idx < 0) return;
    _items[idx] = _items[idx].copyWith(isRead: true);
    _notificationsController.add(List.unmodifiable(_items));
  }

  void clearAll() {
    _items.clear();
    _notificationsController.add(List.unmodifiable(_items));
  }

  Future<void> subscribeTopics(Iterable<String> topics) async {
    final supportedMobile = !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS ||
            defaultTargetPlatform == TargetPlatform.macOS);
    if (supportedMobile) {
      for (final topic in topics) {
        await FirebaseMessaging.instance.subscribeToTopic(topic);
      }
    }
  }

  void dispose() {
    _bannerController.close();
    _notificationsController.close();
  }

  void _handleDeepLink(String? deepLink) {
    if (deepLink == null || deepLink.isEmpty) return;
    final nav = AppNavigation.navigatorKey.currentState;
    if (nav == null) return;

    if (deepLink.startsWith('myludo://game/')) {
      nav.push(MaterialPageRoute(builder: (_) => const HomeScreen()));
    } else if (deepLink.startsWith('myludo://lobby')) {
      nav.push(MaterialPageRoute(builder: (_) => const HomeScreen()));
    } else if (deepLink.startsWith('myludo://notifications')) {
      nav.push(MaterialPageRoute(builder: (_) => const NotificationCenterScreen()));
    }
  }
}

class NotificationBootstrap {
  static Future<void> init() async {
    await NotificationService.instance.initialize();
  }
}
