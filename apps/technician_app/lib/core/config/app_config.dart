class AppConfig {
  // Live Production & Local Dev Backend Endpoints
  static const String prodApiBaseUrl = 'https://api.bookurtechnician.online/api/v1';
  static const String renderFallbackApiUrl = 'https://bookurtechnician-backend.onrender.com/api/v1';
  static const String renderApiBaseUrl = 'https://bookurtechnician.onrender.com/api/v1';
  static const String localWifiApiBaseUrl = 'http://192.168.1.3:4000/api/v1';
  static const String localApiBaseUrl = 'http://10.0.2.2:4000/api/v1';
  
  // Primary Live Production Backend Gateway
  static const String apiBaseUrl = 'https://api.bookurtechnician.online/api/v1';
  
  static const String socketUrl = 'https://api.bookurtechnician.online';
  static const String prodSocketUrl = 'https://api.bookurtechnician.online';
  static const String localSocketUrl = 'http://192.168.1.3:4000';
  static const String wsEndpoint = 'https://api.bookurtechnician.online/ws';

  // Working Base URL cache for instant zero-latency routing
  static String activeWorkingBaseUrl = prodApiBaseUrl;

  static void updateWorkingBaseUrl(String url) {
    if (url.isNotEmpty && activeWorkingBaseUrl != url) {
      activeWorkingBaseUrl = url;
    }
  }

  // Candidate URLs for robust failover (ordered dynamically with active working URL first)
  static List<String> get candidateBaseUrls {
    final list = <String>[activeWorkingBaseUrl];
    for (final u in [
      prodApiBaseUrl,
      renderApiBaseUrl,
      renderFallbackApiUrl,
      localWifiApiBaseUrl,
      localApiBaseUrl,
    ]) {
      if (!list.contains(u)) {
        list.add(u);
      }
    }
    return list;
  }

  static const List<String> candidateSocketUrls = [
    'https://api.bookurtechnician.online',
    'https://bookurtechnician.onrender.com',
    'https://bookurtechnician-backend.onrender.com',
    'http://192.168.1.3:4000',
    'http://10.0.2.2:4000',
  ];

  // Request timeout (optimized for instant UI responses)
  static const Duration requestTimeout = Duration(milliseconds: 4000);
}

