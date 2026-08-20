class AppConfig {
  // Live Production Backend Endpoints (Deployed on Render)
  static const String apiBaseUrl = 'https://api.bookurtechnician.online/api/v1';
  static const String renderFallbackApiUrl = 'https://bookurtechnician-backend.onrender.com/api/v1';
  static const String socketUrl = 'https://api.bookurtechnician.online';
  static const String wsEndpoint = 'https://api.bookurtechnician.online/ws';

  // Request timeout (accommodates cold-start wake-up)
  static const Duration requestTimeout = Duration(seconds: 45);
}

