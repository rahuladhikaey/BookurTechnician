import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:customer_app_flutter/booking_provider.dart';
import 'package:customer_app_flutter/models.dart';
import 'package:customer_app_flutter/services/firestore_rest_client.dart';

Map<String, dynamic> _toFirestoreDoc(String collection, String id, Map<String, dynamic> fields, {String? updateTime}) {
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

  final encodedFields = <String, dynamic>{};
  fields.forEach((k, v) {
    if (!k.startsWith('_')) {
      encodedFields[k] = encodeVal(v);
    }
  });

  return {
    'name': 'projects/bookmytechnician-53d94/databases/(default)/documents/$collection/$id',
    'fields': encodedFields,
    'updateTime': updateTime ?? '2026-11-08T00:00:00.000000Z',
  };
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Map<String, Map<String, dynamic>> mockTechProfiles;
  late Map<String, Map<String, dynamic>> mockBookings;
  late Map<String, Map<String, dynamic>> mockCategories;
  late Map<String, Map<String, dynamic>> mockOtpChallenges;
  int commitVersionCounter = 1;

  void setupDefaultMockFirestore() {
    FirestoreRestClient.resetMetrics();
    FirestoreRestClient.clearMemoryCache();
    FirestoreRestClient.clearOtpChallengesForTest();
    commitVersionCounter = 1;

    final freshIso = DateTime.now().toUtc().toIso8601String();
    mockTechProfiles = {
      'uid_tech_988363': {
        'id': 'uid_tech_988363',
        'uid': 'uid_tech_988363',
        'technicianId': 'uid_tech_988363',
        'technicianCode': 'BT-988363',
        'fullName': 'Ram',
        'phone': '9830098836',
        'email': 'ram@bookurtechnician.com',
        'isOnline': true,
        'online': true,
        'availabilityStatus': 'AVAILABLE',
        'kycStatus': 'VERIFIED',
        'accountStatus': 'ACTIVE',
        'latitude': 22.5726,
        'longitude': 88.3639,
        'lastLocationUpdate': freshIso,
        'skills': [
          {'skillId': 'ac_install', 'name': 'AC installation', 'enabled': true},
        ],
        '_updateTime': '2026-11-08T00:00:01.000000Z',
      },
    };

    mockBookings = {};

    mockCategories = {
      'cat_ac': {
        'id': 'cat_ac',
        'name': 'AC Services',
        'icon': 'ac_unit',
        'displayOrder': 1,
        'subcategories': [
          {
            'id': 'sub_ac',
            'name': 'AC Installation & Repair',
            'services': [
              {
                'id': 'ac_install',
                'name': 'AC installation',
                'price': 1299,
                'durationMinutes': 90,
                'warrantyText': '30 Days Warranty',
                'description': 'Split & Window AC installation',
                'imageUrl': 'assets/images/ac.png',
                'active': true,
              }
            ],
          }
        ],
      },
    };

    mockOtpChallenges = {};

    FirestoreRestClient.mockHttpHandler = (
      String method,
      Uri uri, {
      Map<String, String>? headers,
      String? body,
    }) async {
      final path = uri.path;

      // Handle atomic Firestore :commit transaction
      if (path.endsWith(':commit') && method == 'POST') {
        final decoded = jsonDecode(body.toString()) as Map<String, dynamic>;
        final writes = (decoded['writes'] as List<dynamic>? ?? []);

        // Optimistic concurrency precondition verification
        for (final w in writes) {
          if (w is Map<String, dynamic>) {
            final update = w['update'] as Map<String, dynamic>?;
            final currentDoc = w['currentDocument'] as Map<String, dynamic>?;
            if (update != null) {
              final docName = update['name']?.toString() ?? '';
              if (docName.contains('/technician_profiles/')) {
                final tId = docName.split('/technician_profiles/').last;
                final existingTech = mockTechProfiles[tId];
                if (existingTech == null) {
                  return http.Response(jsonEncode({'error': {'status': 'NOT_FOUND'}}), 404);
                }
                final expectedUpdateTime = currentDoc?['updateTime']?.toString();
                if (expectedUpdateTime != null &&
                    expectedUpdateTime.isNotEmpty &&
                    existingTech['_updateTime'] != expectedUpdateTime) {
                  // Optimistic concurrency failure: document changed since read!
                  return http.Response(
                    jsonEncode({
                      'error': {
                        'code': 409,
                        'status': 'ABORTED',
                        'message': 'Precondition updateTime mismatch on technician profile.',
                      }
                    }),
                    409,
                  );
                }
                if (existingTech['availabilityStatus'] == 'BUSY') {
                  return http.Response(
                    jsonEncode({
                      'error': {
                        'code': 409,
                        'status': 'ABORTED',
                        'message': 'Technician already BUSY.',
                      }
                    }),
                    409,
                  );
                }
              }
            }
          }
        }

        // Apply atomic commit writes
        for (final w in writes) {
          if (w is Map<String, dynamic>) {
            final update = w['update'] as Map<String, dynamic>?;
            if (update != null) {
              final docName = update['name']?.toString() ?? '';
              final fields = update['fields'] as Map<String, dynamic>? ?? {};
              if (docName.contains('/technician_profiles/')) {
                final tId = docName.split('/technician_profiles/').last;
                final existingTech = mockTechProfiles[tId]!;
                if (fields.containsKey('availabilityStatus')) {
                  existingTech['availabilityStatus'] = fields['availabilityStatus']['stringValue'];
                }
                if (fields.containsKey('activeBookingId')) {
                  existingTech['activeBookingId'] = fields['activeBookingId']['stringValue'];
                }
                commitVersionCounter++;
                existingTech['_updateTime'] = '2026-11-08T00:00:0$commitVersionCounter.000000Z';
              } else if (docName.contains('/bookings/')) {
                final bId = docName.split('/bookings/').last;
                final parsedBooking = <String, dynamic>{'id': bId};
                fields.forEach((k, v) {
                  if (v is Map) {
                    parsedBooking[k] = v.values.first;
                  }
                });
                mockBookings[bId] = parsedBooking;
              }
            }
          }
        }

        return http.Response(jsonEncode({'writeResults': []}), 200);
      }

      if (path.contains('/technician_profiles')) {
        final docs = mockTechProfiles.entries
            .map((e) => _toFirestoreDoc('technician_profiles', e.key, e.value, updateTime: e.value['_updateTime']?.toString()))
            .toList();
        return http.Response(jsonEncode({'documents': docs}), 200);
      }

      if (path.contains('/bookings')) {
        final docs = mockBookings.entries
            .map((e) => _toFirestoreDoc('bookings', e.key, e.value))
            .toList();
        return http.Response(jsonEncode({'documents': docs}), 200);
      }

      if (path.contains('/service_categories')) {
        final docs = mockCategories.entries
            .map((e) => _toFirestoreDoc('service_categories', e.key, e.value))
            .toList();
        return http.Response(jsonEncode({'documents': docs}), 200);
      }

      if (path.contains('/otp_challenges/')) {
        final docId = path.split('/otp_challenges/').last;
        if (method == 'GET') {
          final existing = mockOtpChallenges[docId];
          if (existing == null) return http.Response('{}', 404);
          return http.Response(jsonEncode(_toFirestoreDoc('otp_challenges', docId, existing)), 200);
        } else if (method == 'PATCH') {
          return http.Response(jsonEncode(_toFirestoreDoc('otp_challenges', docId, {'id': docId})), 200);
        }
      }

      return http.Response(jsonEncode({'documents': []}), 200);
    };
  }

  tearDown(() {
    FirestoreRestClient.mockHttpHandler = null;
  });

  test('Scenario 1: Two customers attempting to book the same technician simultaneously (Atomic Precondition & Lock)', () async {
    SharedPreferences.setMockInitialValues({});
    setupDefaultMockFirestore();

    final bodyCustomerA = {
      'id': 'bkg_cust_A',
      'customerId': 'uid_cust_111',
      'customerName': 'Customer A',
      'customerPhone': '9000000001',
      'serviceId': 'ac_install',
      'serviceName': 'AC installation',
      'latitude': 22.5726,
      'longitude': 88.3639,
      'idempotencyKey': 'idem_cust_A_001',
    };

    final bodyCustomerB = {
      'id': 'bkg_cust_B',
      'customerId': 'uid_cust_222',
      'customerName': 'Customer B',
      'customerPhone': '9000000002',
      'serviceId': 'ac_install',
      'serviceName': 'AC installation',
      'latitude': 22.5726,
      'longitude': 88.3639,
      'idempotencyKey': 'idem_cust_B_002',
    };

    // Fire both booking requests concurrently
    final results = await Future.wait([
      FirestoreRestClient.handleRequest('POST', '/bookings', bodyCustomerA),
      FirestoreRestClient.handleRequest('POST', '/bookings', bodyCustomerB),
    ]);

    final statusCodes = results.map((r) => r.statusCode).toList();
    // Exactly one must succeed with 201 and the other must fail with 409 conflict
    expect(statusCodes.where((s) => s == 201).length, 1);
    expect(statusCodes.where((s) => s == 409).length, 1);

    final winnerRes = results.firstWhere((r) => r.statusCode == 201);
    final loserRes = results.firstWhere((r) => r.statusCode == 409);

    final winnerData = jsonDecode(winnerRes.body);
    final loserData = jsonDecode(loserRes.body);

    expect(winnerData['success'], isTrue);
    expect(winnerData['booking']['status'], 'ASSIGNED');
    expect(winnerData['booking']['technicianId'], 'uid_tech_988363');
    expect(winnerData['booking']['technicianCode'], 'BT-988363');

    expect(loserData['success'], isFalse);
    expect(loserData['code'], 'TECHNICIAN_BUSY_CONFLICT');
  });

  test('Scenario 2: Technician going offline during checkout (Live revalidation blocks booking)', () async {
    SharedPreferences.setMockInitialValues({});
    setupDefaultMockFirestore();

    final notifier = BookingNotifier();
    await notifier.fetchNearbyAvailability(lat: 22.5726, lng: 88.3639, forceRefresh: true);

    // Initially 1 technician is online in state
    expect(notifier.state.getServiceAvailabilityCount('ac_install'), 1);
    expect(notifier.state.isServiceLiveConfirmedAvailable('ac_install'), isTrue);

    // Technician goes offline while customer is on the checkout modal
    mockTechProfiles['uid_tech_988363']!['isOnline'] = false;
    mockTechProfiles['uid_tech_988363']!['online'] = false;
    mockTechProfiles['uid_tech_988363']!['availabilityStatus'] = 'OFFLINE';

    const service = ServiceItem(
      id: 'ac_install',
      name: 'AC installation',
      price: 1299,
      durationMinutes: 90,
      warrantyText: '30 Days',
      description: 'AC Install',
      imageUrl: 'assets/images/ac.png',
    );

    final booked = await notifier.confirmDirectServiceBooking(
      service: service,
      date: 'Today',
      slot: '3:00 PM – 4:00 PM',
    );

    // Must NOT create a fake local booking!
    expect(booked, isNull);
    expect(notifier.state.activeBooking, isNull);
    expect(notifier.state.bookingErrorCode, 'TECHNICIAN_WENT_OFFLINE');
    expect(notifier.state.getServiceAvailabilityCount('ac_install'), 0);
  });

  test('Scenario 3: Stale GPS location (>10 minutes old rejected at availability and booking)', () async {
    SharedPreferences.setMockInitialValues({});
    setupDefaultMockFirestore();

    // Set technician GPS heartbeat to 25 minutes ago
    final staleIso = DateTime.now().toUtc().subtract(const Duration(minutes: 25)).toIso8601String();
    mockTechProfiles['uid_tech_988363']!['lastLocationUpdate'] = staleIso;

    final availRes = await FirestoreRestClient.handleRequest(
      'GET',
      '/catalog/availability?latitude=22.5726&longitude=88.3639&radiusKm=15&serviceId=ac_install&forceRefresh=true',
    );
    final availData = jsonDecode(availRes.body);
    expect(availData['availableTechnicianCount'], 0);

    final bookingRes = await FirestoreRestClient.handleRequest('POST', '/bookings', {
      'id': 'bkg_stale_test',
      'customerId': 'uid_cust_333',
      'serviceId': 'ac_install',
      'serviceName': 'AC installation',
      'latitude': 22.5726,
      'longitude': 88.3639,
      'idempotencyKey': 'idem_stale_001',
    });

    expect(bookingRes.statusCode, 409);
    final bookingData = jsonDecode(bookingRes.body);
    expect(bookingData['success'], isFalse);
    expect(bookingData['code'], 'STALE_LOCATION');
  });

  test('Scenario 4: Firestore 429 response (Exponential backoff retry, telemetry counter, and explicit QUOTA_EXCEEDED state)', () async {
    SharedPreferences.setMockInitialValues({});
    setupDefaultMockFirestore();

    int attemptCount = 0;
    FirestoreRestClient.mockHttpHandler = (
      String method,
      Uri uri, {
      Map<String, String>? headers,
      String? body,
    }) async {
      attemptCount++;
      return http.Response(
        jsonEncode({
          'error': {
            'code': 429,
            'status': 'RESOURCE_EXHAUSTED',
            'message': 'Quota exceeded or write hotspot rate limit.',
          }
        }),
        429,
      );
    };

    final notifier = BookingNotifier();
    await notifier.fetchSingleServiceAvailability('ac_install', lat: 22.5726, lng: 88.3639, forceRefresh: true);

    // Verify exponential backoff retried (initial + retries) and recorded 429 telemetry
    final telemetry = FirestoreRestClient.getTelemetrySummary();
    expect(attemptCount, greaterThan(1));
    expect(telemetry['http429Count'], greaterThan(0));
    expect(telemetry['retries'], greaterThan(0));

    // Verify UI state is explicitly quotaExceeded and NOT false empty availability
    expect(
      notifier.state.getServiceAvailabilityState('ac_install'),
      ServiceAvailabilityState.quotaExceeded,
    );
    expect(notifier.state.bookingErrorCode, 'QUOTA_EXCEEDED');
  });

  test('Scenario 5: App restart with cached availability (Restores cache labelled as cached, revalidates live before booking)', () async {
    // Simulate persisted cache in SharedPreferences before app restart
    SharedPreferences.setMockInitialValues({
      'bt_cached_availability_v1': jsonEncode({
        'counts': {'ac_install': 2},
        'cachedAt': DateTime.now().toUtc().subtract(const Duration(minutes: 2)).toIso8601String(),
      }),
      'bt_cached_categories_v1': jsonEncode([
        {
          'id': 'cat_ac',
          'name': 'AC Services',
          'icon': 'ac_unit',
          'displayOrder': 1,
          'subcategories': [
            {
              'id': 'sub_ac',
              'name': 'AC Care',
              'services': [
                {
                  'id': 'ac_install',
                  'name': 'AC installation',
                  'price': 1299,
                  'durationMinutes': 90,
                  'warrantyText': '30 Days',
                  'description': 'AC installation',
                  'imageUrl': 'assets/images/ac.png',
                }
              ],
            }
          ],
        }
      ]),
    });

    setupDefaultMockFirestore();
    final notifier = BookingNotifier();
    await notifier.restoreCachedCatalogAndAvailability();

    // Verify cache survived restart and is explicitly marked as cached
    expect(notifier.state.isCategoriesCached, isTrue);
    expect(notifier.state.isAvailabilityCached, isTrue);
    expect(notifier.state.getServiceAvailabilityCount('ac_install'), 2);
    expect(
      notifier.state.getServiceAvailabilityText('ac_install'),
      contains('Cached (2 online) • Verifying live...'),
    );
    // Cached availability alone must NOT count as live-confirmed availability
    expect(notifier.state.isServiceLiveConfirmedAvailable('ac_install'), isFalse);

    // Now test booking when cached says 2 online, proving it revalidates live server data (which has 1 online)
    const service = ServiceItem(
      id: 'ac_install',
      name: 'AC installation',
      price: 1299,
      durationMinutes: 90,
      warrantyText: '30 Days',
      description: 'AC Install',
      imageUrl: 'assets/images/ac.png',
    );

    final booked = await notifier.confirmDirectServiceBooking(
      service: service,
      date: 'Today',
      slot: '3:00 PM – 4:00 PM',
    );

    expect(booked, isNotNull);
    expect(notifier.state.isAvailabilityCached, isFalse);
    expect(notifier.state.getServiceAvailabilityCount('ac_install'), 1);
  });

  test('Scenario 6: Network disconnection during booking (Never creates fake local confirmed booking)', () async {
    SharedPreferences.setMockInitialValues({});
    setupDefaultMockFirestore();

    final notifier = BookingNotifier();
    await notifier.fetchNearbyAvailability(lat: 22.5726, lng: 88.3639, forceRefresh: true);
    expect(notifier.state.getServiceAvailabilityCount('ac_install'), 1);

    // Simulate network disconnection right when customer clicks Confirm Booking
    FirestoreRestClient.mockHttpHandler = (
      String method,
      Uri uri, {
      Map<String, String>? headers,
      String? body,
    }) async {
      throw Exception('SocketException: Network unreachable');
    };

    const service = ServiceItem(
      id: 'ac_install',
      name: 'AC installation',
      price: 1299,
      durationMinutes: 90,
      warrantyText: '30 Days',
      description: 'AC Install',
      imageUrl: 'assets/images/ac.png',
    );

    final booked = await notifier.confirmDirectServiceBooking(
      service: service,
      date: 'Today',
      slot: '3:00 PM – 4:00 PM',
    );

    expect(booked, isNull);
    expect(notifier.state.activeBooking, isNull);
    expect(notifier.state.bookingErrorCode, 'NETWORK_ERROR');
  });

  test('Scenario 7: Duplicate booking request (Idempotency key rejects duplicate with 409 DUPLICATE_BOOKING)', () async {
    SharedPreferences.setMockInitialValues({});
    setupDefaultMockFirestore();

    final payload = {
      'id': 'bkg_dup_001',
      'customerId': 'uid_cust_777',
      'customerName': 'Customer Dup',
      'customerPhone': '9000000007',
      'serviceId': 'ac_install',
      'serviceName': 'AC installation',
      'latitude': 22.5726,
      'longitude': 88.3639,
      'idempotencyKey': 'idem_unique_key_999',
    };

    final firstRes = await FirestoreRestClient.handleRequest('POST', '/bookings', payload);
    expect(firstRes.statusCode, 201);

    // Second request with the same idempotencyKey must be rejected as 409 DUPLICATE_BOOKING
    final secondRes = await FirestoreRestClient.handleRequest('POST', '/bookings', payload);
    expect(secondRes.statusCode, 409);
    final secondData = jsonDecode(secondRes.body);
    expect(secondData['code'], 'DUPLICATE_BOOKING');
  });

  test('Scenario 8: Expired OTP, repeated failed OTP attempts (5-attempt lockout), and OTP request rate limit (3/10m)', () async {
    SharedPreferences.setMockInitialValues({});
    setupDefaultMockFirestore();

    final baseTime = DateTime.utc(2026, 11, 8, 12, 0, 0);
    const email = 'security_test@bookurtechnician.com';

    // 8A: Request OTP and test expiration after 11 minutes (>10m limit)
    final req1 = await FirestoreRestClient.requestOtpChallenge(
      identifier: email,
      email: email,
      nowOverride: baseTime,
    );
    expect(req1['success'], isTrue);
    final otp1 = req1['_testOtp'] as String;
    expect(otp1.length, 6);

    // Hardcoded '123456' must NOT be accepted (unless random happened to pick 123456)
    if (otp1 != '123456') {
      final backdoorTry = await FirestoreRestClient.verifyOtpChallenge(
        identifier: email,
        code: '123456',
        nowOverride: baseTime.add(const Duration(minutes: 1)),
      );
      expect(backdoorTry['success'], isFalse);
      expect(backdoorTry['code'], 'INVALID_OTP');
    }

    // Verify after 11 minutes -> must fail with OTP_EXPIRED
    final expiredTry = await FirestoreRestClient.verifyOtpChallenge(
      identifier: email,
      code: otp1,
      nowOverride: baseTime.add(const Duration(minutes: 11)),
    );
    expect(expiredTry['success'], isFalse);
    expect(expiredTry['code'], 'OTP_EXPIRED');

    // 8B: Rate limiting — max 3 OTP requests within 10 minutes
    const rateUser = 'ratelimit@bookurtechnician.com';
    final r1 = await FirestoreRestClient.requestOtpChallenge(identifier: rateUser, nowOverride: baseTime);
    final r2 = await FirestoreRestClient.requestOtpChallenge(identifier: rateUser, nowOverride: baseTime.add(const Duration(minutes: 1)));
    final r3 = await FirestoreRestClient.requestOtpChallenge(identifier: rateUser, nowOverride: baseTime.add(const Duration(minutes: 2)));
    final r4 = await FirestoreRestClient.requestOtpChallenge(identifier: rateUser, nowOverride: baseTime.add(const Duration(minutes: 3)));

    expect(r1['success'], isTrue);
    expect(r2['success'], isTrue);
    expect(r3['success'], isTrue);
    expect(r4['success'], isFalse);
    expect(r4['statusCode'], 429);
    expect(r4['code'], 'OTP_RATE_LIMIT_EXCEEDED');

    // 8C: 5 failed OTP attempts -> 429 OTP_ATTEMPT_LIMIT_EXCEEDED lockout
    const bruteUser = 'bruteforce@bookurtechnician.com';
    final reqBrute = await FirestoreRestClient.requestOtpChallenge(identifier: bruteUser, nowOverride: baseTime);
    final validOtp = reqBrute['_testOtp'] as String;
    final wrongOtp = validOtp == '999999' ? '888888' : '999999';

    for (int i = 1; i <= 4; i++) {
      final res = await FirestoreRestClient.verifyOtpChallenge(
        identifier: bruteUser,
        code: wrongOtp,
        nowOverride: baseTime.add(Duration(seconds: i * 5)),
      );
      expect(res['success'], isFalse);
      expect(res['code'], 'INVALID_OTP');
    }

    // 5th wrong attempt triggers 15-minute lockout
    final res5 = await FirestoreRestClient.verifyOtpChallenge(
      identifier: bruteUser,
      code: wrongOtp,
      nowOverride: baseTime.add(const Duration(seconds: 30)),
    );
    expect(res5['success'], isFalse);
    expect(res5['statusCode'], 429);
    expect(res5['code'], 'OTP_ATTEMPT_LIMIT_EXCEEDED');

    // Even the valid OTP is rejected while locked out!
    final resLocked = await FirestoreRestClient.verifyOtpChallenge(
      identifier: bruteUser,
      code: validOtp,
      nowOverride: baseTime.add(const Duration(minutes: 2)),
    );
    expect(resLocked['success'], isFalse);
    expect(resLocked['code'], 'OTP_ATTEMPT_LIMIT_EXCEEDED');
  });
}
