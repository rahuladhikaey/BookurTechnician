import 'package:flutter/foundation.dart';

class AppConfig {
  // Firebase Spark Free Project Configuration
  static const bool isFirebasePrimary = true;
  static const String firebaseProjectId = 'bookmytechnician-53d94';

  // Legacy Cloud Functions constants (require Firebase Blaze plan; not used by default on Spark Free)
  static const String functionsProdUrl =
      'https://asia-south1-bookmytechnician-53d94.cloudfunctions.net/api';
  static const String functionsEmulatorUrl =
      'http://10.0.2.2:5001/bookmytechnician-53d94/asia-south1/api';
  static const String functionsWifiUrl =
      'http://192.168.1.3:5001/bookmytechnician-53d94/asia-south1/api';

  // Render Backend URL injected via --dart-define=RENDER_API_URL=https://<service>.onrender.com
  static const String renderApiBaseUrl =
      String.fromEnvironment('RENDER_API_URL', defaultValue: '');
  static const String prodApiBaseUrl =
      String.fromEnvironment('API_BASE_URL', defaultValue: renderApiBaseUrl);
  static const String _functionsUrlOverride =
      String.fromEnvironment('FUNCTIONS_API_URL', defaultValue: '');

  @visibleForTesting
  static String? testBackendBaseUrlOverride;

  static String _stripTrailingSlash(String url) =>
      url.trim().replaceAll(RegExp(r'/+$'), '');

  /// Active Render / trusted Node backend URL when configured at build time.
  /// Remains empty ('') until a real deployment URL is injected.
  static String get backendBaseUrl {
    String? debugOverride;
    assert(() {
      debugOverride = testBackendBaseUrlOverride;
      return true;
    }());
    if (debugOverride != null) {
      final cleanOverride = _stripTrailingSlash(debugOverride!);
      if (cleanOverride.isNotEmpty && !cleanOverride.contains('cloudfunctions.net')) {
        return cleanOverride;
      }
    }
    for (final raw in [renderApiBaseUrl, prodApiBaseUrl, _functionsUrlOverride]) {
      final clean = _stripTrailingSlash(raw);
      if (clean.isNotEmpty && !clean.contains('cloudfunctions.net')) {
        return clean;
      }
    }
    return '';
  }

  static bool get hasConfiguredBackend => backendBaseUrl.isNotEmpty;

  static String get functionsApiUrl => backendBaseUrl;

  static const String renderFallbackApiUrl = '';
  static const String localWifiApiBaseUrl = 'http://192.168.1.3:4000/api/v1';
  static const String localApiBaseUrl = 'http://10.0.2.2:4000/api/v1';

  static String get apiBaseUrl => backendBaseUrl;
  static String get baseUrl => backendBaseUrl;

  static const String socketUrl = '';
  static const String prodSocketUrl = '';
  static const String localSocketUrl = 'http://192.168.1.3:4000';
  static const String wsEndpoint = '';

  // Request timeout sized for Render free-tier cold-start resilience
  static const Duration requestTimeout = Duration(seconds: 15);
}
