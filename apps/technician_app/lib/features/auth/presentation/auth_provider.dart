import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/security/secure_storage.dart';
import '../domain/auth_repository.dart';
import '../../../core/network/api_result.dart';
import '../../../core/network/dio_client.dart';

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
  late final DioClient _dioClient;

  AuthNotifier() : super(AuthState(status: AuthStatus.unauthenticated)) {
    _dioClient = DioClient(_secureStorage);
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
    
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (phone.length == 10 && emailRegex.hasMatch(email)) {
      try {
        final response = await _dioClient.dio.post('/auth/request-otp', data: {
          'email': email.trim().toLowerCase(),
          'purpose': 'LOGIN',
        });

        if (response.statusCode == 200) {
          state = state.copyWith(
            status: AuthStatus.otpSent, 
            phone: phone, 
            email: email, 
          );
          return const ApiSuccess(true);
        } else {
          final msg = response.data?['message'] ?? 'Failed to send OTP code';
          state = state.copyWith(status: AuthStatus.unauthenticated, errorMessage: msg);
          return ApiFailure(msg);
        }
      } catch (e) {
        state = state.copyWith(status: AuthStatus.unauthenticated, errorMessage: e.toString());
        return ApiFailure('Connection error: $e');
      }
    } else {
      state = state.copyWith(status: AuthStatus.unauthenticated, errorMessage: 'Invalid phone or email address');
      return const ApiFailure('Invalid phone or email address');
    }
  }

  @override
  Future<ApiResult<String>> verifyOtp(String phone, String code) async {
    state = state.copyWith(status: AuthStatus.authenticating);
    
    try {
      final response = await _dioClient.dio.post('/auth/verify-otp', data: {
        'email': state.email ?? '',
        'otp': code.trim(),
        'role': 'TECHNICIAN',
        'phone': phone.trim(),
      });

      if (response.statusCode == 200) {
        final data = response.data?['data'];
        final accessToken = data?['accessToken'];
        final refreshToken = data?['refreshToken'];
        final userId = data?['user']?['id']?.toString() ?? phone;

        if (accessToken != null) {
          await _secureStorage.saveToken(accessToken);
          if (refreshToken != null) {
            await _secureStorage.saveRefreshToken(refreshToken);
          }
          await _secureStorage.saveUserId(userId);
          state = AuthState(status: AuthStatus.authenticated, phone: phone, email: state.email, token: accessToken);
          return ApiSuccess(accessToken);
        }
      }

      final msg = response.data?['message'] ?? 'Invalid OTP code. Please enter the verification code sent to your email.';
      state = state.copyWith(status: AuthStatus.otpSent, errorMessage: msg);
      return ApiFailure(msg);
    } catch (e) {
      state = state.copyWith(status: AuthStatus.otpSent, errorMessage: e.toString());
      return ApiFailure('Verification error: $e');
    }
  }

  Future<void> logout() async {
    try {
      final refreshToken = await _secureStorage.getRefreshToken();
      await _dioClient.dio.post('/auth/logout', data: {'refreshToken': refreshToken});
    } catch (_) {}

    await _secureStorage.clearAll();
    state = AuthState(status: AuthStatus.unauthenticated);
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier();
});
