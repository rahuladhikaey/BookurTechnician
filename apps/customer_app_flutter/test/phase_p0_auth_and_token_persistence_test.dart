import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:customer_app_flutter/config/app_config.dart';
import 'package:customer_app_flutter/services/api_client.dart';
import 'package:customer_app_flutter/services/firestore_rest_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

String _makeJwt({required String alg, required Map<String, dynamic> payload}) {
  final header = base64Url.encode(utf8.encode(jsonEncode({'alg': alg, 'typ': 'JWT'}))).replaceAll('=', '');
  final body = base64Url.encode(utf8.encode(jsonEncode(payload))).replaceAll('=', '');
  return '$header.$body.sig';
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() async {
    AppConfig.testBackendBaseUrlOverride = null;
    ApiClient.testHttpClient = null;
    ApiClient.testTimeoutOverride = null;
    FirestoreRestClient.mockHttpHandler = null;
    FirestoreRestClient.authHttpHandler = null;
    await FirestoreRestClient.clearFirebaseSession();
  });

  group('Phase 4 & 5 Customer P0 Security Hardening', () {
    test('OTP endpoints NEVER fall back to client OTP on network error, timeout, 401, 403, or 5xx', () async {
      SharedPreferences.setMockInitialValues({});
      AppConfig.testBackendBaseUrlOverride = 'https://trusted-render.example.com';

      bool clientFirestoreAuthCalled = false;
      FirestoreRestClient.mockHttpHandler = (method, uri, {headers, body}) async {
        clientFirestoreAuthCalled = true;
        return http.Response('{}', 200);
      };

      // 1. Network exception (SocketException) on request-otp / verify-otp / resend-otp -> 503 retryable, NO fallback
      ApiClient.testHttpClient = MockClient((request) async {
        throw const SocketException('Network unreachable');
      });

      for (final path in ['/auth/request-otp', '/auth/verify-otp', '/auth/resend-otp']) {
        final res = await ApiClient.post(path, {'email': 'cust@example.com', 'otp': '123456'});
        expect(res.statusCode, 503);
        final decoded = jsonDecode(res.body) as Map<String, dynamic>;
        expect(decoded['success'], isFalse);
        expect(decoded['retryable'], isTrue);
        expect(decoded['code'], 'BACKEND_UNAVAILABLE');
        expect(decoded['accessToken']?.toString().startsWith('fb_cust_tok_') ?? false, isFalse);
      }

      // 2. Timeout -> 503 retryable, NO fallback
      ApiClient.testTimeoutOverride = const Duration(milliseconds: 50);
      ApiClient.testHttpClient = MockClient((request) async {
        await Future.delayed(const Duration(milliseconds: 250));
        return http.Response('{}', 200);
      });
      final timeoutRes = await ApiClient.post('/auth/request-otp', {'email': 'cust@example.com'});
      expect(timeoutRes.statusCode, 503);
      expect((jsonDecode(timeoutRes.body) as Map)['retryable'], isTrue);
      ApiClient.testTimeoutOverride = null;

      // 3. Authoritative 401 & 403 & 500 -> NO client OTP fallback
      for (final code in [401, 403, 500, 502]) {
        ApiClient.testHttpClient = MockClient((request) async {
          return http.Response(jsonEncode({'success': false, 'error': 'HTTP $code'}), code);
        });
        final res = await ApiClient.post('/auth/verify-otp', {'email': 'cust@example.com', 'otp': '111111'});
        expect(res.statusCode, code);
        final decoded = jsonDecode(res.body) as Map<String, dynamic>;
        expect(decoded['success'], isFalse);
        if (code >= 500) {
          expect(decoded['retryable'], isTrue);
        }
      }

      expect(clientFirestoreAuthCalled, isFalse, reason: 'Firestore fallback must NEVER run for OTP endpoints');
    });

    test('Firebase ID/Refresh tokens stay separate from Render HS256 JWT, persist across restart, refresh safely, and never fall back to Anonymous Auth', () async {
      SharedPreferences.setMockInitialValues({});
      AppConfig.testBackendBaseUrlOverride = 'https://trusted-render.example.com';

      final nowSec = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
      final renderAccessJwt = _makeJwt(alg: 'HS256', payload: {'uid': 'uid_cust_42', 'role': 'CUSTOMER', 'exp': nowSec + 3600});
      final renderRefreshJwt = _makeJwt(alg: 'HS256', payload: {'uid': 'uid_cust_42', 'tokenType': 'refresh', 'exp': nowSec + 86400});

      final expiredFirebaseIdToken = _makeJwt(
        alg: 'RS256',
        payload: {'sub': 'uid_cust_42', 'user_id': 'uid_cust_42', 'exp': nowSec - 120},
      );
      final freshFirebaseIdToken = _makeJwt(
        alg: 'RS256',
        payload: {'sub': 'uid_cust_42', 'user_id': 'uid_cust_42', 'exp': nowSec + 3600},
      );

      bool anonymousSignUpCalled = false;
      final List<String> sentGrantRefreshTokens = [];

      FirestoreRestClient.authHttpHandler = (method, uri, {headers, body}) async {
        final uriStr = uri.toString();
        if (uriStr.contains('accounts:signInWithCustomToken')) {
          return http.Response(
            jsonEncode({
              'idToken': expiredFirebaseIdToken,
              'refreshToken': 'opaque_fb_refresh_tok_1',
              'expiresIn': '10', // already expired payload for testing refresh after restart
            }),
            200,
          );
        }
        if (uriStr.contains('securetoken.googleapis.com/v1/token')) {
          final form = Uri.splitQueryString(body ?? '');
          sentGrantRefreshTokens.add(form['refresh_token'] ?? '');
          return http.Response(
            jsonEncode({
              'id_token': freshFirebaseIdToken,
              'refresh_token': 'opaque_fb_refresh_tok_2',
              'user_id': 'uid_cust_42',
              'expires_in': '3600',
            }),
            200,
          );
        }
        if (uriStr.contains('accounts:signUp')) {
          anonymousSignUpCalled = true;
          return http.Response(jsonEncode({'idToken': 'anon', 'localId': 'anon_uid'}), 200);
        }
        return http.Response('{}', 404);
      };

      // Simulate login storing Render JWTs + Firebase Custom Token exchange separately
      final fbLogin = await FirestoreRestClient.signInWithCustomToken('custom_tok_for_cust_42');
      expect(fbLogin?['uid'], 'uid_cust_42');
      await ApiClient.saveUserSession(
        accessToken: renderAccessJwt,
        refreshToken: renderRefreshJwt,
        userId: 'uid_cust_42',
        name: 'Cust User',
        phone: '+919999999999',
        email: 'cust42@example.com',
      );

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('bt_access_token'), renderAccessJwt);
      expect(prefs.getString('bt_refresh_token'), renderRefreshJwt);
      expect(prefs.getString('bt_firebase_id_token'), expiredFirebaseIdToken);
      expect(prefs.getString('bt_firebase_refresh_token'), 'opaque_fb_refresh_tok_1');
      expect(prefs.getString('bt_firebase_uid'), 'uid_cust_42');

      // Validate HS256 JWT is strictly rejected by Firebase token format guard
      expect(FirestoreRestClient.isFirebaseIdTokenFormat(renderAccessJwt), isFalse);
      expect(FirestoreRestClient.isFirebaseIdTokenFormat(freshFirebaseIdToken), isTrue);

      // Simulate app restart (wipe ONLY static in-memory fields while preserving SharedPreferences!)
      FirestoreRestClient.clearMemoryCache();
      FirestoreRestClient.resetInMemoryFirebaseAuthForTest();
      await prefs.setInt('bt_firebase_expires_at_ms', DateTime.now().toUtc().subtract(const Duration(minutes: 5)).millisecondsSinceEpoch);
      final restored = await FirestoreRestClient.restoreFirebaseSession();
      expect(restored?['uid'], 'uid_cust_42');

      // Getting valid Firebase ID token after restart refreshes using Firebase refresh token (NEVER Render HS256 JWT!)
      final validToken = await FirestoreRestClient.getValidFirebaseIdToken();
      expect(validToken, freshFirebaseIdToken);
      expect(sentGrantRefreshTokens, ['opaque_fb_refresh_tok_1']);
      expect(FirestoreRestClient.currentFirebaseUid, 'uid_cust_42');
      expect(anonymousSignUpCalled, isFalse);

      // Even if Firebase refresh fails for an authenticated user, must NEVER fall back to Anonymous Auth
      await prefs.setString('bt_firebase_refresh_token', 'revoked_refresh');
      await prefs.setInt('bt_firebase_expires_at_ms', DateTime.now().toUtc().subtract(const Duration(minutes: 5)).millisecondsSinceEpoch);
      await FirestoreRestClient.restoreFirebaseSession();
      FirestoreRestClient.authHttpHandler = (method, uri, {headers, body}) async {
        if (uri.toString().contains('accounts:signUp')) {
          anonymousSignUpCalled = true;
        }
        return http.Response(jsonEncode({'error': {'message': 'TOKEN_EXPIRED'}}), 400);
      };
      final afterFailToken = await FirestoreRestClient.getValidFirebaseIdToken(forceRefresh: true, allowAnonymousFallback: true);
      expect(afterFailToken, isNull);
      expect(anonymousSignUpCalled, isFalse, reason: 'Authenticated customer session must NEVER fall back to Anonymous Auth');

      // Logout clears both Render and Firebase sessions
      await ApiClient.clearTokens();
      expect(await ApiClient.getAccessToken(), isNull);
      expect(await FirestoreRestClient.restoreFirebaseSession(), isNull);
    });
  });
}
