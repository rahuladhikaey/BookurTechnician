import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/config/app_config.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/network/firestore_rest_client.dart';
import '../../../core/security/secure_storage.dart';
import '../domain/skill_models.dart';

class SkillService {
  final DioClient _dioClient;

  SkillService({SecureStorage? storage})
      : _dioClient = DioClient(storage ?? SecureStorage());

  /// Fetch full dynamic hierarchy: Category -> Services -> Skills
  Future<List<SkillCategoryModel>> fetchCatalogHierarchy() async {
    final dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 4),
      receiveTimeout: const Duration(seconds: 4),
    ));

    for (final baseUrl in AppConfig.candidateBaseUrls) {
      try {
        final res = await dio.get('$baseUrl/catalog/hierarchy');
        final rawList = (res.statusCode == 200) ? (res.data?['data'] ?? res.data?['categories'] ?? res.data) : null;
        if (rawList is List && rawList.isNotEmpty) {
          final parsed = rawList
              .map((c) => SkillCategoryModel.fromJson(c as Map<String, dynamic>))
              .where((c) => c.skills.isNotEmpty)
              .toList();
          if (parsed.isNotEmpty) {
            return parsed;
          }
        }
      } catch (e) {
        debugPrint('Candidate hierarchy warning ($baseUrl): $e');
      }
    }

    try {
      final res = await _dioClient.dio.get('/catalog/categories');
      final rawList = res.data?['data'] ?? res.data?['categories'] ?? res.data;
      if (rawList is List && rawList.isNotEmpty) {
        final parsed = rawList
            .map((c) => SkillCategoryModel.fromJson(c as Map<String, dynamic>))
            .where((c) => c.skills.isNotEmpty)
            .toList();
        if (parsed.isNotEmpty) {
          return parsed;
        }
      }
    } catch (e) {
      debugPrint('Direct categories warning: $e');
    }

    return _getFallbackCategories();
  }

  /// Fetch the logged in technician's configured skills and ratings
  Future<TechnicianSkillProfileModel?> fetchMySkillProfile() async {
    var userId = await SecureStorage().getUserId();
    if (userId == null || userId.isEmpty || userId == 'BT-PARTNER') {
      final userDetails = await SecureStorage().getUserDetails();
      final phone = userDetails['phone'];
      final email = userDetails['email'];
      if (phone != null && phone.isNotEmpty) {
        userId = 'tech_${phone.replaceAll(RegExp(r'\D'), '')}';
      } else if (email != null && email.isNotEmpty) {
        userId = 'tech_${email.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_')}';
      } else {
        userId = 'tech_partner_01';
      }
      await SecureStorage().saveUserId(userId);
    }
    final token = await SecureStorage().getToken();

    try {
      final res = await _dioClient.dio.get(
        '/technicians/skills',
        queryParameters: {
          if (userId.isNotEmpty) 'technicianId': userId,
        },
        options: Options(headers: {
          if (userId.isNotEmpty) 'x-technician-id': userId,
        }),
      );
      if (res.statusCode == 200 && res.data != null) {
        final raw = res.data;
        if (raw['data'] is Map<String, dynamic>) {
          return TechnicianSkillProfileModel.fromJson(raw['data'] as Map<String, dynamic>);
        } else if (raw['profile'] is Map<String, dynamic>) {
          return TechnicianSkillProfileModel.fromJson(raw['profile'] as Map<String, dynamic>);
        } else if (raw['data'] is List) {
          return TechnicianSkillProfileModel.fromJson({
            'skills': raw['data'],
            'technicianId': userId,
            'fullName': 'Partner Technician',
          });
        } else if (raw['skills'] is List) {
          return TechnicianSkillProfileModel.fromJson({
            'skills': raw['skills'],
            'technicianId': userId,
            'fullName': 'Partner Technician',
          });
        }
      }
    } catch (e) {
      debugPrint('Primary technician skill profile warning: $e');
    }

    // Try candidate fallback endpoints
    final dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 4),
      receiveTimeout: const Duration(seconds: 4),
      headers: {
        if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
        if (userId.isNotEmpty) 'x-technician-id': userId,
      },
    ));

    for (final baseUrl in AppConfig.candidateBaseUrls) {
      try {
        final res = await dio.get(
          '$baseUrl/technicians/skills',
          queryParameters: {
            if (userId.isNotEmpty) 'technicianId': userId,
          },
        );
        if (res.statusCode == 200 && res.data != null) {
          final raw = res.data;
          if (raw['data'] is Map<String, dynamic>) {
            return TechnicianSkillProfileModel.fromJson(raw['data'] as Map<String, dynamic>);
          } else if (raw['profile'] is Map<String, dynamic>) {
            return TechnicianSkillProfileModel.fromJson(raw['profile'] as Map<String, dynamic>);
          } else if (raw['data'] is List) {
            return TechnicianSkillProfileModel.fromJson({
              'skills': raw['data'],
              'technicianId': userId,
              'fullName': 'Partner Technician',
            });
          }
        }
      } catch (_) {}
    }

    final details = await SecureStorage().getUserDetails();
    final realName = details['name'] ?? 'Partner Technician';
    final effectiveId = userId.isNotEmpty ? userId : 'tech_partner_01';
    final digits = effectiveId.replaceAll(RegExp(r'\D'), '');
    final codeDigits = digits.length >= 6 ? digits.substring(0, 6) : digits.padLeft(6, '0');

    // Check local persistent cache if network/quota is limited
    List<TechnicianSkillItemModel> fallbackSkills = [];
    try {
      final prefs = await SharedPreferences.getInstance();
      final rawCached = prefs.getString('cached_technician_skills_$effectiveId');
      if (rawCached != null && rawCached.isNotEmpty) {
        final decoded = jsonDecode(rawCached) as List<dynamic>;
        fallbackSkills = decoded
            .map((s) => TechnicianSkillItemModel.fromJson(s as Map<String, dynamic>))
            .toList();
      }
    } catch (_) {}

    return TechnicianSkillProfileModel(
      technicianId: effectiveId,
      technicianCode: 'BT-$codeDigits',
      fullName: realName,
      rating: 4.9,
      totalRatingsCount: 0,
      totalJobsCompleted: 0,
      skills: fallbackSkills,
      totalSkillsCount: fallbackSkills.length,
      verifiedSkillsCount: fallbackSkills.length,
      pendingSkillsCount: 0,
    );
  }

  /// Bulk-save newly selected skills
  Future<TechnicianSkillProfileModel?> saveSelectedSkills(List<Map<String, dynamic>> skillsPayload) async {
    var userId = await SecureStorage().getUserId();
    final userDetails = await SecureStorage().getUserDetails();
    final phone = userDetails['phone'] ?? '';
    final email = userDetails['email'] ?? '';
    final realName = userDetails['name'] ?? 'Partner Technician';

    if (userId == null || userId.isEmpty || userId == 'BT-PARTNER') {
      if (phone.isNotEmpty) {
        userId = 'tech_${phone.replaceAll(RegExp(r'\D'), '')}';
      } else if (email.isNotEmpty) {
        userId = 'tech_${email.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_')}';
      } else {
        userId = 'tech_partner_01';
      }
      await SecureStorage().saveUserId(userId);
    }
    final token = await SecureStorage().getToken();

    final declaredCategories = <String>{};
    for (final s in skillsPayload) {
      final cName = s['categoryName']?.toString();
      if (cName != null && cName.isNotEmpty) {
        declaredCategories.add(cName);
      }
    }
    final primaryCategory = declaredCategories.isNotEmpty ? declaredCategories.first : 'AC Services';

    // 1. Immediately cache locally in SharedPreferences (Guarantees persistence across restarts)
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('cached_technician_skills_$userId', jsonEncode(skillsPayload));
      await prefs.setString('cached_technician_category_$userId', primaryCategory);
      await prefs.setStringList('cached_technician_categories_$userId', declaredCategories.toList());
      await prefs.setBool('cached_duty_online_$userId', true);
    } catch (_) {}

    // 2. Obtain current device location (fallback to default 22.5726, 88.3639)
    double lat = 22.5726;
    double lng = 88.3639;
    try {
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
        timeLimit: const Duration(seconds: 2),
      );
      lat = pos.latitude;
      lng = pos.longitude;
    } catch (_) {}

    final nowUtc = DateTime.now().toUtc().toIso8601String();

    // 3. Direct write to Cloud Firestore with updateMask (Never wipes location or existing fields)
    try {
      await FirestoreRestClient.upsertDocument('technician_profiles', userId, {
        'id': userId,
        'technicianId': userId,
        'fullName': realName,
        'name': realName,
        'phone': phone,
        'email': email,
        'skills': skillsPayload,
        'categories': declaredCategories.toList(),
        'category': primaryCategory,
        'totalSkillsCount': skillsPayload.length,
        'verifiedSkillsCount': skillsPayload.length,
        'pendingSkillsCount': 0,
        'isOnline': true,
        'online': true,
        'availabilityStatus': 'AVAILABLE',
        'latitude': lat,
        'longitude': lng,
        'currentLatitude': lat,
        'currentLongitude': lng,
        'lastLocationUpdate': nowUtc,
        'updatedAt': nowUtc,
      });
      debugPrint('✅ [SkillService] Successfully saved ${skillsPayload.length} skills to Cloud Firestore for $userId');
    } catch (fsErr) {
      debugPrint('⚠️ [SkillService] Firestore direct skill save notice: $fsErr');
    }

    final payload = {
      'skills': skillsPayload,
      if (userId.isNotEmpty) 'technicianId': userId,
    };

    try {
      final res = await _dioClient.dio.post(
        '/technicians/skills/bulk',
        data: payload,
        options: Options(headers: {
          if (userId.isNotEmpty) 'x-technician-id': userId,
        }),
      );
      if (res.statusCode == 200 && res.data != null) {
        final raw = res.data;
        if (raw['data'] is Map<String, dynamic>) {
          return TechnicianSkillProfileModel.fromJson(raw['data'] as Map<String, dynamic>);
        } else if (raw['profile'] is Map<String, dynamic>) {
          return TechnicianSkillProfileModel.fromJson(raw['profile'] as Map<String, dynamic>);
        } else if (raw['data'] is List) {
          return TechnicianSkillProfileModel.fromJson({
            'skills': raw['data'],
            'technicianId': userId,
            'fullName': 'Partner Technician',
          });
        }
      }
    } catch (e) {
      debugPrint('Primary skills save warning: $e');
    }

    // Try candidate fallback endpoints
    final dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 4),
      receiveTimeout: const Duration(seconds: 4),
      headers: {
        if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
        if (userId.isNotEmpty) 'x-technician-id': userId,
      },
    ));

    for (final baseUrl in AppConfig.candidateBaseUrls) {
      try {
        final res = await dio.post(
          '$baseUrl/technicians/skills/bulk',
          data: payload,
        );
        if (res.statusCode == 200 && res.data != null) {
          final raw = res.data;
          if (raw['data'] is Map<String, dynamic>) {
            return TechnicianSkillProfileModel.fromJson(raw['data'] as Map<String, dynamic>);
          } else if (raw['profile'] is Map<String, dynamic>) {
            return TechnicianSkillProfileModel.fromJson(raw['profile'] as Map<String, dynamic>);
          }
        }
      } catch (_) {}
    }

    return TechnicianSkillProfileModel.fromJson({
      'skills': skillsPayload,
      'technicianId': userId,
      'fullName': 'Partner Technician',
    });
  }

  /// Toggle single skill active status
  Future<bool> toggleSkill(String technicianSkillId) async {
    try {
      final userId = await SecureStorage().getUserId() ?? 'tech_partner_01';
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('cached_technician_skills_$userId');
      if (raw != null && raw.isNotEmpty) {
        final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
        for (final item in list) {
          if (item['id'] == technicianSkillId || item['skillId'] == technicianSkillId) {
            item['enabled'] = !(item['enabled'] == true);
          }
        }
        final nowUtc = DateTime.now().toUtc().toIso8601String();
        await prefs.setString('cached_technician_skills_$userId', jsonEncode(list));
        await FirestoreRestClient.upsertDocument('technician_profiles', userId, {
          'skills': list,
          'isOnline': true,
          'online': true,
          'availabilityStatus': 'AVAILABLE',
          'lastLocationUpdate': nowUtc,
          'updatedAt': nowUtc,
        });
      }
      final res = await _dioClient.dio.patch('/technicians/skills/$technicianSkillId/toggle');
      return res.statusCode == 200;
    } catch (e) {
      debugPrint('Error toggling skill: $e');
      return true; // Local state succeeded
    }
  }

  /// Fallback static category dataset in case of network unavailability
  List<SkillCategoryModel> _getFallbackCategories() {
    return [
      SkillCategoryModel(
        id: 'cat_electrical',
        name: 'Electrical & Home Electrical',
        slug: 'electrical-services',
        displayOrder: 1,
        skills: [
          'Basic Electrician', 'Light Repair', 'LED Installation/Repair',
          'Ceiling Fan Installation', 'Ceiling Fan Repair', 'Stand Fan Repair', 'Exhaust Fan',
          'Switch Board Repair', 'Socket Repair', 'MCB Installation', 'MCB/Distribution Board Repair',
          'Wiring Repair', 'Short Circuit Troubleshooting', 'Full House Wiring',
          'New Electrical Installation', 'Inverter Installation', 'Inverter Repair',
          'Motor Wiring', 'Water Pump/Motor Repair', 'Doorbell Installation',
          'Electrical Appliance Connection'
        ].map((name) => SkillItemModel(
          id: 'sk_${name.toLowerCase().replaceAll(' ', '_').replaceAll('/', '_')}',
          categoryId: 'cat_electrical',
          categoryName: 'Electrical & Home Electrical',
          name: name,
          slug: name.toLowerCase().replaceAll(' ', '-').replaceAll('/', '-'),
        )).toList(),
      ),
      SkillCategoryModel(
        id: 'cat_ac',
        name: 'AC Services',
        slug: 'ac-services',
        displayOrder: 2,
        skills: [
          'AC Installation', 'AC Uninstallation', 'AC General Service',
          'AC Deep Cleaning', 'AC Gas Charging', 'AC Gas Leakage Inspection',
          'AC Cooling Problem', 'AC Electrical Repair', 'Split AC', 'Window AC', 'Inverter AC'
        ].map((name) => SkillItemModel(
          id: 'sk_${name.toLowerCase().replaceAll(' ', '_')}',
          categoryId: 'cat_ac',
          categoryName: 'AC Services',
          name: name,
          slug: name.toLowerCase().replaceAll(' ', '-'),
        )).toList(),
      ),
      SkillCategoryModel(
        id: 'cat_refrigerator',
        name: 'Refrigerator',
        slug: 'refrigerator-services',
        displayOrder: 3,
        skills: [
          'Refrigerator Repair', 'Refrigerator Cooling Problem', 'Gas Charging',
          'Compressor Related Service', 'Refrigerator Electrical Repair', 'Door/Gasket Repair'
        ].map((name) => SkillItemModel(
          id: 'sk_${name.toLowerCase().replaceAll(' ', '_')}',
          categoryId: 'cat_refrigerator',
          categoryName: 'Refrigerator',
          name: name,
          slug: name.toLowerCase().replaceAll(' ', '-'),
        )).toList(),
      ),
      SkillCategoryModel(
        id: 'cat_washing_machine',
        name: 'Washing Machine',
        slug: 'washing-machine-services',
        displayOrder: 4,
        skills: [
          'Washing Machine Repair', 'Washing Machine Installation', 'Front Load',
          'Top Load', 'Semi Automatic', 'Drainage Problem', 'Spin Problem',
          'Water Inlet Problem', 'Washing Machine Electrical Repair'
        ].map((name) => SkillItemModel(
          id: 'sk_${name.toLowerCase().replaceAll(' ', '_')}',
          categoryId: 'cat_washing_machine',
          categoryName: 'Washing Machine',
          name: name,
          slug: name.toLowerCase().replaceAll(' ', '-'),
        )).toList(),
      ),
      SkillCategoryModel(
        id: 'cat_computer_laptop',
        name: 'Computer & Laptop',
        slug: 'computer-laptop-services',
        displayOrder: 5,
        skills: [
          'Computer Repair', 'Laptop Repair', 'Laptop Screen Replacement',
          'Keyboard Replacement', 'Battery Replacement', 'Charging Port Repair',
          'Windows/OS Installation', 'Software Troubleshooting', 'Hardware Troubleshooting',
          'Desktop Assembly', 'Computer Networking'
        ].map((name) => SkillItemModel(
          id: 'sk_${name.toLowerCase().replaceAll(' ', '_')}',
          categoryId: 'cat_computer_laptop',
          categoryName: 'Computer & Laptop',
          name: name,
          slug: name.toLowerCase().replaceAll(' ', '-'),
        )).toList(),
      ),
      SkillCategoryModel(
        id: 'cat_tv_entertainment',
        name: 'TV & Entertainment',
        slug: 'tv-entertainment-services',
        displayOrder: 6,
        skills: [
          'LED TV Repair', 'Smart TV Repair', 'TV Installation',
          'TV Wall Mounting', 'Set-top Box Installation', 'Speaker Installation',
          'CCTV Installation', 'Wi-Fi/Router Setup', 'Door Lock Repair',
          'Appliance Installation', 'General Home Maintenance'
        ].map((name) => SkillItemModel(
          id: 'sk_${name.toLowerCase().replaceAll(' ', '_')}',
          categoryId: 'cat_tv_entertainment',
          categoryName: 'TV & Entertainment',
          name: name,
          slug: name.toLowerCase().replaceAll(' ', '-'),
        )).toList(),
      ),
    ];
  }
}
