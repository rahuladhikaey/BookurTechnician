import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_config.dart';

class ApiClient {
  /// Active API Base URL derived from AppConfig
  static String get activeBaseUrl => AppConfig.apiBaseUrl;

  static const String _keyAccessToken = 'bt_access_token';
  static const String _keyRefreshToken = 'bt_refresh_token';
  static const String _keyUserId = 'bt_user_id';
  static const String _keyUserName = 'bt_user_name';
  static const String _keyUserPhone = 'bt_user_phone';
  static const String _keyUserEmail = 'bt_user_email';
  static const String _keyUserProfileJson = 'bt_user_profile_json';

  static Future<String?> getAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyAccessToken);
  }

  static Future<String?> getRefreshToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyRefreshToken);
  }

  static Future<void> saveTokens({required String accessToken, required String refreshToken}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyAccessToken, accessToken);
    await prefs.setString(_keyRefreshToken, refreshToken);
  }

  static Future<void> saveUserSession({
    required String accessToken,
    required String refreshToken,
    required String userId,
    required String name,
    required String phone,
    required String email,
    Map<String, dynamic>? profileJson,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyAccessToken, accessToken);
    await prefs.setString(_keyRefreshToken, refreshToken);
    await prefs.setString(_keyUserId, userId);
    await prefs.setString(_keyUserName, name);
    await prefs.setString(_keyUserPhone, phone);
    await prefs.setString(_keyUserEmail, email);
    if (profileJson != null) {
      await prefs.setString(_keyUserProfileJson, jsonEncode(profileJson));
    }
  }

  static Future<Map<String, String?>> getUserSession() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'accessToken': prefs.getString(_keyAccessToken),
      'refreshToken': prefs.getString(_keyRefreshToken),
      'userId': prefs.getString(_keyUserId),
      'name': prefs.getString(_keyUserName),
      'phone': prefs.getString(_keyUserPhone),
      'email': prefs.getString(_keyUserEmail),
      'profileJson': prefs.getString(_keyUserProfileJson),
    };
  }

  static Future<void> clearTokens() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyAccessToken);
    await prefs.remove(_keyRefreshToken);
    await prefs.remove(_keyUserId);
    await prefs.remove(_keyUserName);
    await prefs.remove(_keyUserPhone);
    await prefs.remove(_keyUserEmail);
    await prefs.remove(_keyUserProfileJson);
  }

  static Map<String, String> _buildHeaders(String? token) {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  static List<String> get _candidateBaseUrls => [
    AppConfig.apiBaseUrl,
    AppConfig.renderFallbackApiUrl,
  ];

  static Future<http.Response> get(String endpoint) async {
    String? token = await getAccessToken();
    Exception? lastException;

    for (final base in _candidateBaseUrls) {
      try {
        final uri = Uri.parse('$base$endpoint');
        var response = await http.get(uri, headers: _buildHeaders(token)).timeout(AppConfig.requestTimeout);

        if (response.statusCode == 401) {
          final refreshed = await _attemptRefreshToken();
          if (refreshed) {
            token = await getAccessToken();
            response = await http.get(uri, headers: _buildHeaders(token)).timeout(AppConfig.requestTimeout);
          }
        }
        if (response.statusCode < 500) {
          return response;
        }
      } catch (e) {
        lastException = e is Exception ? e : Exception(e.toString());
        debugPrint('[ApiClient] GET $base$endpoint failed: $e. Retrying candidate...');
      }
    }

    if (lastException != null) throw lastException;
    return http.Response('{"status":"error","message":"Server unreachable"}', 503);
  }

  static Future<http.Response> post(String endpoint, Map<String, dynamic> body) async {
    String? token = await getAccessToken();
    Exception? lastException;

    for (final base in _candidateBaseUrls) {
      try {
        final uri = Uri.parse('$base$endpoint');
        var response = await http.post(
          uri,
          headers: _buildHeaders(token),
          body: jsonEncode(body),
        ).timeout(AppConfig.requestTimeout);

        if (response.statusCode == 401) {
          final refreshed = await _attemptRefreshToken();
          if (refreshed) {
            token = await getAccessToken();
            response = await http.post(
              uri,
              headers: _buildHeaders(token),
              body: jsonEncode(body),
            ).timeout(AppConfig.requestTimeout);
          }
        }
        if (response.statusCode < 500) {
          return response;
        }
      } catch (e) {
        lastException = e is Exception ? e : Exception(e.toString());
        debugPrint('[ApiClient] POST $base$endpoint failed: $e. Retrying candidate...');
      }
    }

    if (lastException != null) throw lastException;
    return http.Response('{"status":"error","message":"Server unreachable"}', 503);
  }

  static Future<http.Response> put(String endpoint, Map<String, dynamic> body) async {
    String? token = await getAccessToken();
    Exception? lastException;

    for (final base in _candidateBaseUrls) {
      try {
        final uri = Uri.parse('$base$endpoint');
        var response = await http.put(
          uri,
          headers: _buildHeaders(token),
          body: jsonEncode(body),
        ).timeout(AppConfig.requestTimeout);

        if (response.statusCode == 401) {
          final refreshed = await _attemptRefreshToken();
          if (refreshed) {
            token = await getAccessToken();
            response = await http.put(
              uri,
              headers: _buildHeaders(token),
              body: jsonEncode(body),
            ).timeout(AppConfig.requestTimeout);
          }
        }
        if (response.statusCode < 500) {
          return response;
        }
      } catch (e) {
        lastException = e is Exception ? e : Exception(e.toString());
        debugPrint('[ApiClient] PUT $base$endpoint failed: $e. Retrying candidate...');
      }
    }

    if (lastException != null) throw lastException;
    return http.Response('{"status":"error","message":"Server unreachable"}', 503);
  }

  static Future<http.Response> patch(String endpoint, Map<String, dynamic> body) async {
    String? token = await getAccessToken();
    Exception? lastException;

    for (final base in _candidateBaseUrls) {
      try {
        final uri = Uri.parse('$base$endpoint');
        var response = await http.patch(
          uri,
          headers: _buildHeaders(token),
          body: jsonEncode(body),
        ).timeout(AppConfig.requestTimeout);

        if (response.statusCode == 401) {
          final refreshed = await _attemptRefreshToken();
          if (refreshed) {
            token = await getAccessToken();
            response = await http.patch(
              uri,
              headers: _buildHeaders(token),
              body: jsonEncode(body),
            ).timeout(AppConfig.requestTimeout);
          }
        }
        if (response.statusCode < 500) {
          return response;
        }
      } catch (e) {
        lastException = e is Exception ? e : Exception(e.toString());
        debugPrint('[ApiClient] PATCH $base$endpoint failed: $e. Retrying candidate...');
      }
    }

    if (lastException != null) throw lastException;
    return http.Response('{"status":"error","message":"Server unreachable"}', 503);
  }

  static Future<http.Response> delete(String endpoint) async {
    String? token = await getAccessToken();
    Exception? lastException;

    for (final base in _candidateBaseUrls) {
      try {
        final uri = Uri.parse('$base$endpoint');
        var response = await http.delete(
          uri,
          headers: _buildHeaders(token),
        ).timeout(AppConfig.requestTimeout);

        if (response.statusCode == 401) {
          final refreshed = await _attemptRefreshToken();
          if (refreshed) {
            token = await getAccessToken();
            response = await http.delete(
              uri,
              headers: _buildHeaders(token),
            ).timeout(AppConfig.requestTimeout);
          }
        }
        if (response.statusCode < 500) {
          return response;
        }
      } catch (e) {
        lastException = e is Exception ? e : Exception(e.toString());
        debugPrint('[ApiClient] DELETE $base$endpoint failed: $e. Retrying candidate...');
      }
    }

    if (lastException != null) throw lastException;
    return http.Response('{"status":"error","message":"Server unreachable"}', 503);
  }

  static Future<bool> _attemptRefreshToken() async {
    final refreshToken = await getRefreshToken();
    if (refreshToken == null || refreshToken.isEmpty) return false;

    try {
      final uri = Uri.parse('$activeBaseUrl/auth/refresh-token');
      final res = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'refreshToken': refreshToken}),
      ).timeout(const Duration(seconds: 5));

      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        final data = decoded['data'];
        if (data != null && data['accessToken'] != null) {
          await saveTokens(
            accessToken: data['accessToken'],
            refreshToken: data['refreshToken'] ?? refreshToken,
          );
          return true;
        }
      }
    } catch (e) {
      debugPrint('Token refresh failed: $e');
    }

    await clearTokens();
    return false;
  }
}
