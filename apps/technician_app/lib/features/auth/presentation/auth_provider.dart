import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/security/secure_storage.dart';
import '../domain/auth_repository.dart';
import '../../../core/network/api_result.dart';

enum AuthStatus { unauthenticated, authenticating, otpSent, authenticated }

class AuthState {
  final AuthStatus status;
  final String? phone;
  final String? email;
  final String? token;
  final String? errorMessage;

  AuthState({
    this.status = AuthStatus.unauthenticated,
    this.phone,
    this.email,
    this.token,
    this.errorMessage,
  });

  AuthState copyWith({
    AuthStatus? status,
    String? phone,
    String? email,
    String? token,
    String? errorMessage,
  }) {
    return AuthState(
      status: status ?? this.status,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      token: token ?? this.token,
      errorMessage: errorMessage,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> implements AuthRepository {
  late final DioClient _dioClient;
  final SecureStorage _secureStorage;

  AuthNotifier({SecureStorage? storage}) 
      : _secureStorage = storage ?? SecureStorage(),
        super(AuthState()) {
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
    
    final normalizedEmail = email.trim().toLowerCase();
    final normalizedPhone = phone.trim();
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    
    if (normalizedPhone.length == 10 && emailRegex.hasMatch(normalizedEmail)) {
      try {
        final response = await _dioClient.dio.post('/auth/request-otp', data: {
          'email': normalizedEmail,
          'purpose': 'LOGIN',
        });

        if (response.statusCode == 200) {
          state = state.copyWith(
            status: AuthStatus.otpSent, 
            phone: normalizedPhone, 
            email: normalizedEmail, 
          );
          return const ApiSuccess(true);
        } else {
          final msg = response.data?['message'] ?? 'Failed to send OTP code';
          state = state.copyWith(status: AuthStatus.unauthenticated, errorMessage: msg);
          return ApiFailure(msg);
        }
      } catch (e) {
        String msg = 'Connection error: $e';
        if (e is DioException) {
          final backendMsg = e.response?.data?['message'];
          if (backendMsg != null && backendMsg.toString().isNotEmpty) {
            msg = backendMsg.toString();
          }
        }
        state = state.copyWith(status: AuthStatus.unauthenticated, errorMessage: msg);
        return ApiFailure(msg);
      }
    } else {
      state = state.copyWith(status: AuthStatus.unauthenticated, errorMessage: 'Invalid phone or email address');
      return const ApiFailure('Invalid phone or email address');
    }
  }

  @override
  Future<ApiResult<String>> verifyOtp(String phone, String code, {String? email}) async {
    state = state.copyWith(status: AuthStatus.authenticating);
    
    final targetEmail = (email ?? state.email ?? '').trim().toLowerCase();
    final targetPhone = phone.trim();
    final targetOtp = code.trim();

    try {
      final response = await _dioClient.dio.post('/auth/verify-otp', data: {
        'email': targetEmail,
        'otp': targetOtp,
        'role': 'TECHNICIAN',
        'phone': targetPhone,
        'purpose': 'LOGIN',
      });

      if (response.statusCode == 200) {
        final data = response.data?['data'];
        final accessToken = data?['accessToken'];
        final refreshToken = data?['refreshToken'];
        final userId = data?['user']?['id']?.toString() ?? targetPhone;

        if (accessToken != null) {
          await _secureStorage.saveToken(accessToken);
          if (refreshToken != null) {
            await _secureStorage.saveRefreshToken(refreshToken);
          }
          await _secureStorage.saveUserId(userId);
          state = AuthState(status: AuthStatus.authenticated, phone: targetPhone, email: targetEmail, token: accessToken);
          return ApiSuccess(accessToken);
        }
      }

      final msg = response.data?['message'] ?? 'Invalid OTP code. Please enter the verification code sent to your email.';
      state = state.copyWith(status: AuthStatus.otpSent, errorMessage: msg);
      return ApiFailure(msg);
    } catch (e) {
      String msg = 'Verification error: $e';
      if (e is DioException) {
        final backendMsg = e.response?.data?['message'];
        if (backendMsg != null && backendMsg.toString().isNotEmpty) {
          msg = backendMsg.toString();
        } else if (e.response?.statusCode == 400) {
          msg = 'Invalid or expired OTP code. Please check your inbox and try again.';
        }
      }
      state = state.copyWith(status: AuthStatus.otpSent, errorMessage: msg);
      return ApiFailure(msg);
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
