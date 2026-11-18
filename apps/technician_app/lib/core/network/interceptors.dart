import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../security/secure_storage.dart';
import '../config/app_config.dart';
import 'firestore_rest_client.dart';

class AuthInterceptor extends Interceptor {
  final SecureStorage _storage;
  AuthInterceptor(this._storage);

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    try {
      final token = await _storage.getToken();
      if (token != null && token.isNotEmpty) {
        options.headers['Authorization'] = 'Bearer $token';
      }
      final userDetails = await _storage.getUserDetails();
      var techId = userDetails['userId'] ?? userDetails['id'];
      if (techId == null || techId.toString().isEmpty) {
        techId = await _storage.getUserId();
      }
      if (techId == null || techId.toString().isEmpty) {
        final phone = userDetails['phone'];
        if (phone != null && phone.isNotEmpty) {
          techId = FirestoreRestClient.resolveCanonicalTechUid(phone, phone: phone);
        }
      }
      if (techId != null && techId.toString().isNotEmpty) {
        options.headers['x-technician-id'] = techId.toString();
        options.headers['x-user-id'] = techId.toString();
      }
    } catch (e) {
      debugPrint('AuthInterceptor header attach notice: $e');
    }
    // Route to Render/backend HTTP API whenever a real backend URL is configured;
    // only intercept directly into FirestoreRestClient in pure-Firestore offline mode.
    final hasAbsoluteUrl = options.path.startsWith('http://') || options.path.startsWith('https://');
    if (!hasAbsoluteUrl && !AppConfig.hasConfiguredBackend && AppConfig.isFirebasePrimary) {
      try {
        debugPrint('🔥 [TechnicianApp] Serving ${options.path} directly via Firebase Cloud Firestore');
        final fbResp = await FirestoreRestClient.handleDioRequest(options);
        return handler.resolve(fbResp);
      } catch (e) {
        debugPrint('🔥 [TechnicianApp] Firestore request error: $e');
      }
    }

    handler.next(options);
  }
}

class ErrorInterceptor extends Interceptor {
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    final originalRequest = err.requestOptions;
    final statusCode = err.response?.statusCode ?? 0;

    // 1. Refresh expired access token once on 401 for non-auth requests
    if (statusCode == 401 &&
        !originalRequest.path.contains('/auth/') &&
        originalRequest.extra['_retriedAfterRefresh'] != true &&
        AppConfig.hasConfiguredBackend) {
      try {
        final storage = SecureStorage();
        final refreshToken = await storage.getRefreshToken();
        if (refreshToken != null && refreshToken.isNotEmpty) {
          final refreshDio = Dio(BaseOptions(
            baseUrl: AppConfig.backendBaseUrl,
            connectTimeout: AppConfig.requestTimeout,
            receiveTimeout: AppConfig.requestTimeout,
            contentType: Headers.jsonContentType,
          ));
          final refreshRes = await refreshDio.post(
            '/auth/refresh-token',
            data: {'refreshToken': refreshToken},
          );
          if (refreshRes.statusCode == 200 && refreshRes.data is Map) {
            final resMap = refreshRes.data as Map;
            final nested = resMap['data'] is Map ? resMap['data'] as Map : resMap;
            final newAccess = (nested['accessToken'] ?? nested['token'] ?? resMap['accessToken'])?.toString();
            final newRefresh = (nested['refreshToken'] ?? resMap['refreshToken'])?.toString();
            final customTok = (nested['firebaseCustomToken'] ?? resMap['firebaseCustomToken'])?.toString();

            if (newAccess != null && newAccess.isNotEmpty) {
              await storage.saveToken(newAccess);
              if (newRefresh != null && newRefresh.isNotEmpty) {
                await storage.saveRefreshToken(newRefresh);
              }
              if (customTok != null && customTok.isNotEmpty) {
                await FirestoreRestClient.signInWithCustomToken(customTok);
              }

              originalRequest.headers['Authorization'] = 'Bearer $newAccess';
              originalRequest.extra['_retriedAfterRefresh'] = true;
              final retried = await Dio(BaseOptions(
                baseUrl: originalRequest.baseUrl.isNotEmpty
                    ? originalRequest.baseUrl
                    : AppConfig.backendBaseUrl,
                connectTimeout: AppConfig.requestTimeout,
                receiveTimeout: AppConfig.requestTimeout,
              )).fetch(originalRequest);
              return handler.resolve(retried);
            }
          }
        }
      } catch (refreshErr) {
        debugPrint('⚠️ [TechnicianApp] Token refresh failed: $refreshErr');
      }
      return handler.next(err);
    }

    // Never bypass authoritative backend 4xx rejections (e.g. 401, 403, 409, 410)
    if (statusCode >= 400 && statusCode < 500) {
      return handler.next(err);
    }

    // Fall back to direct Cloud Firestore ONLY when no trusted Render backend is configured
    // AND the route is not an authoritative security/OTP/accept/OTP-verification route.
    final isAuthoritativeAction =
        originalRequest.path.contains('/accept') ||
        originalRequest.path.contains('verify-start-otp') ||
        originalRequest.path.contains('verify-end-otp') ||
        originalRequest.path.contains('/auth/');
    if (!AppConfig.hasConfiguredBackend && !isAuthoritativeAction) {
      try {
        debugPrint('🔥 [TechnicianApp] Serving ${originalRequest.path} via Firebase Cloud Firestore fallback');
        final fbResp = await FirestoreRestClient.handleDioRequest(originalRequest);
        return handler.resolve(fbResp);
      } catch (e) {
        debugPrint('🔥 [TechnicianApp] Firestore fallback notice: $e');
      }
    }

    handler.next(err);
  }
}

class LoggingInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    debugPrint('--> ${options.method} ${options.path}');
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    debugPrint('<-- ${response.statusCode} ${response.requestOptions.path}');
    if (response.statusCode != null && response.statusCode! < 500) {
      AppConfig.updateWorkingBaseUrl(response.requestOptions.baseUrl);
    }
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    debugPrint('<-- ERROR: ${err.message}');
    handler.next(err);
  }
}
