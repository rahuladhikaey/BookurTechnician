import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

class EmailService {
  static const String publicKey =
      String.fromEnvironment('EMAILJS_PUBLIC_KEY', defaultValue: 'nLw-NuKf-O8WBphBk');
  // Never hardcode private API secrets in client binaries; must be injected at build time or handled by backend.
  static const String privateKey =
      String.fromEnvironment('EMAILJS_PRIVATE_KEY', defaultValue: '');
  static const String serviceId =
      String.fromEnvironment('EMAILJS_SERVICE_ID', defaultValue: 'service_noexwvl');
  static const String templateId =
      String.fromEnvironment('EMAILJS_TEMPLATE_ID', defaultValue: 'template_159x4wr');

  static Future<bool> sendOtpEmail({
    required String email,
    required String otp,
    required String role,
    String? name,
  }) async {
    final displayName = (name != null && name.trim().isNotEmpty) ? name.trim() : '$role Partner';

    try {
      final dio = Dio(BaseOptions(
        connectTimeout: const Duration(seconds: 8),
        receiveTimeout: const Duration(seconds: 8),
      ));

      final payload = <String, dynamic>{
        'service_id': serviceId,
        'template_id': templateId,
        'user_id': publicKey,
        if (privateKey.isNotEmpty) 'accessToken': privateKey,
        'template_params': {
          'to_email': email.trim().toLowerCase(),
          'email': email.trim().toLowerCase(),
          'user_email': email.trim().toLowerCase(),
          'to_name': displayName,
          'name': displayName,
          'user_name': displayName,
          'otp': otp,
          'code': otp,
          'role': role,
          'subject': '[$role] BookUrTechnician Verification OTP: $otp',
          'message': 'Your verification OTP code for BookUrTechnician Partner ($role) is: $otp. Valid for 10 minutes.',
          'app_name': 'BookurTechnician',
        },
      };

      final response = await dio.post(
        'https://api.emailjs.com/api/v1.0/email/send',
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            'Origin': 'https://bookurtechnician.online',
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)',
          },
        ),
        data: payload,
      );

      debugPrint('📧 [EmailJS Flutter Technician] Dispatch status: ${response.statusCode}');
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      debugPrint('⚠️ [EmailService Technician Error]: $e');
      return false;
    }
  }
}
