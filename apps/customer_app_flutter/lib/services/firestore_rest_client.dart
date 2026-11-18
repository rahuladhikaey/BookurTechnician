import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_config.dart';
import 'email_service.dart';

/// Direct Cloud Firestore Client for BookUrTechnician Customer App
/// Project: bookmytechnician-53d94 (asia-south1)
class FirestoreRestClient {
  static const String projectId = 'bookmytechnician-53d94';
  static const String baseUrl =
      'https://firestore.googleapis.com/v1/projects/$projectId/databases/(default)/documents';
  static const String commitUrl =
      'https://firestore.googleapis.com/v1/projects/$projectId/databases/(default)/documents:commit';
  static const String documentNamePrefix =
      'projects/$projectId/databases/(default)/documents';
  static const String _firebaseWebApiKey = String.fromEnvironment(
    'FIREBASE_WEB_API_KEY',
    defaultValue: 'AIzaSyAhCvnUH_jA5bAhlGlIy3eX2lnM43gFRdE',
  );

  // Persistent SharedPreferences keys for Firebase Auth tokens ONLY
  // Strictly isolated from Render HS256 JWT keys (`bt_access_token`, `bt_refresh_token`)
  static const String _keyFbIdToken = 'bt_firebase_id_token';
  static const String _keyFbRefreshToken = 'bt_firebase_refresh_token';
  static const String _keyFbUid = 'bt_firebase_uid';
  static const String _keyFbExpiresAtMs = 'bt_firebase_expires_at_ms';
  static const String _keyCustomerSessionUid = 'bt_user_id';
  static const String _keyCustomerRenderToken = 'bt_access_token';

  static String? _fbIdToken;
  static String? _fbRefreshToken;
  static String? _fbUid;
  static DateTime? _fbTokenExpiresAt;

  @visibleForTesting
  static Future<http.Response> Function(
    String method,
    Uri uri, {
    Map<String, String>? headers,
    String? body,
  })? authHttpHandler;

  /// Ensure a token is a Firebase ID token (never a Render HS256 backend JWT).
  static bool isFirebaseIdTokenFormat(String? token) {
    if (token == null || token.trim().isEmpty) return false;
    final parts = token.trim().split('.');
    if (parts.length != 3) return false;
    try {
      final headerJson = utf8.decode(base64Url.decode(base64Url.normalize(parts[0])));
      final header = jsonDecode(headerJson);
      if (header is Map && header['alg']?.toString().toUpperCase() == 'HS256') {
        return false;
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<http.Response> _authPost(Uri uri, Map<String, String> headers, String body) async {
    final handler = authHttpHandler ?? mockHttpHandler;
    if (handler != null) {
      return handler('POST', uri, headers: headers, body: body);
    }
    return http.post(uri, headers: headers, body: body).timeout(const Duration(seconds: 8));
  }

  static Future<void> _persistFirebaseSession({
    required String idToken,
    required String refreshToken,
    required String uid,
    required DateTime expiresAt,
  }) async {
    _fbIdToken = idToken;
    _fbRefreshToken = refreshToken;
    _fbUid = uid;
    _fbTokenExpiresAt = expiresAt;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyFbIdToken, idToken);
      if (refreshToken.isNotEmpty) {
        await prefs.setString(_keyFbRefreshToken, refreshToken);
      }
      if (uid.isNotEmpty) {
        await prefs.setString(_keyFbUid, uid);
      }
      await prefs.setInt(_keyFbExpiresAtMs, expiresAt.toUtc().millisecondsSinceEpoch);
    } catch (_) {}
  }

  static Future<Map<String, String>?> restoreFirebaseSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final storedToken = prefs.getString(_keyFbIdToken);
      final storedRefresh = prefs.getString(_keyFbRefreshToken);
      final storedUid = prefs.getString(_keyFbUid);
      final storedExpMs = prefs.getInt(_keyFbExpiresAtMs);

      if (storedToken != null && isFirebaseIdTokenFormat(storedToken)) {
        _fbIdToken = storedToken;
      } else {
        _fbIdToken = null;
      }
      if (storedRefresh != null && storedRefresh.isNotEmpty && storedRefresh.split('.').length != 3) {
        // Firebase refresh tokens are opaque strings, never 3-part Render HS256 JWTs
        _fbRefreshToken = storedRefresh;
      } else if (storedRefresh != null && storedRefresh.split('.').length == 3) {
        _fbRefreshToken = null;
      }
      if (storedUid != null && storedUid.isNotEmpty) {
        _fbUid = storedUid;
      }
      if (storedExpMs != null && storedExpMs > 0) {
        _fbTokenExpiresAt = DateTime.fromMillisecondsSinceEpoch(storedExpMs, isUtc: true);
      }

      if (_fbIdToken != null || _fbRefreshToken != null) {
        return {
          if (_fbUid != null) 'uid': _fbUid!,
          if (_fbIdToken != null) 'idToken': _fbIdToken!,
          if (_fbRefreshToken != null) 'refreshToken': _fbRefreshToken!,
        };
      }
    } catch (_) {}
    return null;
  }

  static Future<void> clearFirebaseSession() async {
    _fbIdToken = null;
    _fbRefreshToken = null;
    _fbUid = null;
    _fbTokenExpiresAt = null;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyFbIdToken);
      await prefs.remove(_keyFbRefreshToken);
      await prefs.remove(_keyFbUid);
      await prefs.remove(_keyFbExpiresAtMs);
    } catch (_) {}
  }

  /// Simulates an app process restart in unit tests (clears memory, preserves SharedPreferences).
  @visibleForTesting
  static void resetInMemoryFirebaseAuthForTest() {
    _fbIdToken = null;
    _fbRefreshToken = null;
    _fbUid = null;
    _fbTokenExpiresAt = null;
  }

  static String? get currentFirebaseUid => _fbUid;

  static Future<bool> _hasAuthenticatedCustomerSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final uid = prefs.getString(_keyCustomerSessionUid);
      final renderToken = prefs.getString(_keyCustomerRenderToken);
      final fbRefresh = prefs.getString(_keyFbRefreshToken);
      return (uid != null && uid.isNotEmpty) ||
          (renderToken != null && renderToken.isNotEmpty) ||
          (fbRefresh != null && fbRefresh.isNotEmpty) ||
          (_fbRefreshToken != null && _fbRefreshToken!.isNotEmpty);
    } catch (_) {
      return _fbRefreshToken != null && _fbRefreshToken!.isNotEmpty;
    }
  }

  /// Exposed for authenticated Firestore operations (e.g. post-restart token refresh verification).
  static Future<String?> getValidFirebaseIdToken({
    bool forceRefresh = false,
    bool allowAnonymousFallback = false,
  }) =>
      _ensureFirebaseIdToken(
        forceRefresh: forceRefresh,
        allowAnonymousFallback: allowAnonymousFallback,
      );

  static Future<String?> _ensureFirebaseIdToken({
    bool forceRefresh = false,
    bool allowAnonymousFallback = false,
  }) async {
    if (_fbIdToken == null || _fbRefreshToken == null) {
      await restoreFirebaseSession();
    }
    if (_fbIdToken != null && !isFirebaseIdTokenFormat(_fbIdToken)) {
      _fbIdToken = null;
    }

    final now = DateTime.now().toUtc();
    if (!forceRefresh &&
        _fbIdToken != null &&
        _fbTokenExpiresAt != null &&
        _fbTokenExpiresAt!.isAfter(now.add(const Duration(seconds: 60)))) {
      return _fbIdToken;
    }

    try {
      if (_fbRefreshToken != null &&
          _fbRefreshToken!.isNotEmpty &&
          _fbRefreshToken!.split('.').length != 3) {
        final refreshUri = Uri.parse(
            'https://securetoken.googleapis.com/v1/token?key=$_firebaseWebApiKey');
        final res = await _authPost(
          refreshUri,
          {'Content-Type': 'application/x-www-form-urlencoded'},
          'grant_type=refresh_token&refresh_token=${Uri.encodeQueryComponent(_fbRefreshToken!)}',
        );
        if (res.statusCode == 200) {
          final data = jsonDecode(res.body) as Map<String, dynamic>;
          final token = data['id_token']?.toString();
          if (token != null && isFirebaseIdTokenFormat(token)) {
            final nextRefresh = data['refresh_token']?.toString() ?? _fbRefreshToken!;
            final nextUid = data['user_id']?.toString() ?? _fbUid ?? _extractUidFromJwt(token) ?? '';
            final expiresIn = int.tryParse(data['expires_in']?.toString() ?? '3600') ?? 3600;
            await _persistFirebaseSession(
              idToken: token,
              refreshToken: nextRefresh,
              uid: nextUid,
              expiresAt: now.add(Duration(seconds: expiresIn)),
            );
            return _fbIdToken;
          }
        }
      }

      // SECURITY: Never silently fall back to Anonymous Auth when an authenticated customer session exists
      // or when caller requires an authenticated Firebase user.
      final hasAuthSession = await _hasAuthenticatedCustomerSession();
      if (hasAuthSession || !allowAnonymousFallback) {
        return null;
      }

      final signUpUri = Uri.parse(
          'https://identitytoolkit.googleapis.com/v1/accounts:signUp?key=$_firebaseWebApiKey');
      final res = await _authPost(
        signUpUri,
        {'Content-Type': 'application/json'},
        jsonEncode({'returnSecureToken': true}),
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final token = data['idToken']?.toString();
        if (token != null && isFirebaseIdTokenFormat(token)) {
          final anonUid = data['localId']?.toString() ?? '';
          final anonRefresh = data['refreshToken']?.toString() ?? '';
          final expiresIn = int.tryParse(data['expiresIn']?.toString() ?? '3600') ?? 3600;
          await _persistFirebaseSession(
            idToken: token,
            refreshToken: anonRefresh,
            uid: anonUid,
            expiresAt: now.add(Duration(seconds: expiresIn)),
          );
          return _fbIdToken;
        }
      }
    } catch (e) {
      debugPrint('⚠️ [Customer Auth] Firebase Auth error: $e');
    }
    return null;
  }

  static String? _extractUidFromJwt(String token) {
    try {
      final parts = token.split('.');
      if (parts.length == 3) {
        final payload = jsonDecode(utf8.decode(base64Url.decode(base64Url.normalize(parts[1])))) as Map<String, dynamic>;
        return (payload['user_id'] ?? payload['sub'])?.toString();
      }
    } catch (_) {}
    return null;
  }

  /// Exchange backend-minted Firebase Custom Token for a real authenticated Firebase ID Token + Refresh Token
  static Future<Map<String, String>?> signInWithCustomToken(String customToken) async {
    if (customToken.trim().isEmpty) return null;
    try {
      final uri = Uri.parse(
          'https://identitytoolkit.googleapis.com/v1/accounts:signInWithCustomToken?key=$_firebaseWebApiKey');
      final res = await _authPost(
        uri,
        {'Content-Type': 'application/json'},
        jsonEncode({
          'token': customToken.trim(),
          'returnSecureToken': true,
        }),
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final idToken = data['idToken']?.toString() ?? '';
        final refreshToken = data['refreshToken']?.toString() ?? '';
        final expiresIn = int.tryParse(data['expiresIn']?.toString() ?? '3600') ?? 3600;
        if (isFirebaseIdTokenFormat(idToken)) {
          final uid = _extractUidFromJwt(idToken) ?? data['localId']?.toString() ?? '';
          await _persistFirebaseSession(
            idToken: idToken,
            refreshToken: refreshToken,
            uid: uid,
            expiresAt: DateTime.now().toUtc().add(Duration(seconds: expiresIn)),
          );
          return {
            'uid': uid,
            'idToken': idToken,
            'refreshToken': refreshToken,
          };
        }
      }
    } catch (e) {
      debugPrint('⚠️ [Customer Auth] signInWithCustomToken error: $e');
    }
    return null;
  }

  /// Injectable HTTP handler for unit/integration testing of 429, network drop, and concurrency scenarios
  static Future<http.Response> Function(
    String method,
    Uri uri, {
    Map<String, String>? headers,
    String? body,
  })? mockHttpHandler;

  // ─── TELEMETRY & COST METRICS (Phase 4.1) ─────────────────────────────────
  static int totalReads = 0;
  static int totalWrites = 0;
  static int totalDeletes = 0;
  static int totalRetries = 0;
  static int total429Responses = 0;
  static int lastHttpStatusCode = 200;

  static void resetMetrics() {
    totalReads = 0;
    totalWrites = 0;
    totalDeletes = 0;
    totalRetries = 0;
    total429Responses = 0;
    lastHttpStatusCode = 200;
    isLastRequestQuotaExceeded = false;
    isLastRequestNetworkError = false;
  }

  static Map<String, dynamic> getTelemetrySummary() {
    // Cloud Firestore asia-south1 pricing (USD): $0.036/100k reads, $0.108/100k writes, $0.012/100k deletes
    final readCostUsd = (totalReads / 100000.0) * 0.036;
    final writeCostUsd = (totalWrites / 100000.0) * 0.108;
    final deleteCostUsd = (totalDeletes / 100000.0) * 0.012;
    final totalUsd = readCostUsd + writeCostUsd + deleteCostUsd;
    return {
      'projectId': projectId,
      'region': 'asia-south1',
      'reads': totalReads,
      'writes': totalWrites,
      'deletes': totalDeletes,
      'retries': totalRetries,
      'http429Count': total429Responses,
      'estimatedCostUsd': double.parse(totalUsd.toStringAsFixed(6)),
      'estimatedCostInr': double.parse((totalUsd * 84.0).toStringAsFixed(4)),
    };
  }

  static final Random _secureRandom = _createRandom();
  static Random _createRandom() {
    try {
      return Random.secure();
    } catch (_) {
      return Random();
    }
  }

  /// Pure Dart SHA-256 implementation (FIPS 180-4) for zero-plaintext OTP verification
  static String sha256Hex(String input) {
    final k = <int>[
      0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
      0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3, 0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
      0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc, 0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
      0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7, 0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
      0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13, 0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
      0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
      0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
      0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208, 0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2,
    ];
    final h = <int>[
      0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a,
      0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19,
    ];
    final bytes = utf8.encode(input);
    final bitLength = bytes.length * 8;
    final paddedLength = ((bytes.length + 9 + 63) ~/ 64) * 64;
    final padded = Uint8List(paddedLength);
    padded.setRange(0, bytes.length, bytes);
    padded[bytes.length] = 0x80;
    final bd = ByteData.sublistView(padded);
    bd.setUint32(paddedLength - 8, (bitLength >> 32) & 0xffffffff, Endian.big);
    bd.setUint32(paddedLength - 4, bitLength & 0xffffffff, Endian.big);

    int rotr(int x, int n) => ((x & 0xffffffff) >>> n) | ((x << (32 - n)) & 0xffffffff);

    final w = List<int>.filled(64, 0);
    for (var i = 0; i < paddedLength; i += 64) {
      for (var t = 0; t < 16; t++) {
        w[t] = bd.getUint32(i + t * 4, Endian.big);
      }
      for (var t = 16; t < 64; t++) {
        final s0 = rotr(w[t - 15], 7) ^ rotr(w[t - 15], 18) ^ ((w[t - 15] & 0xffffffff) >>> 3);
        final s1 = rotr(w[t - 2], 17) ^ rotr(w[t - 2], 19) ^ ((w[t - 2] & 0xffffffff) >>> 10);
        w[t] = (w[t - 16] + s0 + w[t - 7] + s1) & 0xffffffff;
      }
      var a = h[0], b = h[1], c = h[2], d = h[3], e = h[4], f = h[5], g = h[6], hh = h[7];
      for (var t = 0; t < 64; t++) {
        final s1 = rotr(e, 6) ^ rotr(e, 11) ^ rotr(e, 25);
        final ch = (e & f) ^ ((~e & 0xffffffff) & g);
        final temp1 = (hh + s1 + ch + k[t] + w[t]) & 0xffffffff;
        final s0 = rotr(a, 2) ^ rotr(a, 13) ^ rotr(a, 22);
        final maj = (a & b) ^ (a & c) ^ (b & c);
        final temp2 = (s0 + maj) & 0xffffffff;
        hh = g;
        g = f;
        f = e;
        e = (d + temp1) & 0xffffffff;
        d = c;
        c = b;
        b = a;
        a = (temp1 + temp2) & 0xffffffff;
      }
      h[0] = (h[0] + a) & 0xffffffff;
      h[1] = (h[1] + b) & 0xffffffff;
      h[2] = (h[2] + c) & 0xffffffff;
      h[3] = (h[3] + d) & 0xffffffff;
      h[4] = (h[4] + e) & 0xffffffff;
      h[5] = (h[5] + f) & 0xffffffff;
      h[6] = (h[6] + g) & 0xffffffff;
      h[7] = (h[7] + hh) & 0xffffffff;
    }
    return h.map((x) => x.toRadixString(16).padLeft(8, '0')).join();
  }

  /// Executes an HTTP request with exponential backoff and full jitter for retryable errors (429, 503, ABORTED)
  static Future<http.Response> _requestWithBackoff(
    String method,
    Uri uri, {
    Map<String, String>? headers,
    String? body,
    int maxRetries = 3,
    Duration timeout = const Duration(seconds: 6),
  }) async {
    int attempt = 0;
    bool refreshedAuth = false;
    while (true) {
      attempt++;
      http.Response res;
      if (mockHttpHandler != null) {
        res = await mockHttpHandler!(method, uri, headers: headers, body: body);
      } else {
        final effectiveHeaders = Map<String, String>.from(headers ?? const {});
        if (!effectiveHeaders.containsKey('Authorization')) {
          final idToken = await _ensureFirebaseIdToken(forceRefresh: refreshedAuth);
          if (idToken != null && idToken.isNotEmpty) {
            effectiveHeaders['Authorization'] = 'Bearer $idToken';
          }
        }
        switch (method.toUpperCase()) {
          case 'POST':
            res = await http.post(uri, headers: effectiveHeaders, body: body).timeout(timeout);
            break;
          case 'PATCH':
            res = await http.patch(uri, headers: effectiveHeaders, body: body).timeout(timeout);
            break;
          case 'DELETE':
            res = await http.delete(uri, headers: effectiveHeaders).timeout(timeout);
            break;
          default:
            res = await http.get(uri, headers: effectiveHeaders).timeout(timeout);
        }
        if (res.statusCode == 401 && !refreshedAuth) {
          refreshedAuth = true;
          _fbIdToken = null;
          continue;
        }
      }

      lastHttpStatusCode = res.statusCode;
      if (res.statusCode == 429) {
        total429Responses++;
      }

      final isRetryable = res.statusCode == 429 ||
          res.statusCode == 503 ||
          (res.statusCode == 409 && res.body.contains('ABORTED'));

      if (!isRetryable || attempt > maxRetries) {
        return res;
      }

      totalRetries++;
      final baseDelayMs = 150 * (1 << (attempt - 1));
      final jitterMs = _secureRandom.nextInt(100);
      await Future.delayed(Duration(milliseconds: baseDelayMs + jitterMs));
    }
  }

  static Map<String, dynamic> _toFirestoreValue(dynamic val) {
    if (val == null) return {'nullValue': null};
    if (val is bool) return {'booleanValue': val};
    if (val is int) return {'integerValue': val.toString()};
    if (val is double) return {'doubleValue': val};
    if (val is num) return {'doubleValue': val.toDouble()};
    if (val is String) return {'stringValue': val};
    if (val is List) {
      return {
        'arrayValue': {
          'values': val.map(_toFirestoreValue).toList(),
        }
      };
    }
    if (val is Map) {
      final fields = <String, dynamic>{};
      val.forEach((k, v) {
        if (v != null) {
          fields[k.toString()] = _toFirestoreValue(v);
        }
      });
      return {
        'mapValue': {'fields': fields}
      };
    }
    return {'stringValue': val.toString()};
  }

  static dynamic _fromFirestoreValue(Map<String, dynamic>? valObj) {
    if (valObj == null) return null;
    if (valObj.containsKey('stringValue')) return valObj['stringValue'];
    if (valObj.containsKey('booleanValue')) return valObj['booleanValue'];
    if (valObj.containsKey('integerValue')) {
      return int.tryParse(valObj['integerValue'].toString()) ?? 0;
    }
    if (valObj.containsKey('doubleValue')) {
      return (valObj['doubleValue'] as num?)?.toDouble() ?? 0.0;
    }
    if (valObj.containsKey('nullValue')) return null;
    if (valObj.containsKey('timestampValue')) return valObj['timestampValue'];
    if (valObj.containsKey('arrayValue')) {
      final arr = valObj['arrayValue'] as Map<String, dynamic>?;
      final values = arr?['values'] as List<dynamic>? ?? [];
      return values
          .map((v) => _fromFirestoreValue(v as Map<String, dynamic>?))
          .toList();
    }
    if (valObj.containsKey('mapValue')) {
      final mapVal = valObj['mapValue'] as Map<String, dynamic>?;
      final fields = mapVal?['fields'] as Map<String, dynamic>? ?? {};
      final out = <String, dynamic>{};
      fields.forEach((k, v) {
        out[k] = _fromFirestoreValue(v as Map<String, dynamic>?);
      });
      return out;
    }
    return null;
  }

  static Map<String, dynamic>? _docToPlain(Map<String, dynamic>? doc) {
    if (doc == null || doc['fields'] == null) return null;
    final fields = doc['fields'] as Map<String, dynamic>;
    final out = <String, dynamic>{};
    fields.forEach((k, v) {
      out[k] = _fromFirestoreValue(v as Map<String, dynamic>?);
    });
    if (doc['name'] != null && out['id'] == null) {
      final parts = doc['name'].toString().split('/');
      out['id'] = parts.last;
    }
    if (doc['updateTime'] != null) {
      out['_firestoreUpdateTime'] = doc['updateTime'].toString();
    }
    return out;
  }

  static bool isLastRequestQuotaExceeded = false;
  static bool isLastRequestNetworkError = false;
  static final Map<String, _CachedResult> _memoryCache = {};
  static final Set<String> _activeTechnicianLocks = {};
  static final Map<String, String> _idempotencyBookingMap = {};

  static void clearMemoryCache() {
    _memoryCache.clear();
    _activeTechnicianLocks.clear();
    _idempotencyBookingMap.clear();
  }

  static Future<List<Map<String, dynamic>>> listCollection(String collection,
      {int pageSize = 250, bool forceRefresh = false}) async {
    final cacheKey = 'col_$collection';
    final now = DateTime.now();
    final ttlSeconds = collection.contains('categories') ? 300 : 30;

    if (!forceRefresh && _memoryCache.containsKey(cacheKey)) {
      final cached = _memoryCache[cacheKey]!;
      if (now.difference(cached.timestamp).inSeconds < ttlSeconds) {
        return (cached.data as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
    }

    try {
      final uri = Uri.parse('$baseUrl/$collection?pageSize=$pageSize');
      final res = await _requestWithBackoff('GET', uri);
      if (res.statusCode == 200) {
        isLastRequestQuotaExceeded = false;
        isLastRequestNetworkError = false;
        final decoded = jsonDecode(res.body) as Map<String, dynamic>;
        final docs = decoded['documents'] as List<dynamic>? ?? [];
        totalReads += docs.isEmpty ? 1 : docs.length;
        final parsed = docs
            .map((d) => _docToPlain(d as Map<String, dynamic>?))
            .whereType<Map<String, dynamic>>()
            .toList();
        _memoryCache[cacheKey] = _CachedResult(now, parsed);
        return parsed;
      } else if (res.statusCode == 429) {
        isLastRequestQuotaExceeded = true;
        isLastRequestNetworkError = false;
        debugPrint('⚠️ [Customer Firestore] 429 Quota Exceeded for listCollection($collection).');
        if (!forceRefresh && _memoryCache.containsKey(cacheKey)) {
          return (_memoryCache[cacheKey]!.data as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
        }
        return [];
      }
      return [];
    } catch (e) {
      isLastRequestNetworkError = true;
      debugPrint('🔥 [FirestoreRestClient] listCollection($collection) error: $e');
      if (!forceRefresh && _memoryCache.containsKey(cacheKey)) {
        return (_memoryCache[cacheKey]!.data as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
      return [];
    }
  }

  static Future<Map<String, dynamic>?> getDocument(
      String collection, String docId, {bool forceRefresh = false}) async {
    final cleanId = docId.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    final cacheKey = 'doc_${collection}_$cleanId';
    final now = DateTime.now();

    if (!forceRefresh && _memoryCache.containsKey(cacheKey)) {
      final cached = _memoryCache[cacheKey]!;
      if (now.difference(cached.timestamp).inSeconds < 30) {
        return Map<String, dynamic>.from(cached.data as Map);
      }
    }

    try {
      final uri = Uri.parse('$baseUrl/$collection/$cleanId');
      final res = await _requestWithBackoff('GET', uri);
      if (res.statusCode == 200) {
        isLastRequestQuotaExceeded = false;
        isLastRequestNetworkError = false;
        totalReads += 1;
        final data = _docToPlain(jsonDecode(res.body) as Map<String, dynamic>?);
        if (data != null) {
          _memoryCache[cacheKey] = _CachedResult(now, data);
        }
        return data;
      } else if (res.statusCode == 429) {
        isLastRequestQuotaExceeded = true;
      }
      return null;
    } catch (_) {
      isLastRequestNetworkError = true;
      return null;
    }
  }

  static Future<Map<String, dynamic>?> upsertDocument(
      String collection, String docId, Map<String, dynamic> data) async {
    try {
      final cleanId = docId.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
      final fields = <String, dynamic>{};
      final payload = {
        ...data,
        'id': cleanId,
        'updatedAt': DateTime.now().toUtc().toIso8601String(),
      };
      payload.forEach((k, v) {
        if (v != null && k != '_firestoreUpdateTime') {
          fields[k] = _toFirestoreValue(v);
        }
      });

      // Crucial: Use updateMask so partial updates NEVER wipe out existing fields
      final maskParams = fields.keys
          .map((k) => 'updateMask.fieldPaths=${Uri.encodeQueryComponent(k)}')
          .join('&');
      final uri = Uri.parse('$baseUrl/$collection/$cleanId?$maskParams');

      final res = await _requestWithBackoff(
        'PATCH',
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'fields': fields}),
      );

      _memoryCache.remove('col_$collection');
      _memoryCache.remove('doc_${collection}_$cleanId');

      if (res.statusCode >= 200 && res.statusCode < 300) {
        isLastRequestQuotaExceeded = false;
        isLastRequestNetworkError = false;
        totalWrites += 1;
        return _docToPlain(jsonDecode(res.body) as Map<String, dynamic>?);
      } else if (res.statusCode == 429) {
        isLastRequestQuotaExceeded = true;
      }
    } catch (e) {
      isLastRequestNetworkError = true;
      debugPrint('🔥 [FirestoreRestClient] upsert($collection/$docId) error: $e');
    }
    return null;
  }

  /// Atomic Firestore `:commit` transaction with optimistic concurrency precondition (`currentDocument.updateTime`)
  /// Ensures that if two customers simultaneously attempt to assign the same technician, the second fails with 409!
  static Future<Map<String, dynamic>> atomicAssignBookingTransaction({
    required String bookingId,
    required Map<String, dynamic> bookingDoc,
    required String technicianId,
    String? expectedTechUpdateTime,
  }) async {
    final cleanBookingId = bookingId.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    final cleanTechId = technicianId.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');

    // In-process synchronous mutex check for simultaneous in-app or parallel test requests
    if (_activeTechnicianLocks.contains(cleanTechId)) {
      return {
        'success': false,
        'statusCode': 409,
        'code': 'TECHNICIAN_BUSY_CONFLICT',
        'error': 'Concurrency conflict: Selected technician is already being assigned to another booking.',
      };
    }

    _activeTechnicianLocks.add(cleanTechId);
    try {
      final nowUtc = DateTime.now().toUtc().toIso8601String();
      final bookingFields = <String, dynamic>{};
      bookingDoc.forEach((k, v) {
        if (v != null && k != '_firestoreUpdateTime') {
          bookingFields[k] = _toFirestoreValue(v);
        }
      });

      final techUpdateFields = <String, dynamic>{
        'availabilityStatus': _toFirestoreValue('BUSY'),
        'activeBookingId': _toFirestoreValue(cleanBookingId),
        'updatedAt': _toFirestoreValue(nowUtc),
      };

      final writes = <Map<String, dynamic>>[
        {
          'update': {
            'name': '$documentNamePrefix/technician_profiles/$cleanTechId',
            'fields': techUpdateFields,
          },
          'updateMask': {
            'fieldPaths': ['availabilityStatus', 'activeBookingId', 'updatedAt'],
          },
          if (expectedTechUpdateTime != null && expectedTechUpdateTime.isNotEmpty)
            'currentDocument': {'updateTime': expectedTechUpdateTime}
          else
            'currentDocument': {'exists': true},
        },
        {
          'update': {
            'name': '$documentNamePrefix/bookings/$cleanBookingId',
            'fields': bookingFields,
          },
          'currentDocument': {'exists': false},
        },
      ];

      final uri = Uri.parse(commitUrl);
      final res = await _requestWithBackoff(
        'POST',
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'writes': writes}),
        maxRetries: 2,
      );

      _memoryCache.remove('col_technician_profiles');
      _memoryCache.remove('col_bookings');
      _memoryCache.remove('doc_technician_profiles_$cleanTechId');

      if (res.statusCode >= 200 && res.statusCode < 300) {
        totalWrites += 2;
        return {'success': true, 'statusCode': 201};
      } else if (res.statusCode == 400 || res.statusCode == 409) {
        return {
          'success': false,
          'statusCode': 409,
          'code': 'TECHNICIAN_BUSY_CONFLICT',
          'error': 'Atomic transaction conflict: Technician state changed or was assigned to another customer.',
        };
      } else if (res.statusCode == 429) {
        isLastRequestQuotaExceeded = true;
        return {
          'success': false,
          'statusCode': 429,
          'code': 'QUOTA_EXCEEDED',
          'error': 'Firestore rate limit or quota exceeded during booking transaction.',
        };
      } else {
        return {
          'success': false,
          'statusCode': res.statusCode,
          'code': 'TRANSACTION_FAILED',
          'error': 'Firestore atomic commit failed (HTTP ${res.statusCode}).',
        };
      }
    } catch (e) {
      isLastRequestNetworkError = true;
      return {
        'success': false,
        'statusCode': 503,
        'code': 'NETWORK_ERROR',
        'error': 'Network disconnection during atomic booking assignment: $e',
      };
    } finally {
      _activeTechnicianLocks.remove(cleanTechId);
    }
  }

  // ─── AUTHORITATIVE OTP CHALLENGE ENGINE (Phase 4.1) ──────────────────────
  static final Map<String, Map<String, dynamic>> _localOtpChallenges = {};

  static void clearOtpChallengesForTest() {
    _localOtpChallenges.clear();
  }

  static Future<Map<String, dynamic>> requestOtpChallenge({
    required String identifier,
    String? email,
    String? phone,
    String? fullName,
    String role = 'CUSTOMER',
    DateTime? nowOverride,
  }) async {
    final normId = identifier.trim().toLowerCase();
    if (normId.isEmpty) {
      return {'success': false, 'statusCode': 400, 'code': 'MISSING_IDENTIFIER', 'error': 'Email or phone is required'};
    }

    final nowMs = (nowOverride ?? DateTime.now()).millisecondsSinceEpoch;
    final cleanDocId = 'otp_${normId.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_')}';

    Map<String, dynamic>? existing = _localOtpChallenges[cleanDocId];
    existing ??= await getDocument('otp_challenges', cleanDocId, forceRefresh: true);

    int requestCount = 0;
    int windowStartMs = nowMs;
    if (existing != null) {
      final prevWindowStart = (existing['windowStartMs'] as num?)?.toInt() ?? 0;
      final prevCount = (existing['requestCount'] as num?)?.toInt() ?? 0;
      if (nowMs - prevWindowStart < 600000) {
        if (prevCount >= 3) {
          return {
            'success': false,
            'statusCode': 429,
            'code': 'OTP_RATE_LIMIT_EXCEEDED',
            'error': 'Maximum 3 OTP requests allowed within 10 minutes. Please wait before trying again.',
          };
        }
        requestCount = prevCount;
        windowStartMs = prevWindowStart;
      }
    }

    final otp = (100000 + _secureRandom.nextInt(900000)).toString();
    final otpHash = sha256Hex(otp);
    final challengeDoc = {
      'id': cleanDocId,
      'identifier': normId,
      'otpHash': otpHash,
      'role': role,
      'fullName': fullName ?? 'Customer',
      'requestedAtMs': nowMs,
      'expiresAtMs': nowMs + 600000, // 10 minutes
      'failedAttempts': 0,
      'lockedUntilMs': 0,
      'requestCount': requestCount + 1,
      'windowStartMs': windowStartMs,
    };

    _localOtpChallenges[cleanDocId] = challengeDoc;
    await upsertDocument('otp_challenges', cleanDocId, challengeDoc);

    if (email != null && email.contains('@')) {
      await EmailService.sendOtpEmail(
        email: email,
        otp: otp,
        role: role,
        name: fullName,
      );
    }

    return {
      'success': true,
      'statusCode': 200,
      'message': 'OTP generated and dispatched via server challenge',
      'expiresInSeconds': 600,
      if (mockHttpHandler != null) '_testOtp': otp,
    };
  }

  static Future<Map<String, dynamic>> verifyOtpChallenge({
    required String identifier,
    required String code,
    DateTime? nowOverride,
  }) async {
    final normId = identifier.trim().toLowerCase();
    final cleanCode = code.trim();
    final nowMs = (nowOverride ?? DateTime.now()).millisecondsSinceEpoch;
    final cleanDocId = 'otp_${normId.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_')}';

    Map<String, dynamic>? challenge = _localOtpChallenges[cleanDocId];
    challenge ??= await getDocument('otp_challenges', cleanDocId, forceRefresh: true);

    if (challenge == null) {
      return {
        'success': false,
        'statusCode': 400,
        'code': 'OTP_NOT_FOUND',
        'error': 'No active OTP challenge found. Please request a new OTP.',
      };
    }

    final lockedUntilMs = (challenge['lockedUntilMs'] as num?)?.toInt() ?? 0;
    if (lockedUntilMs > nowMs) {
      return {
        'success': false,
        'statusCode': 429,
        'code': 'OTP_ATTEMPT_LIMIT_EXCEEDED',
        'error': 'Too many incorrect OTP attempts. Account is locked for 15 minutes.',
      };
    }

    final expiresAtMs = (challenge['expiresAtMs'] as num?)?.toInt() ?? 0;
    if (nowMs > expiresAtMs) {
      return {
        'success': false,
        'statusCode': 400,
        'code': 'OTP_EXPIRED',
        'error': 'OTP has expired (valid for 10 minutes). Please request a new OTP.',
      };
    }

    final failedAttempts = (challenge['failedAttempts'] as num?)?.toInt() ?? 0;
    final expectedHash = challenge['otpHash']?.toString() ?? '';
    final inputHash = sha256Hex(cleanCode);

    if (expectedHash.isEmpty || inputHash != expectedHash) {
      final nextFailed = failedAttempts + 1;
      final isNowLocked = nextFailed >= 5;
      final updated = {
        ...challenge,
        'failedAttempts': nextFailed,
        if (isNowLocked) 'lockedUntilMs': nowMs + 900000,
      };
      _localOtpChallenges[cleanDocId] = updated;
      await upsertDocument('otp_challenges', cleanDocId, updated);

      if (isNowLocked) {
        return {
          'success': false,
          'statusCode': 429,
          'code': 'OTP_ATTEMPT_LIMIT_EXCEEDED',
          'error': 'Maximum 5 failed OTP attempts reached. Locked for 15 minutes.',
        };
      }
      return {
        'success': false,
        'statusCode': 400,
        'code': 'INVALID_OTP',
        'error': 'Invalid OTP code. ${5 - nextFailed} attempts remaining.',
      };
    }

    final consumed = {
      ...challenge,
      'otpHash': '',
      'consumedAtMs': nowMs,
      'failedAttempts': 0,
      'lockedUntilMs': 0,
    };
    _localOtpChallenges[cleanDocId] = consumed;
    await upsertDocument('otp_challenges', cleanDocId, consumed);

    return {
      'success': true,
      'statusCode': 200,
      'message': 'OTP verified successfully',
    };
  }

  static double _calculateDistanceKm(
      double lat1, double lon1, double lat2, double lon2) {
    const double earthRadiusKm = 6371.0;
    final dLat = (lat2 - lat1) * (pi / 180.0);
    final dLon = (lon2 - lon1) * (pi / 180.0);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1 * (pi / 180.0)) *
            cos(lat2 * (pi / 180.0)) *
            sin(dLon / 2) *
            sin(dLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadiusKm * c;
  }

  static const Map<String, String> _canonicalSkillAliases = {
    // AC Services
    'sk_ac_installation': 'ac_install',
    'ac installation': 'ac_install',
    'ac_install': 'ac_install',
    'sk_ac_uninstallation': 'ac_uninstall',
    'ac uninstallation': 'ac_uninstall',
    'ac_uninstall': 'ac_uninstall',
    'sk_deep_cleaning_service': 'ac_deep_cleaning',
    'deep cleaning service': 'ac_deep_cleaning',
    'ac deep cleaning service': 'ac_deep_cleaning',
    'ac deep cleaning': 'ac_deep_cleaning',
    'ac_deep_cleaning': 'ac_deep_cleaning',
    'ac_deep_clean': 'ac_deep_cleaning',
    'sk_ac_repair': 'ac_repair_general',
    'ac repair': 'ac_repair_general',
    'ac_repair_general': 'ac_repair_general',
    'ac_repair': 'ac_repair_general',
    'sk_ac_pcb_repair': 'ac_pcb_repair',
    'ac pcb repair': 'ac_pcb_repair',
    'ac_pcb_repair': 'ac_pcb_repair',
    'sk_ac_relocation': 'ac_relocation',
    'ac relocation': 'ac_relocation',
    'ac_relocation': 'ac_relocation',
    'sk_ac_general_servicing': 'ac_general_service',
    'ac general servicing': 'ac_general_service',
    'ac general service': 'ac_general_service',
    'sk_ac_general_service': 'ac_general_service',
    'ac_general_service': 'ac_general_service',
    'sk_gas_refill_top_up': 'ac_gas_refill',
    'gas refill / top-up': 'ac_gas_refill',
    'ac gas refill': 'ac_gas_refill',
    'gas refill': 'ac_gas_refill',
    'ac_gas_refill': 'ac_gas_refill',
    'ac_gas_charging': 'ac_gas_refill',
    'ac gas charging/refilling': 'ac_gas_refill',
    'ac cooling problem': 'ac_cooling_problem',
    'ac cooling issue': 'ac_cooling_problem',
    'sk_ac_cooling_problem': 'ac_cooling_problem',
    'ac_cooling_issue': 'ac_cooling_problem',
    'ac_cooling_problem': 'ac_cooling_problem',
    'ac compressor issue': 'ac_compressor_issue',
    'ac compressor repair': 'ac_compressor_issue',
    'ac_compressor_repair': 'ac_compressor_issue',
    'ac_compressor_issue': 'ac_compressor_issue',
    'ac water leakage repair': 'ac_water_leakage',
    'sk_ac_water_leakage': 'ac_water_leakage',
    'ac_water_leakage': 'ac_water_leakage',
    'ac electrical repair': 'ac_electrical_repair',
    'sk_ac_electrical_repair': 'ac_electrical_repair',
    'ac_electrical_repair': 'ac_electrical_repair',
    'ac noise/vibration issue': 'ac_noise_vibration',
    'ac_noise_vibration': 'ac_noise_vibration',
    'ac outdoor unit repair': 'ac_outdoor_repair',
    'ac_outdoor_repair': 'ac_outdoor_repair',
    'ac remote/sensor issue': 'ac_remote_sensor',
    'ac_remote_sensor': 'ac_remote_sensor',
    'copper pipe installation': 'copper_pipe_install',
    'copper_pipe_install': 'copper_pipe_install',

    // Electrical Services
    'sk_ceiling_fan_installation': 'fan_ceiling_install',
    'ceiling fan installation': 'fan_ceiling_install',
    'fan_ceiling_install': 'fan_ceiling_install',
    'sk_exhaust_fan': 'fan_exhaust_install',
    'exhaust fan': 'fan_exhaust_install',
    'exhaust fan installation': 'fan_exhaust_install',
    'fan_exhaust_install': 'fan_exhaust_install',
    'sk_fan_installation': 'fan_install',
    'fan installation': 'fan_install',
    'fan_install': 'fan_install',
    'sk_ceiling_fan_repair': 'fan_rep',
    'ceiling fan repair': 'fan_rep',
    'fan repair': 'fan_rep',
    'fan_rep': 'fan_rep',
    'sk_fan_repair': 'fan_rep',
    'sk_light_repair': 'light_rep',
    'light repair': 'light_rep',
    'light_rep': 'light_rep',
    'sk_light_installation': 'light_install',
    'light installation': 'light_install',
    'light_install': 'light_install',
    'sk_led_installation_repair': 'led_install',
    'led installation/repair': 'led_install',
    'led light installation': 'led_install',
    'led_install': 'led_install',
    'led_light_install': 'led_install',
    'decorative light installation': 'decorative_light_install',
    'decorative_light_install': 'decorative_light_install',
    'sk_basic_electrician': 'elec_fault_diag',
    'basic electrician': 'elec_fault_diag',
    'electrical fault diagnosis': 'elec_fault_diag',
    'elec_fault_diag': 'elec_fault_diag',
    'sk_mcb_repair': 'mcb_rep',
    'mcb repair': 'mcb_rep',
    'mcb replacement': 'mcb_rep',
    'mcb repair/replacement': 'mcb_rep',
    'mcb_rep': 'mcb_rep',
    'mcb_replace': 'mcb_rep',
    'sk_fuse_repair': 'fuse_rep',
    'fuse repair': 'fuse_rep',
    'fuse_rep': 'fuse_rep',
    'doorbell installation/repair': 'doorbell_svc',
    'doorbell_svc': 'doorbell_svc',
    'inverter installation/repair': 'inverter_rep',
    'inverter repair': 'inverter_rep',
    'inverter_rep': 'inverter_rep',
    'inverter_install': 'inverter_rep',
    'geyser electrical connection': 'geyser_connection',
    'geyser_connection': 'geyser_connection',
    'electrical appliance connection': 'appliance_connect',
    'appliance_connect': 'appliance_connect',
    'switch repair': 'switch_rep',
    'switch replacement': 'switch_rep',
    'switch_rep': 'switch_rep',
    'switch_replace': 'switch_rep',
    'socket repair': 'socket_rep',
    'socket replacement': 'socket_rep',
    'socket_rep': 'socket_rep',
    'socket_replace': 'socket_rep',
    'switchboard repair': 'switchboard_repair',
    'switchboard_repair': 'switchboard_repair',
  };

  /// Maps any raw service ID, skill ID, or display name to canonical central catalog serviceId.
  static String resolveCanonicalServiceId(String? raw, {String? name}) {
    if (raw != null) {
      final clean = raw.trim().toLowerCase();
      if (_canonicalSkillAliases.containsKey(clean)) {
        return _canonicalSkillAliases[clean]!;
      }
      final norm = clean.replaceAll('sk_', '').replaceAll('_', ' ').trim();
      if (_canonicalSkillAliases.containsKey(norm)) {
        return _canonicalSkillAliases[norm]!;
      }
      if (clean.isNotEmpty) {
        return clean;
      }
    }
    if (name != null) {
      final cleanName = name.trim().toLowerCase();
      if (_canonicalSkillAliases.containsKey(cleanName)) {
        return _canonicalSkillAliases[cleanName]!;
      }
    }
    return '';
  }

  /// Evaluates whether a technician profile possesses the verified, enabled canonical skill
  /// required for a booking. Parent category matching alone is strictly forbidden.
  static bool _doesTechnicianMatchService(
      Map<String, dynamic> tech, String sId, String sName) {
    final targetCanonical = resolveCanonicalServiceId(sId, name: sName);
    if (targetCanonical.isEmpty) return false;

    final primarySkills = tech['skills'] as List<dynamic>? ?? const [];
    final selectedSkills = tech['selectedSkills'] as List<dynamic>? ?? const [];
    if (primarySkills.isEmpty && selectedSkills.isEmpty) return false;

    // Deduplicate by canonical service ID, letting `skills` override `selectedSkills`
    final Map<String, dynamic> mergedByCanonical = {};
    for (final skill in [...selectedSkills, ...primarySkills]) {
      String rawId = '';
      String rawName = '';
      if (skill is Map) {
        rawId = skill['canonicalServiceId']?.toString() ??
            skill['serviceId']?.toString() ??
            skill['skillId']?.toString() ??
            skill['id']?.toString() ??
            '';
        rawName = skill['name']?.toString() ?? skill['skillName']?.toString() ?? '';
      } else if (skill is String) {
        rawId = skill;
        rawName = skill;
      }
      final key = resolveCanonicalServiceId(rawId, name: rawName);
      final mapKey = key.isNotEmpty ? key : '$rawId:$rawName';
      if (mapKey.isNotEmpty) mergedByCanonical[mapKey] = skill;
    }

    for (final skill in mergedByCanonical.values) {
      String skillId = '';
      String canonicalId = '';
      String skillName = '';
      String verificationStatus = '';
      bool isSkillEnabled = true;

      if (skill is Map) {
        skillId = skill['skillId']?.toString() ?? skill['id']?.toString() ?? '';
        canonicalId = skill['canonicalServiceId']?.toString() ?? skill['serviceId']?.toString() ?? '';
        skillName = skill['name']?.toString() ?? skill['skillName']?.toString() ?? '';
        verificationStatus =
            (skill['verificationStatus'] ?? skill['status'])?.toString().toUpperCase().trim() ?? '';
        if (skill.containsKey('enabled')) {
          isSkillEnabled = skill['enabled'] == true;
        }
        if (skill.containsKey('isActive')) {
          isSkillEnabled = isSkillEnabled && (skill['isActive'] == true);
        }
      } else if (skill is String) {
        // Bare strings lack explicit verification metadata; reject as unverified
        continue;
      }

      // 1. Mandatory verification check: Must be explicitly VERIFIED.
      if (verificationStatus != 'VERIFIED') {
        continue;
      }

      // 2. Mandatory active toggle check: Must be enabled and active.
      if (!isSkillEnabled) {
        continue;
      }

      // 3. Exact Canonical ID match (Zero tolerance for category or substring fallback)
      final skillCanonical = resolveCanonicalServiceId(
        canonicalId.isNotEmpty ? canonicalId : (skillId.isNotEmpty ? skillId : skillName),
        name: skillName,
      );

      if (skillCanonical.isNotEmpty && skillCanonical == targetCanonical) {
        return true;
      }

      if (skillName.isNotEmpty) {
        final nameCanonical = resolveCanonicalServiceId(skillName);
        if (nameCanonical.isNotEmpty && nameCanonical == targetCanonical) {
          return true;
        }
      }
    }

    // Category-level match alone is strictly rejected.
    return false;
  }

  static bool _isValidCoordinatePair(double? lat, double? lng) {
    return lat != null &&
        lng != null &&
        lat.isFinite &&
        lng.isFinite &&
        lat >= -90.0 &&
        lat <= 90.0 &&
        lng >= -180.0 &&
        lng <= 180.0 &&
        !(lat == 0.0 && lng == 0.0);
  }

  /// Single authoritative technician eligibility check matching backend `eligibilityService.js`.
  static Map<String, dynamic> evaluateTechnicianEligibility(
    Map<String, dynamic> tech, {
    String? serviceId,
    String? serviceName,
    double? customerLat,
    double? customerLng,
    double radiusKm = 15.0,
    int maxLocationAgeSeconds = 600,
    Set<String>? busyTechIds,
    bool checkSkill = true,
  }) {
    final tId = (tech['uid'] ?? tech['technicianId'] ?? tech['id'])?.toString().trim() ?? '';
    if (tId.isEmpty) {
      return {'eligible': false, 'reason': 'UNAUTHENTICATED_TECHNICIAN'};
    }

    // 1. Account must be explicitly ACTIVE
    final accStatus = (tech['accountStatus']?.toString() ?? '').toUpperCase().trim();
    if (accStatus != 'ACTIVE') {
      return {'eligible': false, 'reason': 'ACCOUNT_NOT_ACTIVE'};
    }

    // 2. KYC must be explicitly VERIFIED or APPROVED
    final kycStatus = (tech['kycStatus']?.toString() ?? '').toUpperCase().trim();
    if (kycStatus != 'VERIFIED' && kycStatus != 'APPROVED') {
      return {'eligible': false, 'reason': 'KYC_NOT_VERIFIED'};
    }

    // 3. Technician must be strictly online
    final isOnline = tech['isOnline'] == true;
    final availStatus = (tech['availabilityStatus']?.toString() ?? 'AVAILABLE').toUpperCase().trim();
    if (!isOnline || availStatus == 'OFFLINE') {
      return {'eligible': false, 'reason': 'TECHNICIAN_WENT_OFFLINE'};
    }

    // 4. Availability must not be BUSY & no conflicting active booking
    final activeBookingId = tech['activeBookingId']?.toString().trim() ?? '';
    if (availStatus == 'BUSY' ||
        activeBookingId.isNotEmpty ||
        (busyTechIds != null && busyTechIds.contains(tId)) ||
        _activeTechnicianLocks.contains(tId)) {
      return {'eligible': false, 'reason': 'TECHNICIAN_BUSY_CONFLICT'};
    }

    // 5. Location must be valid and recent (<= 10 minutes)
    final double? tLat = ((tech['latitude'] ?? tech['currentLatitude']) as num?)?.toDouble();
    final double? tLng = ((tech['longitude'] ?? tech['currentLongitude']) as num?)?.toDouble();
    if (!_isValidCoordinatePair(tLat, tLng)) {
      return {'eligible': false, 'reason': 'STALE_LOCATION'};
    }

    final lastUpdateStr = tech['lastLocationUpdate']?.toString();
    if (lastUpdateStr == null || lastUpdateStr.isEmpty) {
      return {'eligible': false, 'reason': 'STALE_LOCATION'};
    }
    DateTime? lastUpdate;
    try {
      lastUpdate = DateTime.parse(lastUpdateStr).toUtc();
    } catch (_) {
      return {'eligible': false, 'reason': 'STALE_LOCATION'};
    }
    final ageSeconds = DateTime.now().toUtc().difference(lastUpdate).inSeconds;
    if (ageSeconds > maxLocationAgeSeconds || ageSeconds < -120) {
      return {'eligible': false, 'reason': 'STALE_LOCATION'};
    }

    // 6. Customer coverage check (strict <= radiusKm, no global out-of-radius fallback)
    if (!_isValidCoordinatePair(customerLat, customerLng)) {
      return {'eligible': false, 'reason': 'LOCATION_UNAVAILABLE'};
    }
    final distKm = _calculateDistanceKm(customerLat!, customerLng!, tLat!, tLng!);
    if (distKm > radiusKm) {
      return {'eligible': false, 'reason': 'OUT_OF_RADIUS', 'distanceKm': distKm};
    }

    // 7. Verified & enabled canonical skill check
    if (checkSkill && ((serviceId != null && serviceId.isNotEmpty) || (serviceName != null && serviceName.isNotEmpty))) {
      if (!_doesTechnicianMatchService(tech, serviceId ?? '', serviceName ?? '')) {
        return {'eligible': false, 'reason': 'SKILL_MISMATCH', 'distanceKm': distKm};
      }
    }

    return {
      'eligible': true,
      'reason': null,
      'distanceKm': distKm,
      'ageMinutes': (ageSeconds / 60).floor().abs(),
    };
  }

  /// Fallback API handler that serves Customer App endpoints directly from Cloud Firestore
  static Future<http.Response> handleRequest(String method, String endpoint,
      [Map<String, dynamic>? body]) async {
    final cleanPath = endpoint.split('?').first;
    final m = method.toUpperCase();

    try {
      // 1. Real-time Spatial Availability (Strict 15 KM Radius Scan - Zero Fake Data)
      if (cleanPath.contains('/availability')) {
        final uri = Uri.parse(endpoint.startsWith('http') ? endpoint : 'http://localhost$endpoint');
        final queryParams = uri.queryParameters;
        final targetLat = double.tryParse(queryParams['latitude'] ?? '') ??
            (body != null && body['latitude'] is num ? (body['latitude'] as num).toDouble() : null);
        final targetLng = double.tryParse(queryParams['longitude'] ?? '') ??
            (body != null && body['longitude'] is num ? (body['longitude'] as num).toDouble() : null);
        final radiusKm = double.tryParse(queryParams['radiusKm'] ?? '') ?? 15.0;
        final forceRefresh = queryParams['forceRefresh'] == 'true' || body?['forceRefresh'] == true;

        if (targetLat == null || targetLng == null || targetLat == 0.0 || targetLng == 0.0) {
          return _jsonResponse({
            'success': false,
            'code': 'LOCATION_UNAVAILABLE',
            'error': 'LOCATION_UNAVAILABLE',
            'message': 'Customer GPS coordinates required for 15 km spatial verification.',
            'availableTechnicianCount': 0,
            'totalOnlineTechnicians': 0,
          }, 400);
        }

        final allTechs = await listCollection('technician_profiles', forceRefresh: forceRefresh);
        if (isLastRequestQuotaExceeded) {
          return _jsonResponse({
            'success': false,
            'code': 'QUOTA_EXCEEDED',
            'error': 'RESOURCE_EXHAUSTED',
            'message': 'Firestore rate limit or quota exceeded (HTTP 429). Retries exhausted.',
            'isQuotaExceeded': true,
            'availableTechnicianCount': 0,
            'totalOnlineTechnicians': 0,
          }, 429);
        }
        if (isLastRequestNetworkError) {
          return _jsonResponse({
            'success': false,
            'code': 'NETWORK_ERROR',
            'error': 'NETWORK_ERROR',
            'message': 'Unable to reach Cloud Firestore to verify live technician availability.',
            'availableTechnicianCount': 0,
            'totalOnlineTechnicians': 0,
          }, 503);
        }

        // Authoritative 10-condition eligibility evaluation + Strict Geo-Radius Scan (Zero Out-Of-Radius Fallback)
        final reachableTechs = <Map<String, dynamic>>[];
        for (final t in allTechs) {
          final eval = evaluateTechnicianEligibility(
            t,
            customerLat: targetLat,
            customerLng: targetLng,
            radiusKm: radiusKm,
            checkSkill: false,
          );
          if (eval['eligible'] != true) continue;

          final dist = (eval['distanceKm'] as num).toDouble();
          reachableTechs.add({
            ...t,
            'id': t['id'],
            'technicianId': t['technicianId'] ?? t['id'],
            'technicianCode': t['technicianCode'] ?? 'BT-TECH',
            'fullName': t['fullName'] ?? 'Partner Technician',
            'rating': (t['rating'] as num?)?.toDouble() ?? 0.0,
            'category': t['category'] ?? '',
            'categories': t['categories'] ?? [],
            'skills': t['skills'] ?? [],
            'selectedSkills': t['selectedSkills'] ?? [],
            'distanceKm': double.parse(dist.toStringAsFixed(2)),
            'locationFresh': true,
            'isOnline': true,
            'availabilityStatus': 'AVAILABLE',
          });
        }
        final candidateTechsForCatalog = reachableTechs;

        final categories = await listCollection('service_categories');
        final List<Map<String, dynamic>> servicesList = [];
        final Map<String, int> serviceCounts = {};

        String? targetServiceId = queryParams['serviceId'] ?? (body != null ? body['serviceId']?.toString() : null);
        if (targetServiceId == null && cleanPath.contains('/services/')) {
          final parts = cleanPath.split('/services/').last.split('/');
          if (parts.isNotEmpty && parts.first != 'availability') {
            targetServiceId = parts.first;
          }
        }

        for (final cat in categories) {
          final subcategories = cat['subcategories'] as List<dynamic>? ?? [];
          for (final sub in subcategories) {
            if (sub is Map<String, dynamic>) {
              final services = sub['services'] as List<dynamic>? ?? [];
              for (final s in services) {
                if (s is Map<String, dynamic>) {
                  final sId = s['id']?.toString() ?? '';
                  final sName = s['name']?.toString() ?? '';
                  if (sId.isNotEmpty) {
                    int matchingCount = 0;
                    for (final tech in candidateTechsForCatalog) {
                      if (_doesTechnicianMatchService(tech, sId, sName)) {
                        matchingCount++;
                      }
                    }
                    serviceCounts[sId] = matchingCount;
                    final canonicalKey = resolveCanonicalServiceId(sId, name: sName);
                    if (canonicalKey.isNotEmpty) {
                      serviceCounts[canonicalKey] = matchingCount;
                    }
                    servicesList.add({
                      'serviceId': sId,
                      'availableTechnicianCount': matchingCount,
                    });
                  }
                }
              }
            }
          }
        }

        int targetCount = candidateTechsForCatalog.length;
        if (targetServiceId != null && targetServiceId.isNotEmpty) {
          final targetCanonical = resolveCanonicalServiceId(targetServiceId);
          if (serviceCounts.containsKey(targetServiceId)) {
            targetCount = serviceCounts[targetServiceId] ?? 0;
          } else if (targetCanonical.isNotEmpty && serviceCounts.containsKey(targetCanonical)) {
            targetCount = serviceCounts[targetCanonical] ?? 0;
          } else {
            int directCount = 0;
            for (final tech in candidateTechsForCatalog) {
              if (_doesTechnicianMatchService(tech, targetServiceId, '')) {
                directCount++;
              }
            }
            targetCount = directCount;
          }
          if (!servicesList.any((e) => e['serviceId'] == targetServiceId)) {
            servicesList.add({
              'serviceId': targetServiceId,
              'availableTechnicianCount': targetCount,
            });
          }
        }

        return _jsonResponse({
          'success': true,
          'services': servicesList,
          'data': servicesList,
          'availableTechnicianCount': targetCount,
          'totalOnlineTechnicians': candidateTechsForCatalog.length,
          'count': targetCount,
          'isAuthoritative': true,
          'isCached': false,
          'verifiedAt': DateTime.now().toUtc().toIso8601String(),
        });
      }

      // 2. Real-time Nearby Technicians Roster (With Strict PII Redaction & 10-Min Heartbeat Check)
      if (cleanPath.contains('/technicians/nearby') ||
          (cleanPath.contains('/technicians') && !cleanPath.contains('/skills'))) {
        final uri = Uri.parse(endpoint.startsWith('http') ? endpoint : 'http://localhost$endpoint');
        final queryParams = uri.queryParameters;
        final targetLat = double.tryParse(queryParams['latitude'] ?? '') ??
            (body != null && body['latitude'] is num ? (body['latitude'] as num).toDouble() : 22.5726);
        final targetLng = double.tryParse(queryParams['longitude'] ?? '') ??
            (body != null && body['longitude'] is num ? (body['longitude'] as num).toDouble() : 88.3639);
        final requestedServiceId = queryParams['serviceId'] ?? (body != null ? body['serviceId']?.toString() : null);
        final requestedCatId = queryParams['categoryId'] ?? (body != null ? body['categoryId']?.toString() : null);
        final radiusKm = double.tryParse(queryParams['radiusKm'] ?? '') ?? 15.0;

        final allTechs = await listCollection('technician_profiles', forceRefresh: true);
        if (isLastRequestQuotaExceeded) {
          return _jsonResponse({
            'success': false,
            'code': 'QUOTA_EXCEEDED',
            'error': 'RESOURCE_EXHAUSTED',
            'isQuotaExceeded': true,
            'technicians': [],
          }, 429);
        }

        final nearbyList = <Map<String, dynamic>>[];
        for (final tech in allTechs) {
          final eval = evaluateTechnicianEligibility(
            tech,
            serviceId: requestedServiceId,
            customerLat: targetLat,
            customerLng: targetLng,
            radiusKm: radiusKm,
          );
          if (eval['eligible'] != true) continue;

          final distKm = (eval['distanceKm'] as num).toDouble();
          final distMeters = distKm * 1000;
          final arrivalMins = max(8, (distKm * 3.5).round());

          final tId = tech['id']?.toString() ?? tech['technicianId']?.toString() ?? 'tech_partner';
          final digits = tId.replaceAll(RegExp(r'\D'), '');
          final tCode = tech['technicianCode']?.toString() ??
              'BT-${(digits.length >= 6 ? digits.substring(digits.length - 6) : digits.padLeft(6, '0'))}';

          // Redact PII: never expose raw phone, email, or exact street/home GPS before assignment!
          nearbyList.add({
            'technicianId': tId,
            'technicianCode': tCode,
            'fullName': tech['fullName'] ?? tech['name'] ?? 'Service Partner',
            'category': tech['category'] ?? '',
            'profileImageUrl': tech['profileImageUrl'] ?? '',
            'experienceYears': (tech['experienceYears'] as num?)?.toInt() ?? 0,
            'rating': (tech['rating'] as num?)?.toDouble() ?? 0.0,
            'totalRatingsCount': (tech['totalRatingsCount'] as num?)?.toInt() ?? 0,
            'totalJobsCompleted': (tech['totalJobsCompleted'] as num?)?.toInt() ?? 0,
            'distanceKm': double.parse(distKm.toStringAsFixed(2)),
            'distanceMeters': distMeters.round(),
            'estimatedArrivalMinutes': arrivalMins,
            'isOnline': true,
            'locationFresh': true,
            'availabilityStatus': 'AVAILABLE',
          });
        }

        return _jsonResponse({
          'success': true,
          'serviceId': requestedServiceId ?? '',
          'serviceName': requestedServiceId ?? 'Service',
          'categoryId': requestedCatId ?? '',
          'latitude': targetLat,
          'longitude': targetLng,
          'radiusKm': radiusKm,
          'totalOnlineTechnicians': nearbyList.length,
          'updatedAt': DateTime.now().toUtc().toIso8601String(),
          'technicians': nearbyList,
          'data': nearbyList,
        });
      }

      // 3. Catalog Categories & Services
      if (cleanPath.contains('/catalog') || cleanPath.contains('/services')) {
        if (cleanPath.contains('/banners')) {
          final banners = await listCollection('banners');
          return _jsonResponse({'success': true, 'data': banners});
        }
        final categories = await listCollection('service_categories');
        categories.sort((a, b) =>
            ((a['displayOrder'] as num?) ?? 99)
                .compareTo((b['displayOrder'] as num?) ?? 99));
        return _jsonResponse({
          'success': true,
          'data': categories,
          'categories': categories,
        });
      }

      // 4. Auth Request OTP / Verify OTP
      // Strictly disabled when trusted backend is configured; never mint fake client tokens.
      if (cleanPath.contains('/auth/')) {
        if (AppConfig.hasConfiguredBackend) {
          return _jsonResponse({
            'success': false,
            'retryable': true,
            'code': 'BACKEND_REQUIRED',
            'error': 'Authentication requires the trusted backend server. Client fallback is disabled.',
          }, 503);
        }
        return _jsonResponse({
          'success': false,
          'retryable': true,
          'code': 'BACKEND_REQUIRED',
          'error': 'Authentication server is required for OTP verification.',
        }, 503);
      }

      // 5. FCM Push Token Registration
      if (cleanPath.contains('/fcm-token') && m == 'POST' && body != null) {
        final userId = body['userId']?.toString() ?? '';
        final token = body['token']?.toString() ?? body['fcmToken']?.toString() ?? '';
        if (userId.isNotEmpty && token.isNotEmpty) {
          await upsertDocument('users', userId, {
            'fcmToken': token,
            'fcmTokenUpdatedAt': DateTime.now().toUtc().toIso8601String(),
            'platform': body['platform'] ?? 'android',
          });
        }
        return _jsonResponse({'success': true, 'message': 'FCM token synced to Firestore'});
      }

      // 6. Atomic Booking Assignment & Pre-Assignment Revalidation (Phase 4.1)
      if (cleanPath.contains('/bookings')) {
        if (m == 'POST' && body != null && !cleanPath.contains('/cancel')) {
          final customerId = body['customerId']?.toString() ?? 'cust_default';
          final serviceId = body['serviceId']?.toString() ?? '';
          final serviceName = body['serviceName']?.toString() ?? body['service']?.toString() ?? '';
          final idempotencyKey = body['idempotencyKey']?.toString() ??
              '${customerId}_${serviceId}_${body['scheduleDate'] ?? ''}_${body['scheduleSlot'] ?? ''}';

          // 6.1 Duplicate Booking / Idempotency Guard
          if (idempotencyKey.isNotEmpty && _idempotencyBookingMap.containsKey(idempotencyKey)) {
            return _jsonResponse({
              'success': false,
              'code': 'DUPLICATE_BOOKING',
              'error': 'DUPLICATE_BOOKING',
              'message': 'A booking request for this service is already active or in progress.',
              'existingBookingId': _idempotencyBookingMap[idempotencyKey],
            }, 409);
          }

          final custLat = (body['latitude'] as num?)?.toDouble();
          final custLng = (body['longitude'] as num?)?.toDouble();
          if (custLat == null || custLng == null || custLat == 0.0 || custLng == 0.0) {
            return _jsonResponse({
              'success': false,
              'code': 'LOCATION_UNAVAILABLE',
              'error': 'LOCATION_UNAVAILABLE',
              'message': 'Customer GPS coordinates are required to verify technician radius.',
            }, 400);
          }

          // 6.2 Live Server Revalidation (forceRefresh: true — NEVER authorize from cache!)
          final allTechs = await listCollection('technician_profiles', forceRefresh: true);
          if (isLastRequestQuotaExceeded) {
            return _jsonResponse({
              'success': false,
              'code': 'QUOTA_EXCEEDED',
              'error': 'QUOTA_EXCEEDED',
              'message': 'Firestore quota exceeded (HTTP 429). Cannot verify technician availability.',
            }, 429);
          }
          if (isLastRequestNetworkError) {
            return _jsonResponse({
              'success': false,
              'code': 'NETWORK_ERROR',
              'error': 'NETWORK_ERROR',
              'message': 'Network disconnection while verifying live technician availability.',
            }, 503);
          }

          final existingBookings = await listCollection('bookings', forceRefresh: true);
          if (isLastRequestQuotaExceeded) {
            return _jsonResponse({
              'success': false,
              'code': 'QUOTA_EXCEEDED',
              'error': 'QUOTA_EXCEEDED',
              'message': 'Firestore quota exceeded (HTTP 429) while checking active bookings.',
            }, 429);
          }

          // Also check if customer already has an active duplicate booking in Firestore
          final hasDuplicateCustomerBooking = existingBookings.any((b) {
            final st = (b['status']?.toString() ?? '').toUpperCase();
            final isActive = ['CONFIRMED', 'ASSIGNED', 'ACCEPTED', 'IN_PROGRESS'].contains(st);
            return isActive &&
                b['customerId']?.toString() == customerId &&
                b['serviceId']?.toString() == serviceId &&
                (body['idempotencyKey'] != null && b['idempotencyKey'] == body['idempotencyKey']);
          });
          if (hasDuplicateCustomerBooking) {
            return _jsonResponse({
              'success': false,
              'code': 'DUPLICATE_BOOKING',
              'error': 'DUPLICATE_BOOKING',
              'message': 'Duplicate booking request rejected.',
            }, 409);
          }

          // Build set of busy technician IDs from active bookings
          final busyTechIds = <String>{};
          for (final b in existingBookings) {
            final st = (b['status']?.toString() ?? '').toUpperCase();
            if (['ASSIGNED', 'ACCEPTED', 'IN_PROGRESS', 'TECHNICIAN_ARRIVED'].contains(st)) {
              final tId = b['technicianId']?.toString();
              if (tId != null && tId.isNotEmpty) {
                busyTechIds.add(tId);
              }
            }
          }

          final requestedTechId = body['technicianId']?.toString();
          bool sawOfflineTech = false;
          bool sawStaleLocation = false;
          bool sawSkillMismatch = false;
          bool sawOutOfRadius = false;
          bool sawBusyConflict = false;
          bool sawUnverifiedAccountOrKyc = false;

          final eligibleCandidates = <Map<String, dynamic>>[];

          for (final tech in allTechs) {
            final tId = tech['id']?.toString() ?? tech['technicianId']?.toString() ?? '';
            if (tId.isEmpty) continue;
            if (requestedTechId != null && requestedTechId.isNotEmpty && tId != requestedTechId) {
              continue;
            }

            final eval = evaluateTechnicianEligibility(
              tech,
              serviceId: serviceId,
              serviceName: serviceName,
              customerLat: custLat,
              customerLng: custLng,
              radiusKm: 15.0,
              busyTechIds: busyTechIds,
            );
            if (eval['eligible'] != true) {
              switch (eval['reason']) {
                case 'TECHNICIAN_BUSY_CONFLICT':
                  sawBusyConflict = true;
                  break;
                case 'TECHNICIAN_WENT_OFFLINE':
                  sawOfflineTech = true;
                  break;
                case 'STALE_LOCATION':
                  sawStaleLocation = true;
                  break;
                case 'OUT_OF_RADIUS':
                  sawOutOfRadius = true;
                  break;
                case 'SKILL_MISMATCH':
                  sawSkillMismatch = true;
                  break;
                case 'ACCOUNT_NOT_ACTIVE':
                case 'KYC_NOT_VERIFIED':
                  sawUnverifiedAccountOrKyc = true;
                  break;
              }
              continue;
            }

            eligibleCandidates.add({
              ...tech,
              'id': tId,
              'distanceKm': (eval['distanceKm'] as num).toDouble(),
            });
          }

          final candidatesToPickFrom = eligibleCandidates;
          if (candidatesToPickFrom.isEmpty) {
            String failureCode = 'NO_TECHNICIAN_ONLINE';
            String failureMessage = 'No online technician is currently available for this service.';
            if (sawBusyConflict) {
              failureCode = 'TECHNICIAN_BUSY_CONFLICT';
              failureMessage = 'Technician was just assigned to another customer booking.';
            } else if (sawOfflineTech) {
              failureCode = 'TECHNICIAN_WENT_OFFLINE';
              failureMessage = 'No verified technician is currently online for this service.';
            } else if (sawStaleLocation) {
              failureCode = 'STALE_LOCATION';
              failureMessage = 'Technician GPS location is stale (>10 minutes old). Cannot assign safely.';
            } else if (sawOutOfRadius) {
              failureCode = 'OUT_OF_RADIUS';
              failureMessage = 'No technician with this skill is within the service area.';
            } else if (sawSkillMismatch) {
              failureCode = 'SKILL_MISMATCH';
              failureMessage = 'Online technicians near you do not have the required service skill enabled.';
            } else if (sawUnverifiedAccountOrKyc) {
              failureCode = 'TECHNICIAN_NOT_VERIFIED';
              failureMessage = 'No active, KYC-verified technician is currently available for this service.';
            }

            return _jsonResponse({
              'success': false,
              'code': failureCode,
              'error': failureCode,
              'message': failureMessage,
            }, 409);
          }

          // Sort by closest distance to find the absolute NEAREST online technician
          candidatesToPickFrom.sort((a, b) =>
              (a['distanceKm'] as double).compareTo(b['distanceKm'] as double));
          final winner = candidatesToPickFrom.first;
          final winnerId = winner['id'].toString();
          final winnerName = winner['fullName']?.toString() ?? winner['name']?.toString() ?? 'Partner Technician';
          final winnerPhone = winner['phone']?.toString() ?? '';
          final digits = winnerId.replaceAll(RegExp(r'\D'), '');
          final winnerCode = winner['technicianCode']?.toString() ??
              'BT-${(digits.length >= 6 ? digits.substring(digits.length - 6) : digits.padLeft(6, '0'))}';

          final bookingId =
              body['id']?.toString() ?? 'BK-${100000 + _secureRandom.nextInt(900000)}';
          final startOtp = (1000 + _secureRandom.nextInt(9000)).toString();
          final endOtp = (1000 + _secureRandom.nextInt(9000)).toString();
          final nowIso = DateTime.now().toUtc().toIso8601String();

          final newBooking = <String, dynamic>{
            ...body,
            'id': bookingId,
            'bookingCode': bookingId,
            'status': 'ASSIGNED',
            'technicianId': winnerId,
            'technicianCode': winnerCode,
            'technicianName': winnerName,
            'technicianPhone': winnerPhone,
            'distanceKm': double.parse((winner['distanceKm'] as double).toStringAsFixed(2)),
            'startOtp': startOtp,
            'endOtp': endOtp,
            'idempotencyKey': idempotencyKey,
            'assignedAt': nowIso,
            'createdAt': nowIso,
            'updatedAt': nowIso,
          };

          // 6.3 Execute Atomic Firestore Transaction (:commit with currentDocument.updateTime precondition)
          final commitResult = await atomicAssignBookingTransaction(
            bookingId: bookingId,
            bookingDoc: newBooking,
            technicianId: winnerId,
            expectedTechUpdateTime: winner['_firestoreUpdateTime']?.toString(),
          );

          if (commitResult['success'] != true) {
            final status = (commitResult['statusCode'] as int?) ?? 409;
            return _jsonResponse({
              'success': false,
              'code': commitResult['code'] ?? 'TECHNICIAN_BUSY_CONFLICT',
              'error': commitResult['code'] ?? 'TECHNICIAN_BUSY_CONFLICT',
              'message': commitResult['error'] ?? 'Booking assignment failed.',
            }, status);
          }

          if (idempotencyKey.isNotEmpty) {
            _idempotencyBookingMap[idempotencyKey] = bookingId;
          }

          // Create authoritative dispatch_offer record for immediate technician audible ringtone & alert popup
          final offerId = 'offer_${bookingId}_$winnerId';
          final expiresAt = DateTime.now().toUtc().add(const Duration(seconds: 30)).toIso8601String();
          upsertDocument('dispatch_offers', offerId, {
            'id': offerId,
            'offerId': offerId,
            'bookingId': bookingId,
            'bookingCode': bookingId,
            'technicianId': winnerId,
            'serviceId': serviceId,
            'serviceName': serviceName,
            'approximateArea': body['address'] ?? body['fullAddress'] ?? 'Nearby Customer Area',
            'distanceKm': double.parse((winner['distanceKm'] as double).toStringAsFixed(2)),
            'expectedEarning': (((body['basePrice'] ?? body['price'] ?? 299) as num).toDouble() * 0.8).round(),
            'payout': (((body['basePrice'] ?? body['price'] ?? 299) as num).toDouble() * 0.8).round(),
            'totalAmount': body['grandTotal'] ?? body['totalAmount'] ?? 299,
            'status': 'SENT',
            'timeoutSeconds': 30,
            'expiresAt': expiresAt,
            'createdAt': nowIso,
          }).catchError((_) => null);

          return _jsonResponse({
            'success': true,
            'booking': newBooking,
            'data': newBooking,
          }, 201);
        }

        if (cleanPath.contains('/cancel') && m == 'POST') {
          final parts = cleanPath.split('/');
          final bId = parts.length >= 3 ? parts[parts.length - 2] : '';
          if (bId.isNotEmpty) {
            final updated = await upsertDocument('bookings', bId, {
              'status': 'CANCELLED',
              'cancellationReason': body?['reason'] ?? 'Cancelled by customer',
            });
            return _jsonResponse({'success': true, 'data': updated});
          }
        }

        if ((cleanPath.contains('/resend-start-otp') || cleanPath.contains('/resend-end-otp')) && m == 'POST') {
          final parts = cleanPath.split('/');
          final bIndex = parts.indexOf('bookings');
          final bId = bIndex != -1 && parts.length > bIndex + 1 ? parts[bIndex + 1] : '';
          final booking = bId.isNotEmpty ? await getDocument('bookings', bId) : null;
          return _jsonResponse({
            'success': true,
            'message': 'OTP resent successfully',
            'data': booking,
            'startOtp': booking?['startOtp'],
            'endOtp': booking?['endOtp'],
          });
        }

        if (m == 'GET') {
          final parts = cleanPath.split('/');
          final bookingIdx = parts.indexOf('bookings');
          if (bookingIdx != -1 && parts.length > bookingIdx + 1 && parts[bookingIdx + 1].isNotEmpty && parts[bookingIdx + 1] != 'my-bookings') {
            final bId = parts[bookingIdx + 1];
            final singleBooking = await getDocument('bookings', bId);
            return _jsonResponse({
              'success': true,
              'data': singleBooking,
              'booking': singleBooking,
              'tracking': singleBooking,
            });
          }
          final bookings = await listCollection('bookings');
          return _jsonResponse({
            'success': true,
            'bookings': bookings,
            'data': bookings,
          });
        }
      }

      return _jsonResponse({'success': true, 'data': {}});
    } catch (e) {
      return _jsonResponse({'success': false, 'code': 'INTERNAL_ERROR', 'message': e.toString()}, 500);
    }
  }

  static http.Response _jsonResponse(Map<String, dynamic> data,
      [int statusCode = 200]) {
    return http.Response(
      jsonEncode(data),
      statusCode,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );
  }
}


class _CachedResult {
  final DateTime timestamp;
  final dynamic data;
  _CachedResult(this.timestamp, this.data);
}


