import 'dart:async';
import 'dart:convert';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_config.dart';

class LocationTrackingService {
  static final LocationTrackingService _instance = LocationTrackingService._internal();
  factory LocationTrackingService() => _instance;
  LocationTrackingService._internal();

  static const String notificationChannelId = 'partner_duty_channel';
  static const int notificationId = 888;

  Future<void> initializeService() async {
    try {
      final service = FlutterBackgroundService();

      // Android notification channel setup
      const AndroidNotificationChannel channel = AndroidNotificationChannel(
        notificationChannelId,
        'Partner Duty Active',
        description: 'Ongoing foreground notification for live technician location sync',
        importance: Importance.low,
      );

      final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

      await flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);

      await service.configure(
        androidConfiguration: AndroidConfiguration(
          onStart: onStart,
          autoStart: false,
          isForegroundMode: true,
          notificationChannelId: notificationChannelId,
          initialNotificationTitle: 'Partner Duty Active',
          initialNotificationContent: 'GPS tracking initializing...',
          foregroundServiceNotificationId: notificationId,
          foregroundServiceTypes: [AndroidForegroundType.location],
        ),
        iosConfiguration: IosConfiguration(
          autoStart: false,
          onForeground: onStart,
          onBackground: onIosBackground,
        ),
      );
    } catch (e) {
      debugPrint('[LocationTrackingService] initializeService error: $e');
    }
  }

  Future<bool> startTracking() async {
    try {
      final service = FlutterBackgroundService();
      final isRunning = await service.isRunning();
      if (!isRunning) {
        return await service.startService();
      }
      return true;
    } catch (e) {
      debugPrint('[LocationTrackingService] startTracking error: $e');
      return false;
    }
  }

  Future<void> stopTracking() async {
    try {
      final service = FlutterBackgroundService();
      final isRunning = await service.isRunning();
      if (isRunning) {
        service.invoke('stopService');
      }
    } catch (e) {
      debugPrint('[LocationTrackingService] stopTracking error: $e');
    }
  }

  Future<bool> isTrackingRunning() async {
    try {
      final service = FlutterBackgroundService();
      return await service.isRunning();
    } catch (e) {
      debugPrint('[LocationTrackingService] isTrackingRunning error: $e');
      return false;
    }
  }

  @pragma('vm:entry-point')
  static Future<bool> onIosBackground(ServiceInstance service) async {
    DartPluginRegistrant.ensureInitialized();
    return true;
  }

  @pragma('vm:entry-point')
  static Future<void> onStart(ServiceInstance service) async {
    DartPluginRegistrant.ensureInitialized();

    if (service is AndroidServiceInstance) {
      service.on('setAsForeground').listen((event) {
        service.setAsForegroundService();
      });

      service.on('setAsBackground').listen((event) {
        service.setAsBackgroundService();
      });
    }

    service.on('stopService').listen((event) {
      service.stopSelf();
    });

    // ─── PERIODIC 30-SECOND LOCATION SYNC TIMER ───
    Timer.periodic(const Duration(seconds: 30), (timer) async {
      try {
        final position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: const Duration(seconds: 10),
        );

        final prefs = await SharedPreferences.getInstance();
        final token = prefs.getString('auth_token');

        if (token != null && token.isNotEmpty) {
          final uri = Uri.parse('${AppConfig.apiBaseUrl}/technician/location');
          final payload = jsonEncode({
            'latitude': position.latitude,
            'longitude': position.longitude,
            'speed': position.speed,
            'heading': position.heading,
            'timestamp': DateTime.now().toIso8601String(),
          });

          await http.post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: payload,
          ).timeout(const Duration(seconds: 8));
        }

        // Format live timestamp
        final timeStr = DateFormat('hh:mm:ss a').format(DateTime.now());

        if (service is AndroidServiceInstance) {
          if (await service.isForegroundService()) {
            service.setForegroundNotificationInfo(
              title: 'Partner Duty Active',
              content: 'Live GPS: ${position.latitude.toStringAsFixed(4)}°, ${position.longitude.toStringAsFixed(4)}° • $timeStr',
            );
          }
        }

        // Broadcast to in-app listeners
        service.invoke('location_update', {
          'latitude': position.latitude,
          'longitude': position.longitude,
          'speed': position.speed,
          'heading': position.heading,
          'timestamp': DateTime.now().toIso8601String(),
        });
      } catch (e) {
        debugPrint('Background location sync error: $e');
      }
    });
  }
}
