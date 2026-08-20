import 'dart:convert';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../config/app_config.dart';
import '../network/dio_client.dart';
import 'audio_alert_service.dart';
import '../../features/dispatch/presentation/incoming_job_alert_dialog.dart';

/// Top-level background message handler required by Firebase Messaging
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint('[FCM Background] Message received: ${message.messageId} | Data: ${message.data}');

  if (message.data['type'] == 'NEW_JOB_ALERT') {
    // Play loud incoming ringtone in background
    await AudioAlertService().startJobAlertRingtone();
    
    // Display local full-screen notification
    await NotificationService().showJobAlertNotification(message.data);
  }
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();

  static const String channelId = 'job_alerts_channel';
  static const String channelName = 'Incoming Job Alerts';
  static const String channelDescription = 'High-priority notifications for new customer service requests';

  GlobalKey<NavigatorState>? navigatorKey;

  void setNavigatorKey(GlobalKey<NavigatorState> key) {
    navigatorKey = key;
  }

  /// Initialize Firebase messaging and notification channels
  Future<void> initialize({GlobalKey<NavigatorState>? navKey}) async {
    if (navKey != null) {
      navigatorKey = navKey;
    }

    try {
      // Request push notification permissions
      NotificationSettings settings = await _fcm.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
        criticalAlert: true,
      );

      debugPrint('[FCM] Permission status: ${settings.authorizationStatus}');

      // Configure Android local notifications channel with custom raw sound
      const AndroidInitializationSettings androidSettings =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      const DarwinInitializationSettings iosSettings = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );

      const InitializationSettings initSettings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );

      await _localNotifications.initialize(
        initSettings,
        onDidReceiveNotificationResponse: _onNotificationTapped,
      );

      // Create Android Notification Channel with custom raw sound & maximum importance
      const AndroidNotificationChannel androidChannel = AndroidNotificationChannel(
        channelId,
        channelName,
        description: channelDescription,
        importance: Importance.max,
        playSound: true,
        sound: RawResourceAndroidNotificationSound('incoming_job_ringtone'),
        enableVibration: true,
        enableLights: true,
        showBadge: true,
      );

      await _localNotifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(androidChannel);

      // Listen for FCM foreground messages
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

      // When notification opened from terminated or background state
      FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpenedApp);

      // Sync device FCM Token with backend
      await syncTokenWithBackend();

      // Listen for token refreshes
      _fcm.onTokenRefresh.listen((newToken) {
        syncTokenWithBackend(token: newToken);
      });
    } catch (e) {
      debugPrint('[NotificationService] Initialization warning: $e');
    }
  }

  /// Syncs FCM token to Spring Boot backend
  Future<void> syncTokenWithBackend({String? token}) async {
    try {
      final fcmToken = token ?? await _fcm.getToken();
      if (fcmToken != null && fcmToken.isNotEmpty) {
        debugPrint('[FCM] Registering Token with Backend: $fcmToken');
        final dio = DioClient().dio;
        await dio.post(
          '${AppConfig.apiBaseUrl}/technician/fcm-token',
          data: {'fcmToken': fcmToken},
        );
        debugPrint('[FCM] Token synchronized with backend successfully.');
      }
    } catch (e) {
      debugPrint('[FCM] Error registering token with backend: $e');
    }
  }

  /// Handles FCM messages received while the app is in the foreground
  void _handleForegroundMessage(RemoteMessage message) {
    debugPrint('[FCM Foreground] Received: ${message.data}');
    final data = message.data;

    if (data['type'] == 'NEW_JOB_ALERT') {
      // 1. Play loud looping audio & continuous vibration
      AudioAlertService().startJobAlertRingtone();

      // 2. Display local notification banner
      showJobAlertNotification(data);

      // 3. Pop up Full-Screen Incoming Job Alert overlay
      _showIncomingJobModal(data);
    }
  }

  void _handleMessageOpenedApp(RemoteMessage message) {
    debugPrint('[FCM] Notification opened by user: ${message.data}');
    if (message.data['type'] == 'NEW_JOB_ALERT') {
      _showIncomingJobModal(message.data);
    }
  }

  void _onNotificationTapped(NotificationResponse response) {
    if (response.payload != null) {
      try {
        final Map<String, dynamic> data = jsonDecode(response.payload!);
        if (data['type'] == 'NEW_JOB_ALERT') {
          _showIncomingJobModal(data);
        }
      } catch (e) {
        debugPrint('[NotificationService] Payload parse error: $e');
      }
    }
  }

  /// Displays local full-screen notification banner with custom sound
  Future<void> showJobAlertNotification(Map<String, dynamic> data) async {
    final payout = data['payout'] ?? '0';
    final serviceType = data['serviceType'] ?? 'Service Request';
    final distanceKm = data['distanceKm'] ?? '0';

    final androidDetails = AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: channelDescription,
      importance: Importance.max,
      priority: Priority.high,
      sound: const RawResourceAndroidNotificationSound('incoming_job_ringtone'),
      playSound: true,
      enableVibration: true,
      fullScreenIntent: true,
      category: AndroidNotificationCategory.call,
      visibility: NotificationVisibility.public,
      styleInformation: BigTextStyleInformation(
        '$serviceType ($distanceKm km away)\nExpected Payout: ₹$payout',
        contentTitle: '🔔 New Job Alert - ₹$payout',
      ),
    );

    const iosDetails = DarwinNotificationDetails(
      sound: 'incoming_job_ringtone.wav',
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      '🔔 New Job Alert - ₹$payout',
      '$serviceType • $distanceKm km away',
      notificationDetails,
      payload: jsonEncode(data),
    );
  }

  /// Displays the full-screen pulsating modal overlay
  void _showIncomingJobModal(Map<String, dynamic> data) {
    if (navigatorKey?.currentContext == null) {
      debugPrint('[NotificationService] Navigator context not available.');
      return;
    }

    final context = navigatorKey!.currentContext!;
    IncomingJobAlertOverlay.show(
      context: context,
      proposalId: data['proposalId']?.toString() ?? '',
      bookingId: data['bookingId']?.toString() ?? '',
      serviceType: data['serviceType']?.toString() ?? 'Repair & Maintenance',
      customerName: data['customerName']?.toString() ?? 'Customer',
      customerAddress: data['customerAddress']?.toString() ?? 'Nearby Address',
      distanceKm: data['distanceKm']?.toString() ?? '1.5',
      payout: data['payout']?.toString() ?? '500',
      timeoutSeconds: int.tryParse(data['timeoutSeconds']?.toString() ?? '45') ?? 45,
    );
  }
}
