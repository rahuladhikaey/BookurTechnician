import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:dio/dio.dart';
import 'interceptors.dart';
import '../security/secure_storage.dart';

class DioClient {
  final Dio dio;

  DioClient(SecureStorage storage) : dio = Dio() {
    dio.options = BaseOptions(
      baseUrl: kDebugMode ? 'http://10.0.2.2:8080/api/v1' : 'https://api.bookurtechnician.online/api/v1',
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      contentType: Headers.jsonContentType,
    );

    dio.interceptors.addAll([
      AuthInterceptor(storage),
      ErrorInterceptor(),
      LoggingInterceptor(),
    ]);
  }
}
