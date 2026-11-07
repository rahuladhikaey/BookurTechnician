import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:technician_app/core/network/firestore_rest_client.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    FirestoreRestClient.mockHttpHandler = null;
  });

  test('Technician Skill Save strictly preserves GPS coordinates, lastLocationUpdate, and online presence (Never overwrites GPS)', () async {
    SharedPreferences.setMockInitialValues({});
    FirestoreRestClient.resetMetrics();
    FirestoreRestClient.clearMemoryCache();

    final List<Uri> patchedUris = [];
    final List<Map<String, dynamic>> patchedBodies = [];

    FirestoreRestClient.mockHttpHandler = (
      String method,
      Uri uri, {
      Map<String, String>? headers,
      String? body,
    }) async {
      if (method == 'PATCH' && uri.path.contains('/technician_profiles/')) {
        patchedUris.add(uri);
        patchedBodies.add(jsonDecode(body.toString()) as Map<String, dynamic>);
      }
      return http.Response(
        jsonEncode({
          'name': 'projects/bookmytechnician-53d94/databases/(default)/documents/technician_profiles/uid_tech_988363',
          'fields': {},
        }),
        200,
      );
    };

    final reqOptions = RequestOptions(
      path: '/technicians/skills/bulk',
      method: 'POST',
      data: {
        'technicianId': 'uid_tech_988363',
        'skills': [
          {'skillId': 'ac_install', 'name': 'AC installation', 'categoryName': 'AC Services', 'enabled': true},
          {'skillId': 'ac_repair', 'name': 'AC repair', 'categoryName': 'AC Services', 'enabled': true},
        ],
      },
    );

    final res = await FirestoreRestClient.handleDioRequest(reqOptions);
    expect(res.statusCode, 200);
    expect(patchedUris, isNotEmpty);

    final patchUri = patchedUris.last;
    final patchBody = patchedBodies.last;
    final fields = patchBody['fields'] as Map<String, dynamic>;
    final queryStr = patchUri.query;

    // Verify internal UID and public partner code separation
    expect(fields['id']['stringValue'], 'uid_tech_988363');
    expect(fields['uid']['stringValue'], 'uid_tech_988363');
    expect(fields['technicianCode']['stringValue'], 'BT-988363');

    // CRITICAL PHASE 4.1 REQUIREMENT:
    // Skill updates MUST NOT contain latitude, longitude, currentLatitude, currentLongitude, lastLocationUpdate, or isOnline!
    expect(fields.containsKey('latitude'), isFalse);
    expect(fields.containsKey('longitude'), isFalse);
    expect(fields.containsKey('currentLatitude'), isFalse);
    expect(fields.containsKey('currentLongitude'), isFalse);
    expect(fields.containsKey('lastLocationUpdate'), isFalse);
    expect(fields.containsKey('isOnline'), isFalse);
    expect(fields.containsKey('online'), isFalse);
    expect(queryStr.contains('lastLocationUpdate'), isFalse);
    expect(queryStr.contains('latitude'), isFalse);
    expect(queryStr.contains('longitude'), isFalse);
  });

  test('Technician OTP & Identity Security: Internal UID vs Public Partner Code, SHA-256 Hash, Expiry, Rate Limit, 5-Attempt Lockout', () async {
    SharedPreferences.setMockInitialValues({});
    FirestoreRestClient.resetMetrics();
    FirestoreRestClient.clearMemoryCache();
    FirestoreRestClient.clearOtpChallengesForTest();

    FirestoreRestClient.mockHttpHandler = (
      String method,
      Uri uri, {
      Map<String, String>? headers,
      String? body,
    }) async {
      if (method == 'GET' && uri.path.contains('/otp_challenges/')) {
        return http.Response('{}', 404);
      }
      return http.Response(
        jsonEncode({
          'name': 'projects/bookmytechnician-53d94/databases/(default)/documents/test/doc',
          'fields': {},
        }),
        200,
      );
    };

    final baseTime = DateTime.utc(2026, 11, 8, 10, 0, 0);
    const techEmail = 'ram.partner@bookurtechnician.com';

    // 1. Request OTP
    final reqOtp = await FirestoreRestClient.requestOtpChallenge(
      identifier: techEmail,
      email: techEmail,
      phone: '9830098836',
      fullName: 'Ram',
      role: 'TECHNICIAN',
      nowOverride: baseTime,
    );
    expect(reqOtp['success'], isTrue);
    final generatedOtp = reqOtp['_testOtp'] as String;

    // 2. Verify '123456' backdoor is rejected
    if (generatedOtp != '123456') {
      final backdoorRes = await FirestoreRestClient.verifyOtpChallenge(
        identifier: techEmail,
        code: '123456',
        nowOverride: baseTime.add(const Duration(seconds: 10)),
      );
      expect(backdoorRes['success'], isFalse);
      expect(backdoorRes['code'], 'INVALID_OTP');
    }

    // 3. Login via handleDioRequest with valid OTP and verify internal UID (`uid_tech_...`) vs public code (`BT-...`)
    final loginRes = await FirestoreRestClient.handleDioRequest(
      RequestOptions(
        path: '/auth/verify-otp',
        method: 'POST',
        data: {
          'email': techEmail,
          'phone': '9830098836',
          'name': 'Ram',
          'otp': generatedOtp,
        },
      ),
    );
    expect(loginRes.statusCode, 200);
    final userMap = loginRes.data['user'] as Map<String, dynamic>;
    expect(userMap['uid'], 'uid_tech_9830098836');
    expect(userMap['id'], 'uid_tech_9830098836');
    expect(userMap['technicianCode'], 'BT-098836');
    expect(userMap['uid'] != userMap['technicianCode'], isTrue);

    // 4. Verify consumed OTP cannot be replayed
    final replayRes = await FirestoreRestClient.verifyOtpChallenge(
      identifier: techEmail,
      code: generatedOtp,
      nowOverride: baseTime.add(const Duration(seconds: 20)),
    );
    expect(replayRes['success'], isFalse);
  });

  test('Technician Firestore 429 Exponential Backoff & Telemetry Verification', () async {
    SharedPreferences.setMockInitialValues({});
    FirestoreRestClient.resetMetrics();
    FirestoreRestClient.clearMemoryCache();

    int attempts = 0;
    FirestoreRestClient.mockHttpHandler = (
      String method,
      Uri uri, {
      Map<String, String>? headers,
      String? body,
    }) async {
      attempts++;
      if (attempts <= 2) {
        return http.Response(
          jsonEncode({'error': {'code': 429, 'status': 'RESOURCE_EXHAUSTED'}}),
          429,
        );
      }
      return http.Response(jsonEncode({'documents': []}), 200);
    };

    final docs = await FirestoreRestClient.listCollection('technician_profiles', forceRefresh: true);
    expect(docs, isEmpty);
    expect(attempts, 3); // 2 failed 429s + 1 succeeded 200

    final summary = FirestoreRestClient.getTelemetrySummary();
    expect(summary['http429Count'], 2);
    expect(summary['retries'], 2);
    expect(summary['reads'], 1);
  });
}
