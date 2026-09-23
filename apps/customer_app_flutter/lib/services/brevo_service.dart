// Legacy redirect for backward compatibility
import 'email_service.dart';

@Deprecated('Use EmailService instead')
class BrevoService {
  static Future<bool> sendOtpEmail({
    required String email,
    required String otp,
    required String role,
    String? name,
  }) => EmailService.sendOtpEmail(email: email, otp: otp, role: role, name: name);
}
