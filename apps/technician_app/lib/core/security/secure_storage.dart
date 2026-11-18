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

  // Render Backend HS256 Session JWT Keys
  static const String _tokenKey = 'auth_token';
  static const String _refreshTokenKey = 'refresh_token';
  // Separate Firebase Auth Identity Toolkit Keys (never mixed with Render HS256 JWTs)
  static const String _firebaseIdTokenKey = 'firebase_id_token';
  static const String _firebaseRefreshTokenKey = 'firebase_refresh_token';
  static const String _firebaseUidKey = 'firebase_uid';
  static const String _firebaseExpiresAtMsKey = 'firebase_expires_at_ms';

  static const String _userIdKey = 'user_id';
  static const String _userNameKey = 'user_name';
  static const String _userAgeKey = 'user_age';
  static const String _userPhoneKey = 'user_phone';
  static const String _userEmailKey = 'user_email';

  Future<void> _writeSafe(String key, String value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(key, value);
    } catch (_) {}
    try {
      await _storage.write(key: key, value: value);
    } catch (_) {}
  }

  Future<String?> _readSafe(String key) async {
    try {
      final v = await _storage.read(key: key);
      if (v != null && v.isNotEmpty) return v;
    } catch (_) {}
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(key);
    } catch (_) {}
    return null;
  }

  Future<void> _deleteSafe(String key) async {
    try {
      await _storage.delete(key: key);
    } catch (_) {}
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(key);
    } catch (_) {}
  }

  Future<void> saveToken(String token) => _writeSafe(_tokenKey, token);

  Future<String?> getToken() => _readSafe(_tokenKey);

  Future<void> deleteToken() => _deleteSafe(_tokenKey);

  Future<void> saveRefreshToken(String refreshToken) => _writeSafe(_refreshTokenKey, refreshToken);

  Future<String?> getRefreshToken() => _readSafe(_refreshTokenKey);

  Future<void> deleteRefreshToken() => _deleteSafe(_refreshTokenKey);

  Future<void> saveFirebaseSession({
    required String idToken,
    String? refreshToken,
    String? uid,
    int? expiresAtMs,
  }) async {
    await _writeSafe(_firebaseIdTokenKey, idToken);
    if (refreshToken != null && refreshToken.isNotEmpty) {
      await _writeSafe(_firebaseRefreshTokenKey, refreshToken);
    }
    if (uid != null && uid.isNotEmpty) {
      await _writeSafe(_firebaseUidKey, uid);
    }
    if (expiresAtMs != null && expiresAtMs > 0) {
      await _writeSafe(_firebaseExpiresAtMsKey, expiresAtMs.toString());
    }
  }

  Future<String?> getFirebaseIdToken() => _readSafe(_firebaseIdTokenKey);

  Future<String?> getFirebaseRefreshToken() => _readSafe(_firebaseRefreshTokenKey);

  Future<String?> getFirebaseUid() => _readSafe(_firebaseUidKey);

  Future<int?> getFirebaseExpiresAtMs() async {
    final raw = await _readSafe(_firebaseExpiresAtMsKey);
    return raw != null ? int.tryParse(raw) : null;
  }

  Future<void> clearFirebaseSession() async {
    await _deleteSafe(_firebaseIdTokenKey);
    await _deleteSafe(_firebaseRefreshTokenKey);
    await _deleteSafe(_firebaseUidKey);
    await _deleteSafe(_firebaseExpiresAtMsKey);
  }

  Future<void> saveUserId(String userId) => _writeSafe(_userIdKey, userId);

  Future<String?> getUserId() => _readSafe(_userIdKey);

  Future<void> saveUserDetails({
    String? name,
    String? age,
    String? phone,
    String? email,
  }) async {
    if (name != null) await _writeSafe(_userNameKey, name);
    if (age != null) await _writeSafe(_userAgeKey, age);
    if (phone != null) await _writeSafe(_userPhoneKey, phone);
    if (email != null) await _writeSafe(_userEmailKey, email);
  }

  Future<Map<String, String?>> getUserDetails() async {
    final name = await _readSafe(_userNameKey);
    final age = await _readSafe(_userAgeKey);
    final phone = await _readSafe(_userPhoneKey);
    final email = await _readSafe(_userEmailKey);
    final userId = await getUserId();
    return {
      'name': name,
      'age': age,
      'phone': phone,
      'email': email,
      'userId': userId,
      'id': userId,
    };
  }

  Future<void> clearAll() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final hasSeen = prefs.getBool('has_seen_technician_onboarding') ?? true;
      await _deleteSafe(_tokenKey);
      await _deleteSafe(_refreshTokenKey);
      await clearFirebaseSession();
      await _deleteSafe(_userIdKey);
      await _deleteSafe(_userNameKey);
      await _deleteSafe(_userAgeKey);
      await _deleteSafe(_userPhoneKey);
      await _deleteSafe(_userEmailKey);
      try {
        await _storage.deleteAll();
      } catch (_) {}
      await prefs.setBool('has_seen_technician_onboarding', hasSeen);
    } catch (e) {
      debugPrint('SecureStorage.clearAll error: $e');
    }
  }
}
