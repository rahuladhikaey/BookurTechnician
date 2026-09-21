import 'package:flutter/foundation.dart';
import '../../../core/config/app_config.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/security/secure_storage.dart';
import '../domain/technician_analytics_models.dart';

class TechnicianAnalyticsService {
  final DioClient _dioClient;

  TechnicianAnalyticsService({DioClient? dioClient})
      : _dioClient = dioClient ?? DioClient(SecureStorage());

  Future<TierCardModel?> fetchTierStatus() async {
    try {
      final response = await _dioClient.dio.get('${AppConfig.apiBaseUrl}/technicians/tier-status');
      if (response.statusCode == 200 && response.data != null) {
        final data = response.data['data'] ?? response.data;
        if (data is Map<String, dynamic>) {
          return TierCardModel.fromJson(data);
        }
      }
    } catch (e) {
      debugPrint('[AnalyticsService] fetchTierStatus error: $e');
    }
    return null;
  }

  Future<AnalyticsOverviewModel?> fetchAnalyticsOverview({
    String filter = 'today',
    String? startDate,
    String? endDate,
  }) async {
    try {
      final response = await _dioClient.dio.get(
        '${AppConfig.apiBaseUrl}/technicians/analytics/overview',
        queryParameters: {
          'filter': filter,
          if (startDate != null) 'startDate': startDate,
          if (endDate != null) 'endDate': endDate,
        },
      );
      if (response.statusCode == 200 && response.data != null) {
        if (response.data is Map<String, dynamic>) {
          return AnalyticsOverviewModel.fromJson(response.data);
        }
      }
    } catch (e) {
      debugPrint('[AnalyticsService] fetchAnalyticsOverview error: $e');
    }
    return null;
  }

  Future<void> sendShiftHeartbeat({int activeMinutes = 5}) async {
    try {
      await _dioClient.dio.post(
        '${AppConfig.apiBaseUrl}/technicians/shift/heartbeat',
        data: {'activeMinutes': activeMinutes},
      );
    } catch (e) {
      debugPrint('[AnalyticsService] sendShiftHeartbeat error: $e');
    }
  }
}
