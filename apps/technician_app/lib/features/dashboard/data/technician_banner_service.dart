import 'package:dio/dio.dart';
import '../../../../core/config/app_config.dart';
import '../domain/technician_banner.dart';

class TechnicianBannerService {
  static String get baseUrl => AppConfig.apiBaseUrl;

  static final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 4),
      receiveTimeout: const Duration(seconds: 4),
    ),
  );

  static Future<List<TechnicianBanner>> fetchActiveBanners() async {
    try {
      final response = await _dio.get('$baseUrl/technician-banners');

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data;
        if (data is Map<String, dynamic> && data['success'] == true && data['data'] is List) {
          final List list = data['data'] as List;
          if (list.isNotEmpty) {
            return list
                .map((item) => TechnicianBanner.fromJson(item as Map<String, dynamic>))
                .toList();
          }
        }
      }
    } catch (_) {
      // Fallback silently to default 4 promotional slides
    }
    return TechnicianBanner.getDefaultBanners();
  }
}
