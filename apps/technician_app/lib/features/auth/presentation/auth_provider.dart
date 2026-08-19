import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/security/secure_storage.dart';
import '../domain/auth_repository.dart';
import '../../../core/network/api_result.dart';

enum AuthStatus { unauthenticated, authenticating, otpSent, authenticated }

class AuthState {
  final AuthStatus status;
  final String? phone;
  final String? email;
  final String? fullName;
  final int? age;
  final String? token;
  final double? latitude;
  final double? longitude;
  final String? errorMessage;

  AuthState({
    this.status = AuthStatus.unauthenticated,
    this.phone,
    this.email,
    this.fullName,
    this.age,
    this.token,
    this.latitude,
    this.longitude,
    this.errorMessage,
  });

  AuthState copyWith({
    AuthStatus? status,
    String? phone,
    String? email,
    String? fullName,
    int? age,
    String? token,
    double? latitude,
    double? longitude,
    String? errorMessage,
  }) {
    return AuthState(
      status: status ?? this.status,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      fullName: fullName ?? this.fullName,
      age: age ?? this.age,
      token: token ?? this.token,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
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
    try {
      final cachedToken = await _secureStorage.getToken();
      final userDetails = await _secureStorage.getUserDetails();
      final savedAge = int.tryParse(userDetails['age'] ?? '');
      
      if (cachedToken != null && cachedToken.isNotEmpty) {
        state = AuthState(
          status: AuthStatus.authenticated,
          token: cachedToken,
          fullName: userDetails['name'] ?? 'Partner Technician',
          age: savedAge,
          phone: userDetails['phone'],
          email: userDetails['email'],
        );
      }
    } catch (e) {
      debugPrint('Error restoring cached token session: $e');
    }
  }

  @override
  Future<ApiResult<bool>> requestOtp(
    String phone, {
    required String email,
    String? fullName,
    int? age,
  }) async {
    state = state.copyWith(status: AuthStatus.authenticating);
    
    final normalizedEmail = email.trim().toLowerCase();
    final normalizedPhone = phone.trim();
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    
    if (normalizedPhone.length == 10 && emailRegex.hasMatch(normalizedEmail)) {
      try {
        final response = await _dioClient.dio.post('/auth/request-otp', data: {
          'email': normalizedEmail,
          'name': fullName?.trim(),
          'purpose': 'LOGIN',
        });

        if (response.statusCode == 200) {
          state = state.copyWith(
            status: AuthStatus.otpSent, 
            phone: normalizedPhone, 
            email: normalizedEmail,
            fullName: fullName?.trim(),
            age: age,
          );
          return const ApiSuccess(true);
        } else {
          final msg = response.data?['message'] ?? 'Failed to send OTP code';
          state = state.copyWith(status: AuthStatus.unauthenticated, errorMessage: msg);
          return ApiFailure(msg);
        }
      } catch (e) {
        String msg = 'Could not connect to server. Please check your internet connection.';
        if (e is DioException) {
          final backendMsg = e.response?.data?['message'];
          if (backendMsg != null && backendMsg.toString().isNotEmpty) {
            msg = backendMsg.toString();
          } else if (e.type == DioExceptionType.connectionTimeout || e.type == DioExceptionType.receiveTimeout) {
            msg = 'Server connection timed out. Please try again.';
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
  Future<ApiResult<String>> verifyOtp(
    String phone,
    String code, {
    String? email,
    String? fullName,
    int? age,
    double? latitude,
    double? longitude,
  }) async {
    state = state.copyWith(status: AuthStatus.authenticating);
    
    final targetEmail = (email ?? state.email ?? '').trim().toLowerCase();
    final targetPhone = phone.trim();
    final targetOtp = code.trim();
    final targetName = (fullName ?? state.fullName ?? 'Partner Technician').trim();
    final targetAge = age ?? state.age;

    // Capture location if not provided
    double? currentLat = latitude ?? state.latitude;
    double? currentLng = longitude ?? state.longitude;
    if (currentLat == null || currentLng == null) {
      try {
        final hasPermission = await Geolocator.checkPermission();
        if (hasPermission == LocationPermission.always || hasPermission == LocationPermission.whileInUse) {
          final pos = await Geolocator.getCurrentPosition(timeLimit: const Duration(seconds: 5));
          currentLat = pos.latitude;
          currentLng = pos.longitude;
        }
      } catch (_) {}
    }

    try {
      final response = await _dioClient.dio.post('/auth/verify-otp', data: {
        'email': targetEmail,
        'otp': targetOtp,
        'role': 'TECHNICIAN',
        'phone': targetPhone,
        'fullName': targetName,
        'purpose': 'LOGIN',
      });

      if (response.statusCode == 200) {
        final data = response.data?['data'];
        final accessToken = data?['accessToken'];
        final refreshToken = data?['refreshToken'];
        final userId = data?['user']?['id']?.toString() ?? targetPhone;
        final nameFromBackend = data?['user']?['fullName']?.toString() ?? targetName;

        if (accessToken != null) {
          await _secureStorage.saveToken(accessToken);
          if (refreshToken != null) {
            await _secureStorage.saveRefreshToken(refreshToken);
          }
          await _secureStorage.saveUserId(userId);
          await _secureStorage.saveUserDetails(
            name: nameFromBackend,
            age: targetAge?.toString(),
            phone: targetPhone,
            email: targetEmail,
          );

          state = AuthState(
            status: AuthStatus.authenticated,
            phone: targetPhone,
            email: targetEmail,
            fullName: nameFromBackend,
            age: targetAge,
            token: accessToken,
            latitude: currentLat,
            longitude: currentLng,
          );

          // Update location on backend after successful login
          if (currentLat != null && currentLng != null) {
            try {
              await _dioClient.dio.post('/technician/location', data: {
                'latitude': currentLat,
                'longitude': currentLng,
              });
            } catch (_) {}
          }

          return ApiSuccess(accessToken);
        }
      }

      final msg = response.data?['message'] ?? 'Invalid OTP code. Please enter the verification code sent to your email.';
      state = state.copyWith(status: AuthStatus.otpSent, errorMessage: msg);
      return ApiFailure(msg);
    } catch (e) {
      String msg = 'Verification error occurred. Please try again.';
      if (e is DioException) {
        final backendMsg = e.response?.data?['message'];
        if (backendMsg != null && backendMsg.toString().trim().isNotEmpty) {
          msg = backendMsg.toString();
        } else if (e.response?.statusCode == 400) {
          msg = 'Invalid or expired verification code. Please check your inbox.';
        } else if (e.response?.statusCode == 401) {
          msg = 'Authentication failed. Please request a new code.';
        } else if (e.response?.statusCode == 403) {
          msg = 'Technician account is not authorized.';
        } else if (e.response?.statusCode == 500) {
          msg = 'Authentication service temporarily unavailable.';
        }
      }
      state = state.copyWith(status: AuthStatus.otpSent, errorMessage: msg);
      return ApiFailure(msg);
    }
  }

  Future<void> logout() async {
    try {
      final refreshToken = await _secureStorage.getRefreshToken();
      if (refreshToken != null) {
        await _dioClient.dio.post('/auth/logout', data: {'refreshToken': refreshToken});
      }
    } catch (_) {}

    await _secureStorage.clearAll();
    state = AuthState(status: AuthStatus.unauthenticated);
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier();
});

