import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
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
    'updateTime': updateTime ?? '2026-11-11T12:00:00.000000Z',
  };
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Map<String, Map<String, dynamic>> mockTechProfiles;
  late Map<String, Map<String, dynamic>> mockBookings;
  late Map<String, Map<String, dynamic>> mockOffers;

  setUp(() {
    FirestoreRestClient.resetMetrics();
    FirestoreRestClient.clearMemoryCache();
    FirestoreRestClient.clearOtpChallengesForTest();

    mockTechProfiles = {};
    mockBookings = {};
    mockOffers = {};

    FirestoreRestClient.mockHttpHandler = (
      String method,
      Uri uri, {
      Map<String, String>? headers,
      String? body,
    }) async {
      final url = uri.toString();
      final nowUtc = DateTime.now().toUtc().toIso8601String();

      // List technician profiles
      if (method == 'GET' && url.contains('/documents/technician_profiles')) {
        final docs = mockTechProfiles.entries.map((e) => _toFirestoreDoc('technician_profiles', e.key, e.value)).toList();
        return http.Response(jsonEncode({'documents': docs}), 200, headers: {'content-type': 'application/json'});
      }

      // Read single booking
      if (method == 'GET' && url.contains('/documents/bookings/')) {
        final id = url.split('/documents/bookings/').last.split('?').first;
        if (mockBookings.containsKey(id)) {
          return http.Response(jsonEncode(_toFirestoreDoc('bookings', id, mockBookings[id]!)), 200, headers: {'content-type': 'application/json'});
        }
        return http.Response(jsonEncode({'error': {'code': 404, 'message': 'Not found'}}), 404, headers: {'content-type': 'application/json'});
      }

      // Write booking / offer
      if (method == 'POST' && url.contains(':commit')) {
        final b = jsonDecode(body.toString()) as Map<String, dynamic>;
        final writes = b['writes'] as List<dynamic>? ?? [];
        for (final w in writes) {
          final u = w['update'] as Map<String, dynamic>?;
          if (u != null) {
            final name = u['name'] as String;
            if (name.contains('/technician_profiles/')) {
              final id = name.split('/technician_profiles/').last;
              mockTechProfiles[id] = (mockTechProfiles[id] ?? {})..['updatedAt'] = nowUtc;
            } else if (name.contains('/bookings/')) {
              final id = name.split('/bookings/').last;
              mockBookings[id] = {'id': id, 'createdAt': nowUtc};
            } else if (name.contains('/dispatch_offers/')) {
              final id = name.split('/dispatch_offers/').last;
              mockOffers[id] = {'id': id, 'createdAt': nowUtc};
            }
          }
        }
        return http.Response(jsonEncode({
          'commitTime': nowUtc,
          'writeResults': List.filled(writes.length, {'updateTime': nowUtc}),
        }), 200, headers: {'content-type': 'application/json'});
      }

      return http.Response(jsonEncode({'documents': []}), 200, headers: {'content-type': 'application/json'});
    };
  });

  tearDown(() {
    FirestoreRestClient.mockHttpHandler = null;
  });

  group('Technician Skill Eligibility & Dispatch Matching Tests', () {
    test('Scenario 1: Electrical-only technician MUST be REJECTED for AC Installation', () async {
      final nowStr = DateTime.now().toUtc().toIso8601String();
      mockTechProfiles['tech_kakali'] = {
        'id': 'tech_kakali',
        'name': 'Kakali Goswami',
        'technicianCode': 'BT-637055',
        'isOnline': true,
        'availabilityStatus': 'AVAILABLE',
        'latitude': 23.2219,
        'longitude': 88.5672,
        'lastLocationUpdate': nowStr,
        'category': 'Electrical & Home Electrical',
        'categories': ['Electrical & Home Electrical'],
        'skills': [
          {
            'id': 'sk_light_repair',
            'name': 'Light Repair',
            'verificationStatus': 'VERIFIED',
            'enabled': true,
          },
          {
            'id': 'sk_ceiling_fan_installation',
            'name': 'Ceiling Fan Installation',
            'verificationStatus': 'VERIFIED',
            'enabled': true,
          },
        ],
      };

      final res = await FirestoreRestClient.handleRequest('POST', '/bookings', {
        'customerId': 'cust_123',
        'customerName': 'Rahul Adhikary',
        'customerPhone': '+91 9883637055',
        'serviceId': 'ac_install',
        'serviceName': 'AC installation',
        'latitude': 23.2219,
        'longitude': 88.5672,
        'address': 'Birnagar',
      });

      final json = jsonDecode(res.body);
      expect(res.statusCode, equals(409));
      expect(json['success'], isFalse);
      expect(json['code'], equals('SKILL_MISMATCH'));
      expect(mockBookings, isEmpty);
      expect(mockOffers, isEmpty);
    });

    test('Scenario 2: Electrical-only technician MUST be ALLOWED for Light Repair', () async {
      final nowStr = DateTime.now().toUtc().toIso8601String();
      mockTechProfiles['tech_kakali'] = {
        'id': 'tech_kakali',
        'name': 'Kakali Goswami',
        'technicianCode': 'BT-637055',
        'isOnline': true,
        'availabilityStatus': 'AVAILABLE',
        'latitude': 23.2219,
        'longitude': 88.5672,
        'lastLocationUpdate': nowStr,
        'category': 'Electrical & Home Electrical',
        'categories': ['Electrical & Home Electrical'],
        'skills': [
          {
            'id': 'sk_light_repair',
            'name': 'Light Repair',
            'verificationStatus': 'VERIFIED',
            'enabled': true,
          },
        ],
      };

      final res = await FirestoreRestClient.handleRequest('POST', '/bookings', {
        'customerId': 'cust_123',
        'customerName': 'Rahul Adhikary',
        'customerPhone': '+91 9883637055',
        'serviceId': 'light_rep',
        'serviceName': 'Light repair',
        'latitude': 23.2219,
        'longitude': 88.5672,
        'address': 'Birnagar',
      });

      final json = jsonDecode(res.body);
      expect(res.statusCode, equals(201));
      expect(json['success'], isTrue);
      expect(json['data']['technicianId'], equals('tech_kakali'));
    });

    test('Scenario 3: AC technician with verified and active skill MUST be ALLOWED for AC Installation', () async {
      final nowStr = DateTime.now().toUtc().toIso8601String();
      mockTechProfiles['tech_ram'] = {
        'id': 'tech_ram',
        'name': 'Ram Sharma',
        'technicianCode': 'BT-988363',
        'isOnline': true,
        'availabilityStatus': 'AVAILABLE',
        'latitude': 23.2219,
        'longitude': 88.5672,
        'lastLocationUpdate': nowStr,
        'category': 'AC Services',
        'skills': [
          {
            'id': 'ac_install',
            'name': 'AC installation',
            'verificationStatus': 'VERIFIED',
            'enabled': true,
          },
        ],
      };

      final res = await FirestoreRestClient.handleRequest('POST', '/bookings', {
        'customerId': 'cust_123',
        'customerName': 'Rahul Adhikary',
        'customerPhone': '+91 9883637055',
        'serviceId': 'ac_install',
        'serviceName': 'AC installation',
        'latitude': 23.2219,
        'longitude': 88.5672,
        'address': 'Birnagar',
      });

      final json = jsonDecode(res.body);
      expect(res.statusCode, equals(201));
      expect(json['success'], isTrue);
      expect(json['data']['technicianId'], equals('tech_ram'));
    });

    test('Scenario 4: AC technician with PENDING verification MUST be REJECTED', () async {
      final nowStr = DateTime.now().toUtc().toIso8601String();
      mockTechProfiles['tech_pending'] = {
        'id': 'tech_pending',
        'name': 'Pending Tech',
        'isOnline': true,
        'availabilityStatus': 'AVAILABLE',
        'latitude': 23.2219,
        'longitude': 88.5672,
        'lastLocationUpdate': nowStr,
        'category': 'AC Services',
        'skills': [
          {
            'id': 'ac_install',
            'name': 'AC installation',
            'verificationStatus': 'PENDING',
            'enabled': true,
          },
        ],
      };

      final res = await FirestoreRestClient.handleRequest('POST', '/bookings', {
        'customerId': 'cust_123',
        'serviceId': 'ac_install',
        'serviceName': 'AC installation',
        'latitude': 23.2219,
        'longitude': 88.5672,
      });

      final json = jsonDecode(res.body);
      expect(res.statusCode, equals(409));
      expect(json['code'], equals('SKILL_MISMATCH'));
    });

    test('Scenario 5: AC technician with REJECTED verification MUST be REJECTED', () async {
      final nowStr = DateTime.now().toUtc().toIso8601String();
      mockTechProfiles['tech_rejected'] = {
        'id': 'tech_rejected',
        'name': 'Rejected Tech',
        'isOnline': true,
        'availabilityStatus': 'AVAILABLE',
        'latitude': 23.2219,
        'longitude': 88.5672,
        'lastLocationUpdate': nowStr,
        'category': 'AC Services',
        'skills': [
          {
            'id': 'ac_install',
            'name': 'AC installation',
            'verificationStatus': 'REJECTED',
            'enabled': true,
          },
        ],
      };

      final res = await FirestoreRestClient.handleRequest('POST', '/bookings', {
        'customerId': 'cust_123',
        'serviceId': 'ac_install',
        'serviceName': 'AC installation',
        'latitude': 23.2219,
        'longitude': 88.5672,
      });

      final json = jsonDecode(res.body);
      expect(res.statusCode, equals(409));
      expect(json['code'], equals('SKILL_MISMATCH'));
    });

    test('Scenario 6: AC technician with enabled=false (toggled off) MUST be REJECTED', () async {
      final nowStr = DateTime.now().toUtc().toIso8601String();
      mockTechProfiles['tech_disabled'] = {
        'id': 'tech_disabled',
        'name': 'Disabled Tech',
        'isOnline': true,
        'availabilityStatus': 'AVAILABLE',
        'latitude': 23.2219,
        'longitude': 88.5672,
        'lastLocationUpdate': nowStr,
        'category': 'AC Services',
        'skills': [
          {
            'id': 'ac_install',
            'name': 'AC installation',
            'verificationStatus': 'VERIFIED',
            'enabled': false,
          },
        ],
      };

      final res = await FirestoreRestClient.handleRequest('POST', '/bookings', {
        'customerId': 'cust_123',
        'serviceId': 'ac_install',
        'serviceName': 'AC installation',
        'latitude': 23.2219,
        'longitude': 88.5672,
      });

      final json = jsonDecode(res.body);
      expect(res.statusCode, equals(409));
      expect(json['code'], equals('SKILL_MISMATCH'));
    });

    test('Scenario 7: Category-only match alone MUST NEVER qualify a technician', () async {
      final nowStr = DateTime.now().toUtc().toIso8601String();
      mockTechProfiles['tech_category_only'] = {
        'id': 'tech_category_only',
        'name': 'Category Only Tech',
        'isOnline': true,
        'availabilityStatus': 'AVAILABLE',
        'latitude': 23.2219,
        'longitude': 88.5672,
        'lastLocationUpdate': nowStr,
        'category': 'AC Services',
        'categories': ['AC Services'],
        'skills': [], // Zero declared skills
      };

      final res = await FirestoreRestClient.handleRequest('POST', '/bookings', {
        'customerId': 'cust_123',
        'serviceId': 'ac_install',
        'serviceName': 'AC installation',
        'latitude': 23.2219,
        'longitude': 88.5672,
      });

      final json = jsonDecode(res.body);
      expect(res.statusCode, equals(409));
      expect(json['code'], equals('SKILL_MISMATCH'));
    });

    test('Scenario 8: Offline technician with verified skill MUST be REJECTED', () async {
      final nowStr = DateTime.now().toUtc().toIso8601String();
      mockTechProfiles['tech_offline'] = {
        'id': 'tech_offline',
        'name': 'Offline Tech',
        'isOnline': false,
        'availabilityStatus': 'AVAILABLE',
        'latitude': 23.2219,
        'longitude': 88.5672,
        'lastLocationUpdate': nowStr,
        'category': 'AC Services',
        'skills': [
          {
            'id': 'ac_install',
            'name': 'AC installation',
            'verificationStatus': 'VERIFIED',
            'enabled': true,
          },
        ],
      };

      final res = await FirestoreRestClient.handleRequest('POST', '/bookings', {
        'customerId': 'cust_123',
        'serviceId': 'ac_install',
        'serviceName': 'AC installation',
        'latitude': 23.2219,
        'longitude': 88.5672,
      });

      final json = jsonDecode(res.body);
      expect(res.statusCode, equals(409));
      expect(json['code'], equals('TECHNICIAN_WENT_OFFLINE'));
    });

    test('Scenario 9: Technician outside 15 km radius MUST be REJECTED', () async {
      final nowStr = DateTime.now().toUtc().toIso8601String();
      mockTechProfiles['tech_far'] = {
        'id': 'tech_far',
        'name': 'Far Tech',
        'isOnline': true,
        'availabilityStatus': 'AVAILABLE',
        'latitude': 23.5000, // ~31 km away
        'longitude': 88.5672,
        'lastLocationUpdate': nowStr,
        'category': 'AC Services',
        'skills': [
          {
            'id': 'ac_install',
            'name': 'AC installation',
            'verificationStatus': 'VERIFIED',
            'enabled': true,
          },
        ],
      };

      final res = await FirestoreRestClient.handleRequest('POST', '/bookings', {
        'customerId': 'cust_123',
        'serviceId': 'ac_install',
        'serviceName': 'AC installation',
        'latitude': 23.2219,
        'longitude': 88.5672,
      });

      final json = jsonDecode(res.body);
      expect(res.statusCode, equals(409));
      expect(json['code'], equals('OUT_OF_RADIUS'));
    });
  });
}
