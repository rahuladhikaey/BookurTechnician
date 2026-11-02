import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'api_client.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp();
    debugPrint('🔔 [FCM Background] Received push: ${message.messageId} - ${message.notification?.title}');
  } catch (e) {
    debugPrint('⚠️ [FCM Background] Init error: $e');
  }
}

class FcmNotificationService {
  static final FcmNotificationService _instance = FcmNotificationService._internal();
  factory FcmNotificationService() => _instance;
  FcmNotificationService._internal();

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();

  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'bt_customer_notifications',
    'BookurTechnician Customer Alerts',
    description: 'Real-time booking updates, technician dispatch, start/end OTP, and invoices',
    importance: Importance.max,
    playSound: true,
    enableVibration: true,
  );

  bool _isInitialized = false;

  /// Initialize Firebase Push Notifications for Customer App
  Future<void> initialize({Function(Map<String, dynamic> data)? onNotificationTap}) async {
    if (_isInitialized) return;

    try {
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

      // Request permissions
      final settings = await _fcm.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      debugPrint('🔔 [FCM Customer] Permission status: ${settings.authorizationStatus}');

      // Create Local Notification Channel on Android
      final androidImplementation = _localNotifications.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      if (androidImplementation != null) {
        await androidImplementation.createNotificationChannel(_channel);
      }

      // Initialize Flutter Local Notifications
      const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
      const iosInit = DarwinInitializationSettings();
      const initSettings = InitializationSettings(android: androidInit, iOS: iosInit);

      await _localNotifications.initialize(
        initSettings,
        onDidReceiveNotificationResponse: (response) {
          if (response.payload != null && onNotificationTap != null) {
            try {
              final data = jsonDecode(response.payload!) as Map<String, dynamic>;
              onNotificationTap(data);
            } catch (_) {}
          }
        },
      );

      // Foreground message listener
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        debugPrint('🔔 [FCM Foreground] Got message: ${message.notification?.title} - ${message.notification?.body}');
        _showLocalNotification(message);
      });

      // App opened from background/terminated via notification tap
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        debugPrint('🔔 [FCM Clicked] Tapped message: ${message.data}');
        if (onNotificationTap != null) {
          onNotificationTap(message.data);
        }
      });

      // Fetch and register FCM token
      await syncTokenWithBackend();

      // Listen for token refresh
      _fcm.onTokenRefresh.listen((newToken) {
        debugPrint('🔔 [FCM Token Refreshed]: $newToken');
        _uploadTokenToBackend(newToken);
      });

      _isInitialized = true;
    } catch (e) {
      debugPrint('⚠️ [FCM Service] Failed to initialize: $e');
    }
  }

  /// Syncs current device token with backend
  Future<void> syncTokenWithBackend() async {
    try {
      final token = await _fcm.getToken();
      if (token != null) {
        debugPrint('📲 [FCM Device Token]: $token');
        await _uploadTokenToBackend(token);
      }
    } catch (e) {
      debugPrint('⚠️ [FCM Service] Token retrieval error: $e');
    }
  }

  Future<void> _uploadTokenToBackend(String token) async {
    try {
      final session = await ApiClient.getUserSession();
      final userId = session['userId'];
      if (userId == null || userId.isEmpty) {
        debugPrint('ℹ️ [FCM Service] No active user session yet, skipping backend registration.');
        return;
      }

      final response = await ApiClient.post(
        '/customer/fcm-token',
        {
          'token': token,
          'platform': defaultTargetPlatform.name.toLowerCase(),
          'userId': userId,
        },
      );
      if (response.statusCode >= 200 && response.statusCode < 300) {
        debugPrint('✅ [FCM Service] Token successfully registered to server for user $userId');
      }
    } catch (e) {
      debugPrint('⚠️ [FCM Service] Failed to upload token to backend: $e');
    }
  }

  void _showLocalNotification(RemoteMessage message) {
    final notification = message.notification;
    if (notification == null) return;

    _localNotifications.show(
      notification.hashCode,
      notification.title,
      notification.body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channel.id,
          _channel.name,
          channelDescription: _channel.description,
          importance: Importance.max,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
          playSound: true,
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: jsonEncode(message.data),
    );
  }
}
