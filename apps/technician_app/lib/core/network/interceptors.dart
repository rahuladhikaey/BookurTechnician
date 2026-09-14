import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../security/secure_storage.dart';

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
    } catch (e) {
      debugPrint('AuthInterceptor token read error: $e');
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
        final fallbackDio = Dio(BaseOptions(baseUrl: 'https://bookurtechnician-backend.onrender.com/api/v1'));
        final response = await fallbackDio.request(
          originalRequest.path,
          data: originalRequest.data,
          queryParameters: originalRequest.queryParameters,
          options: fallbackOptions,
        );
        return handler.resolve(response);
      } catch (retryErr) {
        if (retryErr is DioException) {
          return handler.next(retryErr);
        }
      }
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
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    debugPrint('<-- ERROR: ${err.message}');
    handler.next(err);
  }
}
