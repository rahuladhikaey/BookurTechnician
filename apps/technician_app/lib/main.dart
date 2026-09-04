import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'app/app.dart';
import 'core/security/secure_storage.dart';
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
  try {
    final savedUserId = await SecureStorage().getUserId();
    if (savedUserId != null && savedUserId.isNotEmpty) {
      TechnicianSocketService().connect(technicianId: savedUserId, category: 'electrician');
    }
  } catch (e) {
    debugPrint('Socket lazy-connect notice: $e');
  }

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
