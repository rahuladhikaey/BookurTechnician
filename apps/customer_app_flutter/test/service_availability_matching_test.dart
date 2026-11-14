import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:customer_app_flutter/services/firestore_rest_client.dart';

void main() {
  group('Customer App Strict Service-Specific Online Technician Matching', () {
    final Map<String, Map<String, dynamic>> fakeDb = {};

    setUp(() {
      fakeDb.clear();
      FirestoreRestClient.mockHttpHandler = (
        String method,
        Uri uri, {
        Map<String, String>? headers,
        Object? body,
      }) async {
        final path = uri.path;
        final docsMarker = '/documents/';
        final idx = path.indexOf(docsMarker);
        if (idx == -1) return http.Response('{}', 404);

        final rel = path.substring(idx + docsMarker.length);
        final parts = rel.split('/');
        final collection = parts[0];

        if (method == 'GET' && parts.length == 1) {
          final docs = fakeDb.entries
              .where((e) => e.key.startsWith('$collection/'))
              .map((e) => e.value)
              .toList();
          return http.Response(jsonEncode({'documents': docs}), 200);
        }
        return http.Response('{}', 404);
      };

      final nowIso = DateTime.now().toUtc().toIso8601String();
      fakeDb['technician_profiles/tech_fan_only'] = {
        'name': 'projects/bookmytechnician-53d94/databases/(default)/documents/technician_profiles/tech_fan_only',
        'fields': {
          'id': {'stringValue': 'tech_fan_only'},
          'technicianId': {'stringValue': 'tech_fan_only'},
          'fullName': {'stringValue': 'Fan Specialist'},
          'isOnline': {'booleanValue': true},
          'availabilityStatus': {'stringValue': 'AVAILABLE'},
          'latitude': {'doubleValue': 22.5726},
          'longitude': {'doubleValue': 88.3639},
          'lastLocationUpdate': {'stringValue': nowIso},
          'skills': {
            'arrayValue': {
              'values': [
                {
                  'mapValue': {
                    'fields': {
                      'skillId': {'stringValue': 'fan_rep'},
                      'canonicalServiceId': {'stringValue': 'fan_rep'},
                      'name': {'stringValue': 'Fan Repair'},
                      'verificationStatus': {'stringValue': 'VERIFIED'},
                      'enabled': {'booleanValue': true},
                      'isActive': {'booleanValue': true},
                    }
                  }
                }
              ]
            }
          },
        },
      };
    });

    tearDown(() {
      FirestoreRestClient.mockHttpHandler = null;
    });

    test('online technician appears ONLY for owned canonical service, never for unowned or fake services', () async {
      // 1. Owned service -> must show 1 online technician
      final fanAvailRes = await FirestoreRestClient.handleRequest(
        'GET',
        '/catalog/availability?latitude=22.5726&longitude=88.3639&radiusKm=15&serviceId=fan_rep&forceRefresh=true',
      );
      expect(fanAvailRes.statusCode, 200);
      final fanData = jsonDecode(fanAvailRes.body) as Map<String, dynamic>;
      expect(fanData['availableTechnicianCount'], 1);

      // 2. Unowned service (AC Installation) -> must show 0, even if service_categories is empty
      final acAvailRes = await FirestoreRestClient.handleRequest(
        'GET',
        '/catalog/availability?latitude=22.5726&longitude=88.3639&radiusKm=15&serviceId=ac_installation&forceRefresh=true',
      );
      expect(acAvailRes.statusCode, 200);
      final acData = jsonDecode(acAvailRes.body) as Map<String, dynamic>;
      expect(acData['availableTechnicianCount'], 0);

      // 3. Fake/unknown service -> must show 0
      final fakeAvailRes = await FirestoreRestClient.handleRequest(
        'GET',
        '/catalog/availability?latitude=22.5726&longitude=88.3639&radiusKm=15&serviceId=fake_nonexistent_service&forceRefresh=true',
      );
      expect(fakeAvailRes.statusCode, 200);
      final fakeData = jsonDecode(fakeAvailRes.body) as Map<String, dynamic>;
      expect(fakeData['availableTechnicianCount'], 0);

      // 4. Nearby technicians roster filtered by serviceId
      final nearbyFanRes = await FirestoreRestClient.handleRequest(
        'GET',
        '/catalog/technicians/nearby?latitude=22.5726&longitude=88.3639&radiusKm=15&serviceId=fan_rep',
      );
      final nearbyFanData = jsonDecode(nearbyFanRes.body) as Map<String, dynamic>;
      expect((nearbyFanData['technicians'] as List).length, 1);

      final nearbyAcRes = await FirestoreRestClient.handleRequest(
        'GET',
        '/catalog/technicians/nearby?latitude=22.5726&longitude=88.3639&radiusKm=15&serviceId=ac_installation',
      );
      final nearbyAcData = jsonDecode(nearbyAcRes.body) as Map<String, dynamic>;
      expect((nearbyAcData['technicians'] as List).length, 0);
    });
  });
}

