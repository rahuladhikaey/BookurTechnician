import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SecureStorage {
  final FlutterSecureStorage _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
      resetOnError: true,
    ),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock,
    ),
  );

  static const String _tokenKey = 'auth_token';
  static const String _refreshTokenKey = 'refresh_token';
  static const String _userIdKey = 'user_id';
  static const String _userNameKey = 'user_name';
  static const String _userAgeKey = 'user_age';
  static const String _userPhoneKey = 'user_phone';
  static const String _userEmailKey = 'user_email';

  Future<void> saveToken(String token) async {
    try {
      await _storage.write(key: _tokenKey, value: token);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_tokenKey, token);
    } catch (e) {
      debugPrint('SecureStorage.saveToken error: $e');
    }
  }

  Future<String?> getToken() async {
    try {
      final token = await _storage.read(key: _tokenKey);
      if (token != null) return token;
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_tokenKey);
    } catch (e) {
      debugPrint('SecureStorage.getToken error: $e');
      try {
        final prefs = await SharedPreferences.getInstance();
        return prefs.getString(_tokenKey);
      } catch (_) {}
      return null;
    }
  }

  Future<void> deleteToken() async {
    try {
      await _storage.delete(key: _tokenKey);
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_tokenKey);
    } catch (e) {
      debugPrint('SecureStorage.deleteToken error: $e');
    }
  }

  Future<void> saveRefreshToken(String refreshToken) async {
    try {
      await _storage.write(key: _refreshTokenKey, value: refreshToken);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_refreshTokenKey, refreshToken);
    } catch (e) {
      debugPrint('SecureStorage.saveRefreshToken error: $e');
    }
  }

  Future<String?> getRefreshToken() async {
    try {
      return await _storage.read(key: _refreshTokenKey);
    } catch (e) {
      debugPrint('SecureStorage.getRefreshToken error: $e');
      return null;
    }
  }

  Future<void> deleteRefreshToken() async {
    try {
      await _storage.delete(key: _refreshTokenKey);
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_refreshTokenKey);
    } catch (e) {
      debugPrint('SecureStorage.deleteRefreshToken error: $e');
    }
  }

  Future<void> saveUserId(String userId) async {
    try {
      await _storage.write(key: _userIdKey, value: userId);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_userIdKey, userId);
    } catch (e) {
      debugPrint('SecureStorage.saveUserId error: $e');
    }
  }

  Future<String?> getUserId() async {
    try {
      return await _storage.read(key: _userIdKey);
    } catch (e) {
      debugPrint('SecureStorage.getUserId error: $e');
      return null;
    }
  }

  Future<void> saveUserDetails({
    String? name,
    String? age,
    String? phone,
    String? email,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (name != null) {
        await _storage.write(key: _userNameKey, value: name);
        await prefs.setString(_userNameKey, name);
      }
      if (age != null) {
        await _storage.write(key: _userAgeKey, value: age);
        await prefs.setString(_userAgeKey, age);
      }
      if (phone != null) {
        await _storage.write(key: _userPhoneKey, value: phone);
        await prefs.setString(_userPhoneKey, phone);
      }
      if (email != null) {
        await _storage.write(key: _userEmailKey, value: email);
        await prefs.setString(_userEmailKey, email);
      }
    } catch (e) {
      debugPrint('SecureStorage.saveUserDetails error: $e');
    }
  }

  Future<Map<String, String?>> getUserDetails() async {
    try {
      final name = await _storage.read(key: _userNameKey);
      final age = await _storage.read(key: _userAgeKey);
      final phone = await _storage.read(key: _userPhoneKey);
      final email = await _storage.read(key: _userEmailKey);
      return {
        'name': name,
        'age': age,
        'phone': phone,
        'email': email,
      };
    } catch (e) {
      debugPrint('SecureStorage.getUserDetails error: $e');
      return {};
    }
  }

  Future<void> clearAll() async {
    try {
      await _storage.deleteAll();
      final prefs = await SharedPreferences.getInstance();
      final hasSeen = prefs.getBool('has_seen_technician_onboarding') ?? true;
      await prefs.remove(_tokenKey);
      await prefs.remove(_refreshTokenKey);
      await prefs.remove(_userIdKey);
      await prefs.remove(_userNameKey);
      await prefs.remove(_userAgeKey);
      await prefs.remove(_userPhoneKey);
      await prefs.remove(_userEmailKey);
      await prefs.setBool('has_seen_technician_onboarding', hasSeen);
    } catch (e) {
      debugPrint('SecureStorage.clearAll error: $e');
    }
  }
}
