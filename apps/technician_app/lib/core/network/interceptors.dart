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
    // Pure Firebase Architecture: Route request directly to Cloud Firestore
    if (AppConfig.isFirebasePrimary) {
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

    // Direct Cloud Firestore Fallback (bookmytechnician-53d94)
    try {
      debugPrint('🔥 [TechnicianApp] Serving ${originalRequest.path} directly via Firebase Cloud Firestore');
      final fbResp = await FirestoreRestClient.handleDioRequest(originalRequest);
      return handler.resolve(fbResp);
    } catch (e) {
      debugPrint('🔥 [TechnicianApp] Firestore fallback notice: $e');
    }

    if (err.response?.statusCode == 401) {
      // Token expiration
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
