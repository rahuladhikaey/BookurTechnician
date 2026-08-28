class AppConfig {
  // Live Production & Local Dev Backend Endpoints
  static const String localApiBaseUrl = 'http://10.0.2.2:4000/api/v1';
  static const String prodApiBaseUrl = 'https://api.bookurtechnician.online/api/v1';
  static const String apiBaseUrl = 'http://localhost:4000/api/v1';
  static const String renderFallbackApiUrl = 'https://bookurtechnician-backend.onrender.com/api/v1';
  
  static const String localSocketUrl = 'http://10.0.2.2:4000';
  static const String socketUrl = 'http://localhost:4000';
  static const String prodSocketUrl = 'https://api.bookurtechnician.online';
  static const String wsEndpoint = 'http://localhost:4000/ws';

  // Request timeout (accommodates cold-start wake-up)
  static const Duration requestTimeout = Duration(seconds: 45);
}

