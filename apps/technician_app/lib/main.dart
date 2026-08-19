import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app/app.dart';
import 'core/services/location_tracking_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
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
