import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_config.dart';
import 'firestore_rest_client.dart';

class ApiClient {
  static String? _cachedWorkingBaseUrl;
  static const String _keyWorkingBaseUrl = 'bt_working_base_url';

  static const String _keyAccessToken = 'bt_access_token';
  static const String _keyRefreshToken = 'bt_refresh_token';
  static const String _keyUserId = 'bt_user_id';
  static const String _keyUserName = 'bt_user_name';
  static const String _keyUserPhone = 'bt_user_phone';
  static const String _keyUserEmail = 'bt_user_email';
  static const String _keyUserProfileJson = 'bt_user_profile_json';

  /// Active API Base URL derived from cached working base URL or AppConfig
  static String get activeBaseUrl => _cachedWorkingBaseUrl ?? AppConfig.apiBaseUrl;

  static List<String> get _candidateBaseUrls {
    if (AppConfig.isFirebasePrimary || FirestoreRestClient.mockHttpHandler != null) {
      return const [];
    }
    final list = <String>[];
    for (final u in [
      activeBaseUrl,
      AppConfig.prodApiBaseUrl,
      AppConfig.localWifiApiBaseUrl,
      AppConfig.localApiBaseUrl,
    ]) {
      if (u.isNotEmpty &&
          !u.contains('onrender.com') &&
          !u.contains('api.bookurtechnician.online') &&
          !list.contains(u)) {
        list.add(u);
      }
    }
    return list;
  }

  static void _updateWorkingBaseUrl(String url) {
    if (_cachedWorkingBaseUrl != url) {
      _cachedWorkingBaseUrl = url;
      SharedPreferences.getInstance().then((prefs) {
        prefs.setString(_keyWorkingBaseUrl, url);
      }).catchError((_) {});
    }
  }

  static Future<void> initWorkingBaseUrl() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_keyWorkingBaseUrl);
      if (saved != null && saved.isNotEmpty) {
        _cachedWorkingBaseUrl = saved;
      }
    } catch (_) {}
  }

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

  static const Duration _fastTimeout = Duration(milliseconds: 3500);

  /// Validates whether an HTTP response is an authoritative response from our application server,
  /// rather than an infrastructure 404/5xx failure or reverse proxy error.
  static bool _isAuthoritativeResponse(http.Response response, String endpoint) {
    final status = response.statusCode;
    // 2xx Success: Always authoritative
    if (status >= 200 && status < 300) return true;

    // 404 Not Found from an unconfigured host or missing proxy route is NOT authoritative
    if (status == 404) {
      final contentType = response.headers['content-type'] ?? '';
      if (!contentType.contains('application/json')) return false;
      try {
        final decoded = jsonDecode(response.body);
        if (decoded is Map && (decoded.containsKey('code') || decoded.containsKey('success'))) {
          return true; // Authoritative application-level 404
        }
      } catch (_) {}
      return false; // Infrastructure / Express route 404 ("Not Found" or "Cannot POST ...")
    }

    // 4xx Client Validation Errors (400, 401, 403, 409 Conflict, 422, 429):
    // Authoritative server-side validations (e.g. DUPLICATE_BOOKING, TECHNICIAN_BUSY_CONFLICT)
    // that must be respected and NEVER bypassed through fallback retries.
    if (status >= 400 && status < 500) {
      return true;
    }

    // 5xx Server errors / Gateway timeouts: Failover to next candidate or fallback
    return false;
  }

  static Future<http.Response> get(String endpoint) async {
    String? token = await getAccessToken();

    for (final base in _candidateBaseUrls) {
      try {
        final uri = Uri.parse('$base$endpoint');
        var response = await http.get(uri, headers: _buildHeaders(token)).timeout(_fastTimeout);

        if (response.statusCode == 401) {
          final refreshed = await _attemptRefreshToken();
          if (refreshed) {
            token = await getAccessToken();
            response = await http.get(uri, headers: _buildHeaders(token)).timeout(_fastTimeout);
          }
        }
        if (_isAuthoritativeResponse(response, endpoint)) {
          if (response.statusCode < 400) {
            _updateWorkingBaseUrl(base);
          }
          return response;
        }
      } catch (e) {
        debugPrint('[ApiClient] GET $base$endpoint failed: $e. Retrying candidate...');
      }
    }

    debugPrint('🔥 [ApiClient] Serving GET $endpoint directly via Firebase Cloud Firestore');
    return FirestoreRestClient.handleRequest('GET', endpoint);
  }

  static Future<http.Response> post(String endpoint, Map<String, dynamic> body) async {
    String? token = await getAccessToken();

    for (final base in _candidateBaseUrls) {
      try {
        final uri = Uri.parse('$base$endpoint');
        var response = await http.post(
          uri,
          headers: _buildHeaders(token),
          body: jsonEncode(body),
        ).timeout(_fastTimeout);

        if (response.statusCode == 401) {
          final refreshed = await _attemptRefreshToken();
          if (refreshed) {
            token = await getAccessToken();
            response = await http.post(
              uri,
              headers: _buildHeaders(token),
              body: jsonEncode(body),
            ).timeout(_fastTimeout);
          }
        }
        if (_isAuthoritativeResponse(response, endpoint)) {
          if (response.statusCode < 400) {
            _updateWorkingBaseUrl(base);
          }
          return response;
        }
      } catch (e) {
        debugPrint('[ApiClient] POST $base$endpoint failed: $e. Retrying candidate...');
      }
    }

    debugPrint('🔥 [ApiClient] Serving POST $endpoint directly via Firebase Cloud Firestore');
    return FirestoreRestClient.handleRequest('POST', endpoint, body);
  }

  static Future<http.Response> put(String endpoint, Map<String, dynamic> body) async {
    String? token = await getAccessToken();

    for (final base in _candidateBaseUrls) {
      try {
        final uri = Uri.parse('$base$endpoint');
        var response = await http.put(
          uri,
          headers: _buildHeaders(token),
          body: jsonEncode(body),
        ).timeout(_fastTimeout);

        if (response.statusCode == 401) {
          final refreshed = await _attemptRefreshToken();
          if (refreshed) {
            token = await getAccessToken();
            response = await http.put(
              uri,
              headers: _buildHeaders(token),
              body: jsonEncode(body),
            ).timeout(_fastTimeout);
          }
        }
        if (_isAuthoritativeResponse(response, endpoint)) {
          if (response.statusCode < 400) {
            _updateWorkingBaseUrl(base);
          }
          return response;
        }
      } catch (e) {
        debugPrint('[ApiClient] PUT $base$endpoint failed: $e. Retrying candidate...');
      }
    }

    debugPrint('🔥 [ApiClient] Serving PUT $endpoint directly via Firebase Cloud Firestore');
    return FirestoreRestClient.handleRequest('PUT', endpoint, body);
  }

  static Future<http.Response> patch(String endpoint, Map<String, dynamic> body) async {
    String? token = await getAccessToken();

    for (final base in _candidateBaseUrls) {
      try {
        final uri = Uri.parse('$base$endpoint');
        var response = await http.patch(
          uri,
          headers: _buildHeaders(token),
          body: jsonEncode(body),
        ).timeout(_fastTimeout);

        if (response.statusCode == 401) {
          final refreshed = await _attemptRefreshToken();
          if (refreshed) {
            token = await getAccessToken();
            response = await http.patch(
              uri,
              headers: _buildHeaders(token),
              body: jsonEncode(body),
            ).timeout(_fastTimeout);
          }
        }
        if (_isAuthoritativeResponse(response, endpoint)) {
          if (response.statusCode < 400) {
            _updateWorkingBaseUrl(base);
          }
          return response;
        }
      } catch (e) {
        debugPrint('[ApiClient] PATCH $base$endpoint failed: $e. Retrying candidate...');
      }
    }

    debugPrint('🔥 [ApiClient] Serving PATCH $endpoint directly via Firebase Cloud Firestore');
    return FirestoreRestClient.handleRequest('PATCH', endpoint, body);
  }

  static Future<http.Response> delete(String endpoint) async {
    String? token = await getAccessToken();

    for (final base in _candidateBaseUrls) {
      try {
        final uri = Uri.parse('$base$endpoint');
        var response = await http.delete(
          uri,
          headers: _buildHeaders(token),
        ).timeout(_fastTimeout);

        if (response.statusCode == 401) {
          final refreshed = await _attemptRefreshToken();
          if (refreshed) {
            token = await getAccessToken();
            response = await http.delete(
              uri,
              headers: _buildHeaders(token),
            ).timeout(_fastTimeout);
          }
        }
        if (_isAuthoritativeResponse(response, endpoint)) {
          if (response.statusCode < 400) {
            _updateWorkingBaseUrl(base);
          }
          return response;
        }
      } catch (e) {
        debugPrint('[ApiClient] DELETE $base$endpoint failed: $e. Retrying candidate...');
      }
    }

    debugPrint('🔥 [ApiClient] Serving DELETE $endpoint directly via Firebase Cloud Firestore');
    return FirestoreRestClient.handleRequest('DELETE', endpoint);
  }

  /// Permanent Account Deletion (Google Play & Indus Appstore Compliance)
  static Future<Map<String, dynamic>> deleteAccount({String reason = 'User requested account closure'}) async {
    try {
      final session = await getUserSession();
      final userId = session['userId'];
      final phone = session['phone'];
      final response = await post('/customer/account/delete', {
        'userId': userId,
        'phone': phone,
        'reason': reason,
      });
      if (response.statusCode >= 200 && response.statusCode < 300) {
        await clearTokens();
        return jsonDecode(response.body);
      } else {
        final err = jsonDecode(response.body);
        throw Exception(err['error'] ?? 'Failed to delete account');
      }
    } catch (e) {
      debugPrint('[ApiClient] deleteAccount error: $e');
      rethrow;
    }
  }

  static Future<bool> _attemptRefreshToken() async {
    final refreshToken = await getRefreshToken();
    if (refreshToken == null || refreshToken.isEmpty) return false;

    for (final base in _candidateBaseUrls) {
      try {
        final uri = Uri.parse('$base/auth/refresh-token');
        final res = await http.post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'refreshToken': refreshToken}),
        ).timeout(const Duration(seconds: 8));

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
        } else if (res.statusCode == 401 || res.statusCode == 403) {
          // Token is definitively invalid/expired on the server
          await clearTokens();
          return false;
        }
      } catch (e) {
        debugPrint('[ApiClient] Token refresh attempt failed: $e');
      }
    }

    // Do NOT clear tokens on network timeouts or temporary server offline
    return false;
  }
}
