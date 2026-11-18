import 'package:flutter_test/flutter_test.dart';
import 'package:customer_app_flutter/config/app_config.dart';

void main() {
  group('Render Pre-Deployment Client Config Audit (Customer App)', () {
    test('Does not invent Render URL or default active backend to Cloud Functions', () {
      expect(AppConfig.renderApiBaseUrl, '');
      expect(AppConfig.backendBaseUrl, '');
      expect(AppConfig.functionsApiUrl, '');
      expect(AppConfig.hasConfiguredBackend, isFalse);
      expect(AppConfig.requestTimeout.inSeconds, greaterThanOrEqualTo(15));
    });
  });
}
