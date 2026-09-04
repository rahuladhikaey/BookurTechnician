class AppConfig {
  // Live Production & Local Dev Backend Endpoints
  static const String prodApiBaseUrl = 'https://api.bookurtechnician.online/api/v1';
  static const String renderFallbackApiUrl = 'https://bookurtechnician-backend.onrender.com/api/v1';
  static const String renderApiBaseUrl = 'https://bookurtechnician.onrender.com/api/v1';
  static const String localWifiApiBaseUrl = 'http://192.168.1.3:4000/api/v1';
  static const String localApiBaseUrl = 'http://10.0.2.2:4000/api/v1';
  
  // Primary Live Production Backend Gateway
  static const String apiBaseUrl = 'https://api.bookurtechnician.online/api/v1';
  static const String baseUrl = apiBaseUrl;
  
  static const String socketUrl = 'https://api.bookurtechnician.online';
  static const String prodSocketUrl = 'https://api.bookurtechnician.online';
  static const String localSocketUrl = 'http://192.168.1.3:4000';
  static const String wsEndpoint = 'https://api.bookurtechnician.online/ws';

  // Request timeout (optimized for quick failover across candidates)
  static const Duration requestTimeout = Duration(seconds: 8);
}

