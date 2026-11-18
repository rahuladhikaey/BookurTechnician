import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:technician_app/core/config/app_config.dart';
import 'package:technician_app/core/network/api_result.dart';
import 'package:technician_app/core/network/firestore_rest_client.dart';
import 'package:technician_app/core/security/secure_storage.dart';
import 'package:technician_app/features/auth/presentation/auth_provider.dart';

String _makeJwt({required String alg, required Map<String, dynamic> payload}) {
  final header = base64Url.encode(utf8.encode(jsonEncode({'alg': alg, 'typ': 'JWT'}))).replaceAll('=', '');
  final body = base64Url.encode(utf8.encode(jsonEncode(payload))).replaceAll('=', '');
  return '$header.$body.sig';
}

class _StubHttpAdapter implements HttpClientAdapter {
  final Future<ResponseBody> Function(RequestOptions options) onFetch;
  _StubHttpAdapter(this.onFetch);

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) =>
      onFetch(options);

  @override
  void close({bool force = false}) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() async {
    AppConfig.testBackendBaseUrlOverride = null;
    FirestoreRestClient.mockHttpHandler = null;
    FirestoreRestClient.authHttpHandler = null;
    await FirestoreRestClient.clearFirebaseSession();
  });

  group('Phase 4 & 5 Technician P0 Security Hardening', () {
    test('Technician OTP requests NEVER fall back to client OTP on network error, timeout, 401, 403, or 5xx', () async {
      SharedPreferences.setMockInitialValues({});
      AppConfig.testBackendBaseUrlOverride = 'https://trusted-render.example.com';

      bool clientChallengeOrFirebasePasswordCalled = false;
      FirestoreRestClient.mockHttpHandler = (method, uri, {headers, body}) async {
        clientChallengeOrFirebasePasswordCalled = true;
        return http.Response('{}', 200);
      };
      FirestoreRestClient.authHttpHandler = (method, uri, {headers, body}) async {
        clientChallengeOrFirebasePasswordCalled = true;
        return http.Response('{}', 200);
      };

      // Network failure & timeout
      final networkFailDio = Dio()
        ..httpClientAdapter = _StubHttpAdapter((options) async {
          throw DioException(
            requestOptions: options,
            type: DioExceptionType.connectionTimeout,
            error: const SocketException('Timeout'),
          );
        });

      final notifier1 = AuthNotifier(storage: SecureStorage(), authDio: networkFailDio);
      final reqRes = await notifier1.requestOtp('+919876543210', email: 'tech@example.com', fullName: 'Tech One');
      expect(reqRes, isA<ApiFailure<bool>>());
      final verRes = await notifier1.verifyOtp('+919876543210', '123456', email: 'tech@example.com');
      expect(verRes, isA<ApiFailure<String>>());

      // Authoritative 401, 403, 503 responses
      for (final status in [401, 403, 500, 503]) {
        final errDio = Dio()
          ..httpClientAdapter = _StubHttpAdapter((options) async {
            return ResponseBody.fromString(
              jsonEncode({'success': false, 'error': 'Backend status $status'}),
              status,
              headers: {
                Headers.contentTypeHeader: [Headers.jsonContentType],
              },
            );
          });
        final notifier2 = AuthNotifier(storage: SecureStorage(), authDio: errDio);
        final r1 = await notifier2.requestOtp('+919876543210', email: 'tech@example.com');
        final r2 = await notifier2.verifyOtp('+919876543210', '123456', email: 'tech@example.com');
        expect(r1, isA<ApiFailure<bool>>());
        expect(r2, isA<ApiFailure<String>>());
      }

      expect(clientChallengeOrFirebasePasswordCalled, isFalse);
    });

    test('Firebase ID/Refresh tokens stay separate from Render JWTs, persist across restart, and refresh safely', () async {
      SharedPreferences.setMockInitialValues({});
      AppConfig.testBackendBaseUrlOverride = 'https://trusted-render.example.com';

      final nowSec = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
      final renderAccessJwt = _makeJwt(alg: 'HS256', payload: {'uid': 'uid_tech_9876543210', 'role': 'TECHNICIAN', 'exp': nowSec + 3600});
      final renderRefreshJwt = _makeJwt(alg: 'HS256', payload: {'uid': 'uid_tech_9876543210', 'tokenType': 'refresh', 'exp': nowSec + 86400});
      final initialFbIdToken = _makeJwt(alg: 'RS256', payload: {'sub': 'uid_tech_9876543210', 'user_id': 'uid_tech_9876543210', 'exp': nowSec + 3600});
      final expiredFbIdToken = _makeJwt(alg: 'RS256', payload: {'sub': 'uid_tech_9876543210', 'user_id': 'uid_tech_9876543210', 'exp': nowSec - 60});
      final freshFbIdToken = _makeJwt(alg: 'RS256', payload: {'sub': 'uid_tech_9876543210', 'user_id': 'uid_tech_9876543210', 'exp': nowSec + 7200});

      final List<String> refreshGrants = [];
      FirestoreRestClient.authHttpHandler = (method, uri, {headers, body}) async {
        if (uri.toString().contains('accounts:signInWithCustomToken')) {
          return http.Response(
            jsonEncode({
              'idToken': initialFbIdToken,
              'refreshToken': 'tech_fb_refresh_1',
              'expiresIn': '3600',
            }),
            200,
          );
        }
        if (uri.toString().contains('securetoken.googleapis.com/v1/token')) {
          final form = Uri.splitQueryString(body ?? '');
          refreshGrants.add(form['refresh_token'] ?? '');
          return http.Response(
            jsonEncode({
              'id_token': freshFbIdToken,
              'refresh_token': 'tech_fb_refresh_2',
              'user_id': 'uid_tech_9876543210',
              'expires_in': '3600',
            }),
            200,
          );
        }
        return http.Response('{}', 404);
      };

      final loginDio = Dio()
        ..httpClientAdapter = _StubHttpAdapter((options) async {
          if (options.path.endsWith('/auth/verify-otp')) {
            return ResponseBody.fromString(
              jsonEncode({
                'success': true,
                'accessToken': renderAccessJwt,
                'refreshToken': renderRefreshJwt,
                'firebaseCustomToken': 'fb_custom_tok_tech',
                'user': {
                  'uid': 'uid_tech_9876543210',
                  'technicianCode': 'BT-543210',
                  'fullName': 'Tech Partner',
                  'phone': '+919876543210',
                  'email': 'tech@example.com',
                  'role': 'TECHNICIAN',
                },
              }),
              200,
              headers: {Headers.contentTypeHeader: [Headers.jsonContentType]},
            );
          }
          return ResponseBody.fromString('{}', 200);
        });

      final storage = SecureStorage();
      final auth = AuthNotifier(storage: storage, authDio: loginDio);
      final verifyRes = await auth.verifyOtp(
        '+919876543210',
        '654321',
        email: 'tech@example.com',
        latitude: 22.5726,
        longitude: 88.3639,
      );
      expect(verifyRes, isA<ApiSuccess<String>>());

      // Verify strict storage separation: Render JWT vs Firebase tokens
      expect(await storage.getToken(), renderAccessJwt);
      expect(await storage.getRefreshToken(), renderRefreshJwt);
      expect(await storage.getFirebaseIdToken(), initialFbIdToken);
      expect(await storage.getFirebaseRefreshToken(), 'tech_fb_refresh_1');
      expect(await storage.getFirebaseUid(), 'uid_tech_9876543210');

      // Validate HS256 JWT is strictly rejected if ever passed as Firebase token
      expect(FirestoreRestClient.isFirebaseIdTokenFormat(renderAccessJwt), isFalse);
      expect(FirestoreRestClient.isFirebaseIdTokenFormat(initialFbIdToken), isTrue);
      expect(FirestoreRestClient.isFirebaseIdTokenFormat(freshFbIdToken), isTrue);

      // Simulate app restart after Firebase ID token expired: clear static memory, store expired Firebase token & timestamp
      await storage.saveFirebaseSession(
        idToken: expiredFbIdToken,
        refreshToken: 'tech_fb_refresh_1',
        uid: 'uid_tech_9876543210',
        expiresAtMs: DateTime.now().toUtc().subtract(const Duration(minutes: 5)).millisecondsSinceEpoch,
      );
      FirestoreRestClient.clearMemoryCache();
      FirestoreRestClient.resetInMemoryFirebaseAuthForTest();

      final restartedAuth = AuthNotifier(storage: SecureStorage());
      await restartedAuth.restoreSessionForTest();

      expect(restartedAuth.state.status, AuthStatus.authenticated);
      expect(restartedAuth.state.uid, 'uid_tech_9876543210');
      expect(restartedAuth.state.token, renderAccessJwt);

      // Expired Firebase ID token must have been refreshed using `tech_fb_refresh_1`, NEVER Render HS256 `renderRefreshJwt`!
      final refreshedFbId = await FirestoreRestClient.getValidFirebaseIdToken();
      expect(refreshedFbId, freshFbIdToken);
      expect(refreshGrants, ['tech_fb_refresh_1']);
      expect(refreshGrants.contains(renderRefreshJwt), isFalse);
    });
  });
}
