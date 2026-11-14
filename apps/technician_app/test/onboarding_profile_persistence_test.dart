import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:technician_app/core/network/firestore_rest_client.dart';
import 'package:technician_app/core/security/secure_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Technician Onboarding, Auth Header & Profile Persistence', () {
    final Map<String, Map<String, dynamic>> fakeDb = {};
    final List<Map<String, String>> capturedAuthHeaders = [];
    final Map<String, String> secureStore = {};

    setUp(() {
      fakeDb.clear();
      capturedAuthHeaders.clear();
      secureStore.clear();
      FirestoreRestClient.clearMemoryCache();
      FirestoreRestClient.clearOtpChallengesForTest();
      SharedPreferences.setMockInitialValues({});

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
        (MethodCall call) async {
          final args = (call.arguments as Map?) ?? {};
          final key = args['key']?.toString();
          if (call.method == 'write' && key != null) {
            secureStore[key] = args['value']?.toString() ?? '';
            return null;
          }
          if (call.method == 'read' && key != null) {
            return secureStore[key];
          }
          if (call.method == 'delete' && key != null) {
            secureStore.remove(key);
            return null;
          }
          if (call.method == 'deleteAll') {
            secureStore.clear();
            return null;
          }
          return null;
        },
      );

      FirestoreRestClient.mockHttpHandler = (
        String method,
        Uri uri, {
        Map<String, String>? headers,
        Object? body,
      }) async {
        if (headers != null && headers.containsKey('Authorization')) {
          capturedAuthHeaders.add({
            'method': method,
            'uri': uri.toString(),
            'auth': headers['Authorization']!,
          });
        }

        final path = uri.path;
        final docsMarker = '/documents/';
        final idx = path.indexOf(docsMarker);
        if (idx == -1) {
          return http.Response('{"error":"not found"}', 404);
        }
        final rel = path.substring(idx + docsMarker.length);
        final parts = rel.split('/');
        final collection = parts[0];
        final docId = parts.length > 1 ? parts[1] : null;

        if (method == 'GET' && docId == null) {
          final docs = fakeDb.entries
              .where((e) => e.key.startsWith('$collection/'))
              .map((e) => e.value)
              .toList();
          return http.Response(jsonEncode({'documents': docs}), 200);
        }

        if (method == 'GET' && docId != null) {
          final key = '$collection/$docId';
          if (!fakeDb.containsKey(key)) {
            return http.Response('{"error":"NOT_FOUND"}', 404);
          }
          return http.Response(jsonEncode(fakeDb[key]), 200);
        }

        if ((method == 'PATCH' || method == 'POST') && docId != null) {
          final key = '$collection/$docId';
          final decoded = jsonDecode(body as String) as Map<String, dynamic>;
          final newFields =
              Map<String, dynamic>.from(decoded['fields'] as Map? ?? {});
          final existing = fakeDb[key] != null
              ? Map<String, dynamic>.from(
                  (fakeDb[key]!['fields'] as Map?) ?? {})
              : <String, dynamic>{};
          existing.addAll(newFields);
          fakeDb[key] = {
            'name':
                'projects/bookmytechnician-53d94/databases/(default)/documents/$key',
            'fields': existing,
          };
          return http.Response(jsonEncode(fakeDb[key]), 200);
        }

        return http.Response('{}', 200);
      };
    });

    tearDown(() {
      FirestoreRestClient.mockHttpHandler = null;
      FirestoreRestClient.clearMemoryCache();
    });

    test('synthetic session tokens are never sent as Bearer headers to Firestore',
        () async {
      await SecureStorage().saveToken('fb_tech_tok_1794400000000');

      await FirestoreRestClient.upsertDocument('technician_profiles', 'tech_test_1', {
        'fullName': 'Test Tech',
      });
      await FirestoreRestClient.getDocument('technician_profiles', 'tech_test_1');

      expect(capturedAuthHeaders, isEmpty);
    });

    test('UPI ID saved via PUT /technicians/profile is returned by GET /technicians/profile',
        () async {
      await SecureStorage().saveUserId('tech_9876543210');

      final putRes = await FirestoreRestClient.handleDioRequest(
        RequestOptions(
          path: '/technicians/profile',
          method: 'PUT',
          headers: {'x-technician-id': 'tech_9876543210'},
          data: {
            'uid': 'tech_9876543210',
            'fullName': 'Ramesh Kumar',
            'upiId': 'ramesh@okaxis',
            'latitude': 22.5801,
            'longitude': 88.4102,
          },
        ),
      );
      expect(putRes.statusCode, 200);

      FirestoreRestClient.clearMemoryCache();

      final getRes = await FirestoreRestClient.handleDioRequest(
        RequestOptions(
          path: '/technicians/profile',
          method: 'GET',
          headers: {'x-technician-id': 'tech_9876543210'},
        ),
      );

      expect(getRes.statusCode, 200);
      final profile = getRes.data['data'] as Map<String, dynamic>;
      expect(profile['fullName'], 'Ramesh Kumar');
      expect(profile['upiId'], 'ramesh@okaxis');
      expect(profile['maskedUpiId'], 'ra***@okaxis');
      expect(profile['latitude'], 22.5801);
      expect(profile['longitude'], 88.4102);
    });
  });
}
