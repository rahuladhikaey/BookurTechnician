import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/security/secure_storage.dart';
import '../domain/auth_repository.dart';
import '../../../core/network/api_result.dart';
import '../../../core/network/brevo_service.dart';

enum AuthStatus { unauthenticated, authenticating, otpSent, authenticated, error }

class AuthState {
  final AuthStatus status;
  final String? phone;
  final String? email;
  final String? expectedOtp;
  final String? errorMessage;
  final String? token;

  AuthState({
    required this.status,
    this.phone,
    this.email,
    this.expectedOtp,
    this.errorMessage,
    this.token,
  });

  AuthState copyWith({
    AuthStatus? status,
    String? phone,
    String? email,
    String? expectedOtp,
    String? errorMessage,
    String? token,
  }) {
    return AuthState(
      status: status ?? this.status,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      expectedOtp: expectedOtp ?? this.expectedOtp,
      errorMessage: errorMessage ?? this.errorMessage,
      token: token ?? this.token,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> implements AuthRepository {
  final SecureStorage _secureStorage = SecureStorage();

  AuthNotifier() : super(AuthState(status: AuthStatus.unauthenticated)) {
    _checkExistingToken();
  }

  void _checkExistingToken() async {
    final cachedToken = await _secureStorage.getToken();
    if (cachedToken != null) {
      state = AuthState(status: AuthStatus.authenticated, token: cachedToken);
    }
  }

  @override
  Future<ApiResult<bool>> requestOtp(String phone, {required String email}) async {
    state = state.copyWith(status: AuthStatus.authenticating);
    await Future.delayed(const Duration(seconds: 1)); // simulated latency
    
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (phone.length == 10 && emailRegex.hasMatch(email)) {
      // Generate dynamic OTP
      final randomOtp = (100000 + Random().nextInt(900000)).toString();

      final success = await BrevoService.sendOtpEmail(
        email: email,
        otp: randomOtp,
        role: 'Technician',
      );

      if (success) {
        state = state.copyWith(
          status: AuthStatus.otpSent, 
          phone: phone, 
          email: email, 
          expectedOtp: randomOtp
        );
        return const ApiSuccess(true);
      } else {
        state = state.copyWith(status: AuthStatus.unauthenticated, errorMessage: 'Failed to send OTP email');
        return const ApiFailure('Failed to send OTP email');
      }
    } else {
      state = state.copyWith(status: AuthStatus.unauthenticated, errorMessage: 'Invalid phone or email address');
      return const ApiFailure('Invalid phone or email address');
    }
  }

  @override
  Future<ApiResult<String>> verifyOtp(String phone, String code) async {
    state = state.copyWith(status: AuthStatus.authenticating);
    await Future.delayed(const Duration(seconds: 1)); // simulated delay
    
    final expected = state.expectedOtp ?? '1234';
    if (code == expected) {
      const mockToken = 'jwt_token_tech_rahul_9988';
      await _secureStorage.saveToken(mockToken);
      await _secureStorage.saveUserId('tech_rahul');
      state = AuthState(status: AuthStatus.authenticated, phone: phone, email: state.email, token: mockToken);
      return const ApiSuccess(mockToken);
    } else {
      state = state.copyWith(status: AuthStatus.otpSent, errorMessage: 'Invalid OTP code');
      return ApiFailure('Invalid OTP code. Expected code: $expected');
    }
  }

  Future<void> logout() async {
    await _secureStorage.clearAll();
    state = AuthState(status: AuthStatus.unauthenticated);
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier();
});
