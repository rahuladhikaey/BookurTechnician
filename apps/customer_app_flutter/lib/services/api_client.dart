import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiClient {
  static const String baseUrl = 'https://api.bookurtechnician.online/api/v1';
  static const String fallbackLocalUrl = 'http://10.0.2.2:8080/api/v1';

  static String get activeBaseUrl => kDebugMode ? fallbackLocalUrl : baseUrl;

  static Future<String?> getAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('bt_access_token');
  }

  static Future<String?> getRefreshToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('bt_refresh_token');
  }

  static Future<void> saveTokens({required String accessToken, required String refreshToken}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('bt_access_token', accessToken);
    await prefs.setString('bt_refresh_token', refreshToken);
  }

  static Future<void> clearTokens() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('bt_access_token');
    await prefs.remove('bt_refresh_token');
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

  static Future<http.Response> get(String endpoint) async {
    String? token = await getAccessToken();
    var uri = Uri.parse('$activeBaseUrl$endpoint');
    var response = await http.get(uri, headers: _buildHeaders(token)).timeout(const Duration(seconds: 10));

    if (response.statusCode == 401) {
      final refreshed = await _attemptRefreshToken();
      if (refreshed) {
        token = await getAccessToken();
        response = await http.get(uri, headers: _buildHeaders(token)).timeout(const Duration(seconds: 10));
      }
    }
    return response;
  }

  static Future<http.Response> post(String endpoint, Map<String, dynamic> body) async {
    String? token = await getAccessToken();
    var uri = Uri.parse('$activeBaseUrl$endpoint');
    var response = await http.post(
      uri,
      headers: _buildHeaders(token),
      body: jsonEncode(body),
    ).timeout(const Duration(seconds: 10));

    if (response.statusCode == 401) {
      final refreshed = await _attemptRefreshToken();
      if (refreshed) {
        token = await getAccessToken();
        response = await http.post(
          uri,
          headers: _buildHeaders(token),
          body: jsonEncode(body),
        ).timeout(const Duration(seconds: 10));
      }
    }
    return response;
  }

  static Future<http.Response> put(String endpoint, Map<String, dynamic> body) async {
    String? token = await getAccessToken();
    var uri = Uri.parse('$activeBaseUrl$endpoint');
    var response = await http.put(
      uri,
      headers: _buildHeaders(token),
      body: jsonEncode(body),
    ).timeout(const Duration(seconds: 10));

    if (response.statusCode == 401) {
      final refreshed = await _attemptRefreshToken();
      if (refreshed) {
        token = await getAccessToken();
        response = await http.put(
          uri,
          headers: _buildHeaders(token),
          body: jsonEncode(body),
        ).timeout(const Duration(seconds: 10));
      }
    }
    return response;
  }

  static Future<http.Response> patch(String endpoint, Map<String, dynamic> body) async {
    String? token = await getAccessToken();
    var uri = Uri.parse('$activeBaseUrl$endpoint');
    var response = await http.patch(
      uri,
      headers: _buildHeaders(token),
      body: jsonEncode(body),
    ).timeout(const Duration(seconds: 10));

    if (response.statusCode == 401) {
      final refreshed = await _attemptRefreshToken();
      if (refreshed) {
        token = await getAccessToken();
        response = await http.patch(
          uri,
          headers: _buildHeaders(token),
          body: jsonEncode(body),
        ).timeout(const Duration(seconds: 10));
      }
    }
    return response;
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
    } catch (_) {}

    await clearTokens();
    return false;
  }
}
