class AppConfig {
  // Pure Firebase Architecture Configuration
  static const bool isFirebasePrimary = true;
  static const String firebaseProjectId = 'bookmytechnician-53d94';

  // Live Production & Local Dev Backend Endpoints (Legacy compatibility shims)
  static const String prodApiBaseUrl = '';
  static const String renderFallbackApiUrl = '';
  static const String renderApiBaseUrl = '';
  static const String localWifiApiBaseUrl = 'http://192.168.1.3:4000/api/v1';
  static const String localApiBaseUrl = 'http://10.0.2.2:4000/api/v1';
  
  // Primary Live Production Backend Gateway (Empty in Firebase-first mode)
  static const String apiBaseUrl = '';
  static const String baseUrl = apiBaseUrl;
  
  static const String socketUrl = '';
  static const String prodSocketUrl = '';
  static const String localSocketUrl = 'http://192.168.1.3:4000';
  static const String wsEndpoint = '';

  // Request timeout (optimized for quick failover across candidates)
  static const Duration requestTimeout = Duration(seconds: 4);
}


