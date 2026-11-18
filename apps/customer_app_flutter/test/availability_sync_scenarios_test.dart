import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:customer_app_flutter/booking_provider.dart';
import 'package:customer_app_flutter/services/firestore_rest_client.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Phase 5 & 6 — Customer App Availability Sync & Unified Eligibility', () {
    final Map<String, Map<String, dynamic>> fakeDb = {};

    setUp(() {
      fakeDb.clear();
      SharedPreferences.setMockInitialValues({});
      FirestoreRestClient.resetMetrics();
      FirestoreRestClient.clearMemoryCache();

      fakeDb['service_categories/cat_ac'] = {
        'name': 'projects/bookmytechnician-53d94/databases/(default)/documents/service_categories/cat_ac',
        'fields': {
          'id': {'stringValue': 'cat_ac'},
          'name': {'stringValue': 'AC Services'},
          'subcategories': {
            'arrayValue': {
              'values': [
                {
                  'mapValue': {
                    'fields': {
                      'id': {'stringValue': 'sub_ac'},
                      'services': {
                        'arrayValue': {
                          'values': [
                            {
                              'mapValue': {
                                'fields': {
                                  'id': {'stringValue': 'ac_install'},
                                  'name': {'stringValue': 'AC installation'},
                                }
                              }
                            },
                            {
                              'mapValue': {
                                'fields': {
                                  'id': {'stringValue': 'light_rep'},
                                  'name': {'stringValue': 'Light Repair'},
                                }
                              }
                            },
                          ]
                        }
                      }
                    }
                  }
                }
              ]
            }
          }
        }
      };

      FirestoreRestClient.mockHttpHandler = (
        String method,
        Uri uri, {
        Map<String, String>? headers,
        String? body,
      }) async {
        final marker = '/documents/';
        final idx = uri.path.indexOf(marker);
        if (idx == -1) return http.Response('{}', 404);
        final col = uri.path.substring(idx + marker.length).split('/').first;
        final docs = fakeDb.entries
            .where((e) => e.key.startsWith('$col/'))
            .map((e) => e.value)
            .toList();
        return http.Response(jsonEncode({'documents': docs}), 200);
      };
    });

    tearDown(() {
      FirestoreRestClient.mockHttpHandler = null;
      FirestoreRestClient.clearMemoryCache();
    });

    Map<String, dynamic> makeTech({
      required String id,
      String accountStatus = 'ACTIVE',
      String kycStatus = 'VERIFIED',
      bool isOnline = true,
      String availabilityStatus = 'AVAILABLE',
      double lat = 23.2440,
      double lng = 88.5550,
      String? lastLocIso,
      String skillId = 'ac_install',
      String skillVer = 'VERIFIED',
      bool skillEnabled = true,
      String? activeBookingId,
    }) {
      return {
        'name': 'projects/bookmytechnician-53d94/databases/(default)/documents/technician_profiles/$id',
        'fields': {
          'id': {'stringValue': id},
          'uid': {'stringValue': id},
          'accountStatus': {'stringValue': accountStatus},
          'kycStatus': {'stringValue': kycStatus},
          'isOnline': {'booleanValue': isOnline},
          'availabilityStatus': {'stringValue': availabilityStatus},
          if (activeBookingId != null) 'activeBookingId': {'stringValue': activeBookingId},
          'latitude': {'doubleValue': lat},
          'longitude': {'doubleValue': lng},
          'lastLocationUpdate': {'stringValue': lastLocIso ?? DateTime.now().toUtc().toIso8601String()},
          'skills': {
            'arrayValue': {
              'values': [
                {
                  'mapValue': {
                    'fields': {
                      'id': {'stringValue': skillId},
                      'canonicalServiceId': {'stringValue': skillId},
                      'verificationStatus': {'stringValue': skillVer},
                      'enabled': {'booleanValue': skillEnabled},
                    }
                  }
                }
              ]
            }
          },
        }
      };
    }

    test('Rejects PENDING account/KYC even if isOnline==true, and propagates live toggles via forceRefresh', () async {
      fakeDb['technician_profiles/tech_unapproved'] = makeTech(
        id: 'tech_unapproved',
        accountStatus: 'PENDING_VERIFICATION',
        kycStatus: 'PENDING',
        isOnline: true,
      );
      fakeDb['technician_profiles/tech_valid'] = makeTech(
        id: 'tech_valid',
        isOnline: false,
        availabilityStatus: 'OFFLINE',
      );

      final notifier = BookingNotifier();
      await notifier.fetchSingleServiceAvailability('ac_install', lat: 23.2420, lng: 88.5530, forceRefresh: true);
      expect(notifier.state.getServiceAvailabilityCount('ac_install'), 0);
      expect(
        notifier.state.getServiceAvailabilityText('ac_install'),
        'No technicians currently available for this service in your area.',
      );

      // Now valid technician comes online -> Customer App forceRefresh sees 1 immediately (even within 15s/30s cache window!)
      fakeDb['technician_profiles/tech_valid'] = makeTech(
        id: 'tech_valid',
        isOnline: true,
        availabilityStatus: 'AVAILABLE',
      );
      await notifier.fetchSingleServiceAvailability('ac_install', lat: 23.2420, lng: 88.5530, forceRefresh: true);
      expect(notifier.state.getServiceAvailabilityCount('ac_install'), 1);

      // Technician out of 15km coverage must NOT show as available (zero global fallback!)
      fakeDb['technician_profiles/tech_valid'] = makeTech(
        id: 'tech_valid',
        lat: 22.5726,
        lng: 88.3639,
      );
      await notifier.fetchSingleServiceAvailability('ac_install', lat: 23.2420, lng: 88.5530, forceRefresh: true);
      expect(notifier.state.getServiceAvailabilityCount('ac_install'), 0);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      notifier.dispose();
    });
  });
}
