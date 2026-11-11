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
      final techId = userDetails['userId'] ?? userDetails['id'];
      if (techId != null && techId.toString().isNotEmpty) {
        options.headers['x-technician-id'] = techId.toString();
        options.headers['x-user-id'] = techId.toString();
      }
    } catch (e) {
      debugPrint('AuthInterceptor header attach notice: $e');
    }
    handler.next(options);
  }
}

class ErrorInterceptor extends Interceptor {
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    final originalRequest = err.requestOptions;
    
    // Automatically retry against Render backend URL if primary domain is unreachable
    if ((err.type == DioExceptionType.connectionTimeout ||
         err.type == DioExceptionType.connectionError ||
         err.type == DioExceptionType.unknown) &&
        originalRequest.baseUrl.contains('api.bookurtechnician.online') &&
        originalRequest.extra['retried_fallback'] != true) {
      try {
        final fallbackOptions = Options(
          method: originalRequest.method,
          headers: originalRequest.headers,
          extra: {'retried_fallback': true},
        );
        final fallbackDio = Dio(BaseOptions(
          baseUrl: AppConfig.renderApiBaseUrl,
          connectTimeout: const Duration(seconds: 4),
          receiveTimeout: const Duration(seconds: 4),
        ));
        final response = await fallbackDio.request(
          originalRequest.path,
          data: originalRequest.data,
          queryParameters: originalRequest.queryParameters,
          options: fallbackOptions,
        );
        AppConfig.updateWorkingBaseUrl(AppConfig.renderApiBaseUrl);
        return handler.resolve(response);
      } catch (retryErr) {
        // Fallback to Cloud Firestore below
      }
    }

    // Direct Cloud Firestore Fallback (bookmytechnician-53d94)
    if (err.type == DioExceptionType.connectionTimeout ||
        err.type == DioExceptionType.connectionError ||
        err.type == DioExceptionType.receiveTimeout ||
        err.type == DioExceptionType.unknown) {
      try {
        debugPrint('🔥 [TechnicianApp] Serving ${originalRequest.path} directly via Firebase Cloud Firestore');
        final fbResp = await FirestoreRestClient.handleDioRequest(originalRequest);
        return handler.resolve(fbResp);
      } catch (_) {}
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
