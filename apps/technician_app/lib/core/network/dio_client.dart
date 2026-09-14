import 'package:dio/dio.dart';
import '../config/app_config.dart';
import 'interceptors.dart';
import '../security/secure_storage.dart';

class DioClient {
  final Dio dio;

  DioClient([SecureStorage? storage]) : dio = Dio() {
    final effectiveStorage = storage ?? SecureStorage();
    dio.options = BaseOptions(
      baseUrl: AppConfig.apiBaseUrl,
      connectTimeout: AppConfig.requestTimeout,
      receiveTimeout: AppConfig.requestTimeout,
      sendTimeout: AppConfig.requestTimeout,
      contentType: Headers.jsonContentType,
    );

    dio.interceptors.addAll([
      AuthInterceptor(effectiveStorage),
      ErrorInterceptor(),
      LoggingInterceptor(),
    ]);
  }
}

