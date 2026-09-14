import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

class BrevoService {
  static const String apiKey = String.fromEnvironment('BREVO_API_KEY');
  static const String senderEmail = 'noreply@asaliswad.com';

  static Future<bool> sendOtpEmail({
    required String email,
    required String otp,
    required String role,
  }) async {
    if (apiKey.isEmpty) {
      debugPrint('=====================================================');
      debugPrint('[BREVO SMTP MOCK] Sending OTP $otp to $email for $role');
      debugPrint('To send real emails, set apiKey in brevo_service.dart.');
      debugPrint('=====================================================');
      return true;
    }

    try {
      final dio = Dio();
      final response = await dio.post(
        'https://api.brevo.com/v3/smtp/email',
        options: Options(
          headers: {
            'api-key': apiKey,
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
        ),
        data: {
          'sender': {
            'name': 'BookUrTechnician',
            'email': senderEmail
          },
          'to': [
            {
              'email': email,
              'name': '$role User'
            }
          ],
          'subject': '[$role] BookUrTechnician Verification OTP',
          'htmlContent': '''
            <html>
              <body style="font-family: Arial, sans-serif; padding: 20px;">
                <h2 style="color: #1E40AF;">BookUrTechnician Verification</h2>
                <p>Hello,</p>
                <p>Your one-time password (OTP) to log in as a <strong>$role</strong> is:</p>
                <div style="font-size: 24px; font-weight: bold; background: #F3F4F6; padding: 12px; border-radius: 8px; display: inline-block; letter-spacing: 4px; color: #1E40AF; margin: 16px 0;">
                  $otp
                </div>
                <p>This OTP is valid for 10 minutes. Please do not share this code with anyone.</p>
                <br>
                <p>Regards,</p>
                <p>BookUrTechnician Support Team</p>
              </body>
            </html>
          ''',
        },
      );
      return response.statusCode == 201 || response.statusCode == 200;
    } catch (e) {
      debugPrint('Error sending Brevo email: $e');
      return false;
    }
  }
}
