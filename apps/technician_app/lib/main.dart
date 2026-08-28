import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'app/app.dart';
import 'core/services/location_tracking_service.dart';
import 'core/services/notification_service.dart';
import 'core/services/socket_service.dart';

final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    await Firebase.initializeApp();
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    await NotificationService().initialize(navKey: rootNavigatorKey);
  } catch (e) {
    debugPrint('Firebase / Notification initialization warning: $e');
  }

  // Initialize socket dispatch & ringing listener
  TechnicianSocketService().setNavigatorKey(rootNavigatorKey);
  TechnicianSocketService().connect(technicianId: 'tech-001', category: 'electrician');

  try {
    await LocationTrackingService().initializeService();
  } catch (e) {
    debugPrint('LocationTrackingService initialization warning: $e');
  }

  runApp(
    const ProviderScope(
      child: TechnicianApp(),
    ),
  );
}
