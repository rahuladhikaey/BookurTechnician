import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

class EmailService {
  static const String publicKey = 'hn2znBkgIi2lY8faY';
  static const String privateKey = 'DLj-DDHXaRY55ww2xu6Jg';
  static const String serviceId = 'service_u5wyepn';
  static const String templateId = 'template_gl8uwjj';

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

      final response = await dio.post(
        'https://api.emailjs.com/api/v1.0/email/send',
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            'Origin': 'https://bookurtechnician.online',
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)',
          },
        ),
        data: {
          'service_id': serviceId,
          'template_id': templateId,
          'user_id': publicKey,
          'accessToken': privateKey,
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
        },
      );

      debugPrint('📧 [EmailJS Flutter Technician] Dispatch status: ${response.statusCode}');
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      debugPrint('⚠️ [EmailService Technician Error]: $e');
      return false;
    }
  }
}
