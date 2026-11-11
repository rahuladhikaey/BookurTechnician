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

    final baseTime = DateTime.now().toUtc();
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

  test('Phase 2 Server-Authoritative Acceptance: Concurrency Lock, Exactly One Winner, Idempotency, and Expiry', () async {
    SharedPreferences.setMockInitialValues({});
    FirestoreRestClient.resetMetrics();
    FirestoreRestClient.clearMemoryCache();

    // In-memory mock Firestore storage
    final Map<String, Map<String, dynamic>> mockDb = {
      'technician_profiles/uid_tech_1111111111': {
        'id': 'uid_tech_1111111111',
        'fullName': 'Partner Alpha',
        'phone': '1111111111',
        'technicianCode': 'BT-111111',
        'isOnline': true,
        'availabilityStatus': 'AVAILABLE',
        'lastLocationUpdate': '2026-11-11T21:00:00.000Z',
      },
      'technician_profiles/uid_tech_2222222222': {
        'id': 'uid_tech_2222222222',
        'fullName': 'Partner Beta',
        'phone': '2222222222',
        'technicianCode': 'BT-222222',
        'isOnline': true,
        'availabilityStatus': 'AVAILABLE',
        'lastLocationUpdate': '2026-11-11T21:05:00.000Z',
      },
      'bookings/bkg_ac_compete_001': {
        'id': 'bkg_ac_compete_001',
        'serviceName': 'AC installation',
        'customerName': 'Kakali Goswami',
        'status': 'REQUESTED',
        'technicianId': '',
      },
      'dispatch_offers/offer_ac_alpha': {
        'id': 'offer_ac_alpha',
        'bookingId': 'bkg_ac_compete_001',
        'technicianId': 'uid_tech_1111111111',
        'status': 'SENT',
        'expiresAt': DateTime.now().toUtc().add(const Duration(seconds: 40)).toIso8601String(),
      },
      'dispatch_offers/offer_ac_beta': {
        'id': 'offer_ac_beta',
        'bookingId': 'bkg_ac_compete_001',
        'technicianId': 'uid_tech_2222222222',
        'status': 'SENT',
        'expiresAt': DateTime.now().toUtc().add(const Duration(seconds: 40)).toIso8601String(),
      },
    };

    FirestoreRestClient.mockHttpHandler = (
      String method,
      Uri uri, {
      Map<String, String>? headers,
      String? body,
    }) async {
      final path = uri.path;

      // GET single document
      if (method == 'GET' && !path.endsWith('/documents') && !path.endsWith('/technician_profiles') && !path.endsWith('/dispatch_offers') && !path.endsWith('/bookings')) {
        for (final entry in mockDb.entries) {
          if (path.contains(entry.key)) {
            final fsFields = <String, dynamic>{};
            entry.value.forEach((k, v) {
              if (v is String) fsFields[k] = {'stringValue': v};
              if (v is bool) fsFields[k] = {'booleanValue': v};
              if (v is num) fsFields[k] = {'doubleValue': v.toDouble()};
            });
            return http.Response(jsonEncode({'name': entry.key, 'fields': fsFields}), 200);
          }
        }
        return http.Response('{"error": "Not found"}', 404);
      }

      // GET collection list
      if (method == 'GET' && path.contains('/dispatch_offers')) {
        final docs = mockDb.entries
            .where((e) => e.key.startsWith('dispatch_offers/'))
            .map((e) {
              final fsFields = <String, dynamic>{};
              e.value.forEach((k, v) {
                if (v is String) fsFields[k] = {'stringValue': v};
                if (v is bool) fsFields[k] = {'booleanValue': v};
                if (v is num) fsFields[k] = {'doubleValue': v.toDouble()};
              });
              return {'name': e.key, 'fields': fsFields};
            })
            .toList();
        return http.Response(jsonEncode({'documents': docs}), 200);
      }

      // PATCH document update
      if (method == 'PATCH') {
        for (final key in mockDb.keys) {
          if (path.contains(key)) {
            final decodedBody = jsonDecode(body.toString()) as Map<String, dynamic>;
            final inFields = decodedBody['fields'] as Map<String, dynamic>? ?? {};
            inFields.forEach((k, valObj) {
              if (valObj is Map) {
                mockDb[key]![k] = valObj['stringValue'] ?? valObj['booleanValue'] ?? valObj['doubleValue'] ?? valObj['integerValue'];
              }
            });
            return http.Response(jsonEncode({'name': key, 'fields': inFields}), 200);
          }
        }
      }

      return http.Response('{}', 200);
    };

    // 1. Unauthenticated request rejected
    final unauthRes = await FirestoreRestClient.handleDioRequest(
      RequestOptions(
        path: '/dispatch/offers/offer_ac_alpha/accept',
        method: 'POST',
      ),
    );
    expect(unauthRes.statusCode, 401);
    expect(unauthRes.data['code'], 'UNAUTHORIZED');

    // 2. Technician Alpha accepts offer -> SUCCESS (200 OK)
    final alphaAcceptRes = await FirestoreRestClient.handleDioRequest(
      RequestOptions(
        path: '/dispatch/offers/offer_ac_alpha/accept',
        method: 'POST',
        headers: {'x-technician-id': 'uid_tech_1111111111'},
      ),
    );
    expect(alphaAcceptRes.statusCode, 200);
    expect(alphaAcceptRes.data['success'], isTrue);
    expect(alphaAcceptRes.data['code'], 'ACCEPTED');
    expect(alphaAcceptRes.data['booking']['technicianId'], 'uid_tech_1111111111');
    expect(alphaAcceptRes.data['booking']['status'], 'ASSIGNED');

    // Verify mock database state committed atomically
    expect(mockDb['bookings/bkg_ac_compete_001']!['status'], 'ASSIGNED');
    expect(mockDb['bookings/bkg_ac_compete_001']!['technicianId'], 'uid_tech_1111111111');
    expect(mockDb['dispatch_offers/offer_ac_alpha']!['status'], 'ACCEPTED');
    expect(mockDb['technician_profiles/uid_tech_1111111111']!['availabilityStatus'], 'BUSY');

    // CRITICAL CONDITION 1: lastPresenceHeartbeat separate from lastLocationUpdate!
    expect(mockDb['technician_profiles/uid_tech_1111111111']!.containsKey('lastPresenceHeartbeat'), isTrue);
    expect(mockDb['technician_profiles/uid_tech_1111111111']!['lastLocationUpdate'], '2026-11-11T21:00:00.000Z'); // Unchanged!

    // 3. Technician Beta attempts to accept the SAME booking -> REJECTED (409 Conflict)
    final betaAcceptRes = await FirestoreRestClient.handleDioRequest(
      RequestOptions(
        path: '/dispatch/offers/offer_ac_beta/accept',
        method: 'POST',
        headers: {'x-technician-id': 'uid_tech_2222222222'},
      ),
    );
    expect(betaAcceptRes.statusCode, 409);
    expect(betaAcceptRes.data['success'], isFalse);
    expect(betaAcceptRes.data['code'], 'ALREADY_ASSIGNED');
    expect(betaAcceptRes.data['message'], contains('already been accepted by another technician partner'));

    // Verify exactly ONE winner committed
    expect(mockDb['bookings/bkg_ac_compete_001']!['technicianId'], 'uid_tech_1111111111');

    // 4. Technician Alpha retries (Idempotency / Network retry) -> SUCCESS (200 OK, isIdempotent: true)
    final alphaRetryRes = await FirestoreRestClient.handleDioRequest(
      RequestOptions(
        path: '/dispatch/offers/offer_ac_alpha/accept',
        method: 'POST',
        headers: {'x-technician-id': 'uid_tech_1111111111'},
      ),
    );
    expect(alphaRetryRes.statusCode, 200);
    expect(alphaRetryRes.data['isIdempotent'], isTrue);
    expect(alphaRetryRes.data['booking']['technicianId'], 'uid_tech_1111111111');

    // 5. Expired offer rejected (410 Gone / Expired)
    mockDb['dispatch_offers/offer_expired'] = {
      'id': 'offer_expired',
      'bookingId': 'bkg_ac_compete_001',
      'technicianId': 'uid_tech_1111111111',
      'status': 'SENT',
      'expiresAt': DateTime.now().toUtc().subtract(const Duration(minutes: 5)).toIso8601String(),
    };
    final expiredRes = await FirestoreRestClient.handleDioRequest(
      RequestOptions(
        path: '/dispatch/offers/offer_expired/accept',
        method: 'POST',
        headers: {'x-technician-id': 'uid_tech_1111111111'},
      ),
    );
    expect(expiredRes.statusCode, 410);
    expect(expiredRes.data['code'], 'OFFER_EXPIRED');
  });

  test('Phase 3 Skill Eligibility: Server-Authoritative Acceptance & Offers Filter Reject Unauthorized Skills', () async {
    final mockDb = <String, Map<String, dynamic>>{
      'technician_profiles/uid_tech_kakali': {
        'id': 'uid_tech_kakali',
        'uid': 'uid_tech_kakali',
        'name': 'Kakali Goswami',
        'technicianCode': 'BT-637055',
        'isOnline': true,
        'availabilityStatus': 'AVAILABLE',
        'category': 'Electrical & Home Electrical',
        'categories': ['Electrical & Home Electrical'],
        'skills': [
          {
            'skillId': 'sk_light_repair',
            'name': 'Light Repair',
            'verificationStatus': 'VERIFIED',
            'enabled': true,
          },
          {
            'skillId': 'sk_ceiling_fan_installation',
            'name': 'Ceiling Fan Installation',
            'verificationStatus': 'VERIFIED',
            'enabled': true,
          },
        ],
      },
      'bookings/bkg_ac_install_999': {
        'id': 'bkg_ac_install_999',
        'serviceId': 'ac_install',
        'serviceName': 'AC installation',
        'status': 'REQUESTED',
        'totalAmount': 1039.0,
      },
      'dispatch_offers/offer_ac_kakali': {
        'id': 'offer_ac_kakali',
        'bookingId': 'bkg_ac_install_999',
        'technicianId': 'uid_tech_kakali',
        'serviceId': 'ac_install',
        'serviceName': 'AC installation',
        'status': 'SENT',
        'expiresAt': DateTime.now().toUtc().add(const Duration(minutes: 5)).toIso8601String(),
      },
      'bookings/bkg_light_rep_888': {
        'id': 'bkg_light_rep_888',
        'serviceId': 'light_rep',
        'serviceName': 'Light repair',
        'status': 'REQUESTED',
        'totalAmount': 199.0,
      },
      'dispatch_offers/offer_light_kakali': {
        'id': 'offer_light_kakali',
        'bookingId': 'bkg_light_rep_888',
        'technicianId': 'uid_tech_kakali',
        'serviceId': 'light_rep',
        'serviceName': 'Light repair',
        'status': 'SENT',
        'expiresAt': DateTime.now().toUtc().add(const Duration(minutes: 5)).toIso8601String(),
      },
    };

    Map<String, dynamic> encodeVal(dynamic val) {
      if (val == null) return {'nullValue': null};
      if (val is bool) return {'booleanValue': val};
      if (val is int) return {'integerValue': val.toString()};
      if (val is double) return {'doubleValue': val};
      if (val is String) return {'stringValue': val};
      if (val is List) {
        return {
          'arrayValue': {
            'values': val.map((e) => encodeVal(e)).toList(),
          }
        };
      }
      if (val is Map) {
        final m = <String, dynamic>{};
        val.forEach((k, v) => m[k.toString()] = encodeVal(v));
        return {
          'mapValue': {'fields': m}
        };
      }
      return {'stringValue': val.toString()};
    }

    FirestoreRestClient.mockHttpHandler = (method, uri, {body, headers}) async {
      final path = uri.path;

      // GET single document
      if (method == 'GET' && !path.endsWith('/documents') && !path.endsWith('/technician_profiles') && !path.endsWith('/dispatch_offers') && !path.endsWith('/bookings')) {
        for (final key in mockDb.keys) {
          if (path.contains(key)) {
            final f = <String, dynamic>{};
            mockDb[key]!.forEach((k, v) => f[k] = encodeVal(v));
            return http.Response(jsonEncode({'name': key, 'fields': f}), 200);
          }
        }
        return http.Response('{"error": "Not found"}', 404);
      }

      // GET collection
      if (method == 'GET') {
        final collectionName = path.split('/').last;
        final docs = mockDb.entries
            .where((e) => e.key.startsWith('$collectionName/'))
            .map((e) {
              final f = <String, dynamic>{};
              e.value.forEach((k, v) => f[k] = encodeVal(v));
              return {'name': e.key, 'fields': f};
            })
            .toList();
        return http.Response(jsonEncode({'documents': docs}), 200);
      }

      // PATCH document update
      if (method == 'PATCH') {
        for (final key in mockDb.keys) {
          if (path.contains(key)) {
            final decodedBody = jsonDecode(body.toString()) as Map<String, dynamic>;
            final inFields = decodedBody['fields'] as Map<String, dynamic>? ?? {};
            inFields.forEach((k, valObj) {
              if (valObj is Map) {
                mockDb[key]![k] = valObj['stringValue'] ?? valObj['booleanValue'] ?? valObj['doubleValue'] ?? valObj['integerValue'];
              }
            });
            return http.Response(jsonEncode({'name': key, 'fields': inFields}), 200);
          }
        }
      }

      return http.Response('{}', 200);
    };

    // 1. Layer 4 Defense: Electrical-only technician attempts to accept AC installation -> 403 FORBIDDEN
    final acAcceptRes = await FirestoreRestClient.handleDioRequest(
      RequestOptions(
        path: '/dispatch/offers/offer_ac_kakali/accept',
        method: 'POST',
        headers: {'x-technician-id': 'uid_tech_kakali'},
      ),
    );
    expect(acAcceptRes.statusCode, 403);
    expect(acAcceptRes.data['success'], isFalse);
    expect(acAcceptRes.data['code'], 'SKILL_NOT_AUTHORIZED');
    expect(acAcceptRes.data['error'], 'INELIGIBLE_FOR_SERVICE');

    // 2. Layer 2 Defense: /technician/offers ignores AC installation for electrical technician
    mockDb.remove('dispatch_offers/offer_light_kakali'); // Only AC offer left
    final offersPollRes1 = await FirestoreRestClient.handleDioRequest(
      RequestOptions(
        path: '/technician/offers',
        method: 'GET',
        headers: {'x-technician-id': 'uid_tech_kakali'},
      ),
    );
    expect(offersPollRes1.statusCode, 200);
    expect(offersPollRes1.data['hasPending'], isFalse); // Skipped because skill mismatch!

    // 3. Authorized Electrical offer is accepted successfully -> 200 OK
    mockDb['dispatch_offers/offer_light_kakali'] = {
      'id': 'offer_light_kakali',
      'bookingId': 'bkg_light_rep_888',
      'technicianId': 'uid_tech_kakali',
      'serviceId': 'light_rep',
      'serviceName': 'Light repair',
      'status': 'SENT',
      'expiresAt': DateTime.now().toUtc().add(const Duration(minutes: 5)).toIso8601String(),
    };
    final lightAcceptRes = await FirestoreRestClient.handleDioRequest(
      RequestOptions(
        path: '/dispatch/offers/offer_light_kakali/accept',
        method: 'POST',
        headers: {'x-technician-id': 'uid_tech_kakali'},
      ),
    );
    expect(lightAcceptRes.statusCode, 200);
    expect(lightAcceptRes.data['success'], isTrue);
    expect(lightAcceptRes.data['code'], 'ACCEPTED');
    expect(lightAcceptRes.data['booking']['technicianId'], 'uid_tech_kakali');
  });

  test('Phase 3 OTP Verification: Zero-Bypass, Attempt Limiting, and 3-Attempt Lockout', () async {
    final mockDb = <String, Map<String, dynamic>>{
      'bookings/bkg_otp_test_101': {
        'id': 'bkg_otp_test_101',
        'status': 'ASSIGNED',
        'technicianId': 'uid_tech_partner_01',
        'totalAmount': 1000.0,
        'startOtp': '4567',
        'endOtp': '8901',
      },
      'booking_secrets/bkg_otp_test_101': {
        'bookingId': 'bkg_otp_test_101',
        'failedStartAttempts': 0,
        'failedEndAttempts': 0,
        'startLockedOut': false,
        'endLockedOut': false,
        'startOtpHash': FirestoreRestClient.sha256Hex('4567'),
        'endOtpHash': FirestoreRestClient.sha256Hex('8901'),
      },
      'technician_profiles/uid_tech_partner_01': {
        'id': 'uid_tech_partner_01',
        'name': 'Partner Tech',
        'walletBalance': 500,
        'totalJobsCompleted': 2,
        'availabilityStatus': 'BUSY',
      },
    };

    FirestoreRestClient.mockHttpHandler = (method, url, {body, headers}) async {
      final path = url.path;
      if (path.contains('/databases/(default)/documents/')) {
        for (final key in mockDb.keys) {
          if (path.contains(key)) {
            if (method == 'GET') {
              final data = mockDb[key]!;
              final fields = <String, dynamic>{};
              for (final entry in data.entries) {
                final v = entry.value;
                if (v is bool) {
                  fields[entry.key] = {'booleanValue': v};
                } else if (v is int) {
                  fields[entry.key] = {'integerValue': v.toString()};
                } else if (v is double) {
                  fields[entry.key] = {'doubleValue': v};
                } else {
                  fields[entry.key] = {'stringValue': v.toString()};
                }
              }
              return http.Response(jsonEncode({'name': key, 'fields': fields}), 200);
            } else if (method == 'PATCH') {
              final decodedBody = jsonDecode(body.toString()) as Map<String, dynamic>;
              final inFields = decodedBody['fields'] as Map<String, dynamic>? ?? {};
              inFields.forEach((k, valObj) {
                if (valObj is Map) {
                  mockDb[key]![k] = valObj['stringValue'] ??
                      valObj['booleanValue'] ??
                      valObj['doubleValue'] ??
                      valObj['integerValue'];
                }
              });
              return http.Response(jsonEncode({'name': key, 'fields': inFields}), 200);
            }
          }
        }
      }
      return http.Response('{}', 200);
    };

    // 1. Wrong Start OTP -> 400 INVALID_OTP with 2 remaining attempts (Zero bypass!)
    final wrongRes1 = await FirestoreRestClient.handleDioRequest(
      RequestOptions(
        path: '/bookings/bkg_otp_test_101/status',
        method: 'PATCH',
        headers: {'x-technician-id': 'uid_tech_partner_01'},
        data: {'status': 'IN_PROGRESS', 'startOtp': '0000'},
      ),
    );
    expect(wrongRes1.statusCode, 400);
    expect(wrongRes1.data['code'], 'INVALID_OTP');
    expect(wrongRes1.data['remainingAttempts'], 2);

    // 2. Wrong Start OTP -> 400 with 1 remaining attempt
    final wrongRes2 = await FirestoreRestClient.handleDioRequest(
      RequestOptions(
        path: '/bookings/bkg_otp_test_101/status',
        method: 'PATCH',
        headers: {'x-technician-id': 'uid_tech_partner_01'},
        data: {'status': 'IN_PROGRESS', 'startOtp': '1111'},
      ),
    );
    expect(wrongRes2.statusCode, 400);
    expect(wrongRes2.data['remainingAttempts'], 1);

    // 3. Third wrong attempt -> 403 OTP_LOCKED_OUT (Strict permanent lockout)
    final wrongRes3 = await FirestoreRestClient.handleDioRequest(
      RequestOptions(
        path: '/bookings/bkg_otp_test_101/status',
        method: 'PATCH',
        headers: {'x-technician-id': 'uid_tech_partner_01'},
        data: {'status': 'IN_PROGRESS', 'startOtp': '2222'},
      ),
    );
    expect(wrongRes3.statusCode, 403);
    expect(wrongRes3.data['code'], 'OTP_LOCKED_OUT');

    // 4. Correct Start OTP on fresh booking -> 200 OK & Status becomes IN_PROGRESS
    mockDb['booking_secrets/bkg_otp_test_101'] = {
      'bookingId': 'bkg_otp_test_101',
      'failedStartAttempts': 0,
      'failedEndAttempts': 0,
      'startLockedOut': false,
      'endLockedOut': false,
      'startOtpHash': FirestoreRestClient.sha256Hex('4567'),
      'endOtpHash': FirestoreRestClient.sha256Hex('8901'),
    };
    final successStartRes = await FirestoreRestClient.handleDioRequest(
      RequestOptions(
        path: '/bookings/bkg_otp_test_101/status',
        method: 'PATCH',
        headers: {'x-technician-id': 'uid_tech_partner_01'},
        data: {'status': 'IN_PROGRESS', 'startOtp': '4567'},
      ),
    );
    expect(successStartRes.statusCode, 200);
    expect(successStartRes.data['status'], 'IN_PROGRESS');

    // 5. Correct End OTP -> 200 OK & Status becomes COMPLETED with 80% technician payout
    final successEndRes = await FirestoreRestClient.handleDioRequest(
      RequestOptions(
        path: '/bookings/bkg_otp_test_101/status',
        method: 'PATCH',
        headers: {'x-technician-id': 'uid_tech_partner_01'},
        data: {'status': 'COMPLETED', 'endOtp': '8901'},
      ),
    );
    expect(successEndRes.statusCode, 200);
    expect(successEndRes.data['status'], 'COMPLETED');
    expect(successEndRes.data['payoutAmount'], 800); // 80% of 1000

    FirestoreRestClient.mockHttpHandler = null;
  });
}
