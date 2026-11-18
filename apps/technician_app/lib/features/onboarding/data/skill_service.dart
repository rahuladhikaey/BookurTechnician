import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
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

    try {
      final cats = await FirestoreRestClient.listCollection('service_categories');
      if (cats.isNotEmpty) {
        final parsed = cats
            .map((c) => SkillCategoryModel.fromJson(c))
            .where((c) => c.skills.isNotEmpty)
            .toList();
        if (parsed.isNotEmpty) {
          return parsed;
        }
      }
    } catch (e) {
      debugPrint('Firestore catalog categories warning: $e');
    }

    return [];
  }

  /// Fetch the logged in technician's configured skills and ratings
  Future<TechnicianSkillProfileModel?> fetchMySkillProfile() async {
    final userDetails = await SecureStorage().getUserDetails();
    final phone = userDetails['phone'] ?? '';
    final email = userDetails['email'] ?? '';
    var rawUserId = await SecureStorage().getUserId();
    final userId = FirestoreRestClient.resolveCanonicalTechUid(
      (rawUserId != null && rawUserId.isNotEmpty && rawUserId != 'BT-PARTNER')
          ? rawUserId
          : (phone.isNotEmpty ? phone : email),
      phone: phone,
    );
    await SecureStorage().saveUserId(userId);

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
        TechnicianSkillProfileModel? candidate;
        if (raw['data'] is Map<String, dynamic>) {
          candidate = TechnicianSkillProfileModel.fromJson(raw['data'] as Map<String, dynamic>);
        } else if (raw['profile'] is Map<String, dynamic>) {
          candidate = TechnicianSkillProfileModel.fromJson(raw['profile'] as Map<String, dynamic>);
        } else if (raw['data'] is List) {
          candidate = TechnicianSkillProfileModel.fromJson({
            'skills': raw['data'],
            'technicianId': userId,
            'fullName': userDetails['name'] ?? 'Partner Technician',
          });
        } else if (raw['skills'] is List) {
          candidate = TechnicianSkillProfileModel.fromJson({
            'skills': raw['skills'],
            'technicianId': userId,
            'fullName': userDetails['name'] ?? 'Partner Technician',
          });
        }
        if (candidate != null && candidate.skills.isNotEmpty) {
          return candidate;
        }
      }
    } catch (e) {
      debugPrint('Primary technician skill profile warning: $e');
    }

    // Check Cloud Firestore directly if needed
    try {
      final doc = await FirestoreRestClient.getDocument('technician_profiles', userId);
      if (doc != null) {
        final docSkills = (doc['selectedSkills'] is List && (doc['selectedSkills'] as List).isNotEmpty)
            ? doc['selectedSkills'] as List
            : (doc['skills'] is List ? doc['skills'] as List : <dynamic>[]);
        if (docSkills.isNotEmpty) {
          return TechnicianSkillProfileModel.fromJson({
            'technicianId': userId,
            'technicianCode': doc['technicianCode'] ?? FirestoreRestClient.resolveTechnicianCode(userId, phone: phone),
            'fullName': doc['fullName'] ?? doc['name'] ?? userDetails['name'] ?? 'Partner Technician',
            'rating': (doc['rating'] as num?)?.toDouble() ?? 0.0,
            'totalRatingsCount': doc['totalRatingsCount'] ?? 0,
            'totalJobsCompleted': doc['totalJobsCompleted'] ?? 0,
            'skills': docSkills,
          });
        }
      }
    } catch (_) {}

    final realName = userDetails['name'] ?? 'Partner Technician';
    final partnerCode = FirestoreRestClient.resolveTechnicianCode(userId, phone: phone);

    // Check local persistent cache if network/quota is limited
    List<TechnicianSkillItemModel> fallbackSkills = [];
    try {
      final prefs = await SharedPreferences.getInstance();
      var rawCached = prefs.getString('cached_technician_skills_$userId');
      rawCached ??= prefs.getString('cached_technician_skills_global');
      rawCached ??= prefs.getString('cached_technician_skills_default');
      if (rawCached == null && phone.isNotEmpty) {
        rawCached = prefs.getString('cached_technician_skills_$phone');
      }
      if (rawCached != null && rawCached.isNotEmpty) {
        final decoded = jsonDecode(rawCached) as List<dynamic>;
        fallbackSkills = decoded
            .map((s) => TechnicianSkillItemModel.fromJson(s as Map<String, dynamic>))
            .toList();
      }
    } catch (_) {}

    return TechnicianSkillProfileModel(
      technicianId: userId,
      technicianCode: partnerCode,
      fullName: realName,
      rating: 0.0,
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
    final userDetails = await SecureStorage().getUserDetails();
    final phone = userDetails['phone'] ?? '';
    final email = userDetails['email'] ?? '';
    final realName = userDetails['name'] ?? 'Partner Technician';
    final rawUserId = await SecureStorage().getUserId();

    final userId = FirestoreRestClient.resolveCanonicalTechUid(
      (rawUserId != null && rawUserId.isNotEmpty && rawUserId != 'BT-PARTNER')
          ? rawUserId
          : (phone.isNotEmpty ? phone : email),
      phone: phone,
    );
    await SecureStorage().saveUserId(userId);

    final normalizedSkillsPayload = skillsPayload.map((s) {
      final sName = (s['skillName'] ?? s['name'] ?? '').toString();
      final sId = (s['canonicalServiceId'] ?? s['skillId'] ?? s['id'] ?? '').toString();
      final canonicalId = FirestoreRestClient.resolveCanonicalServiceId(sId, skillName: sName);
      return <String, dynamic>{
        ...s,
        'id': canonicalId,
        'skillId': canonicalId,
        'canonicalServiceId': canonicalId,
        'skillName': sName.isNotEmpty ? sName : canonicalId,
        'verificationStatus': (s['verificationStatus'] ?? 'PENDING').toString().toUpperCase(),
        'enabled': s['enabled'] != false,
      };
    }).toList();

    final declaredCategories = <String>{};
    for (final s in normalizedSkillsPayload) {
      final cName = s['categoryName']?.toString();
      if (cName != null && cName.isNotEmpty) {
        declaredCategories.add(cName);
      }
    }
    final primaryCategory = declaredCategories.isNotEmpty ? declaredCategories.first : 'AC Services';

    // 1. Immediately cache locally in SharedPreferences (Guarantees persistence across restarts)
    try {
      final prefs = await SharedPreferences.getInstance();
      final encodedSkills = jsonEncode(normalizedSkillsPayload);
      await prefs.setString('cached_technician_skills_$userId', encodedSkills);
      await prefs.setString('cached_technician_skills_global', encodedSkills);
      await prefs.setString('cached_technician_skills_default', encodedSkills);
      if (rawUserId != null && rawUserId.isNotEmpty && rawUserId != userId) {
        await prefs.setString('cached_technician_skills_$rawUserId', encodedSkills);
      }
      if (phone.isNotEmpty) {
        await prefs.setString('cached_technician_skills_$phone', encodedSkills);
      }
      await prefs.setString('cached_technician_category_$userId', primaryCategory);
      await prefs.setStringList('cached_technician_categories_$userId', declaredCategories.toList());
    } catch (_) {}

    final nowUtc = DateTime.now().toUtc().toIso8601String();
    final partnerCode = FirestoreRestClient.resolveTechnicianCode(userId, phone: phone);

    // 2. When Render/trusted backend is configured, save authoritatively via backend API;
    // otherwise persist directly to Cloud Firestore with updateMask (GPS/presence untouched).
    if (!AppConfig.hasConfiguredBackend) {
      try {
        await FirestoreRestClient.upsertDocument('technician_profiles', userId, {
          'id': userId,
          'uid': userId,
          'technicianId': userId,
          'technicianCode': partnerCode,
          'fullName': realName,
          'name': realName,
          'phone': phone,
          'phoneNumber': phone,
          'email': email,
          'selectedSkills': normalizedSkillsPayload,
          'skills': normalizedSkillsPayload,
          'serviceCategories': declaredCategories.toList(),
          'categories': declaredCategories.toList(),
          'category': primaryCategory,
          'totalSkillsCount': normalizedSkillsPayload.length,
          'verifiedSkillsCount': normalizedSkillsPayload.length,
          'pendingSkillsCount': 0,
          'updatedAt': nowUtc,
        });
        debugPrint('✅ [SkillService] Successfully saved ${normalizedSkillsPayload.length} canonical skills to Cloud Firestore for $userId (GPS/presence untouched)');
      } catch (fsErr) {
        debugPrint('⚠️ [SkillService] Firestore direct skill save notice: $fsErr');
      }
    }

    final payload = {
      'skills': normalizedSkillsPayload,
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
            'technicianCode': partnerCode,
            'fullName': realName,
          });
        }
      }
    } catch (e) {
      debugPrint('Primary skills save warning: $e');
    }



    return TechnicianSkillProfileModel.fromJson({
      'skills': normalizedSkillsPayload,
      'technicianId': userId,
      'technicianCode': partnerCode,
      'fullName': realName,
    });
  }

  /// Toggle single skill active status
  Future<bool> toggleSkill(String technicianSkillId) async {
    try {
      final userDetails = await SecureStorage().getUserDetails();
      final phone = userDetails['phone'] ?? '';
      final rawUserId = await SecureStorage().getUserId();
      final userId = FirestoreRestClient.resolveCanonicalTechUid(rawUserId, phone: phone);
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('cached_technician_skills_$userId');
      if (raw != null && raw.isNotEmpty) {
        final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
        for (final item in list) {
          if (item['id'] == technicianSkillId ||
              item['skillId'] == technicianSkillId ||
              item['canonicalServiceId'] == technicianSkillId) {
            item['enabled'] = !(item['enabled'] == true);
          }
        }
        final nowUtc = DateTime.now().toUtc().toIso8601String();
        await prefs.setString('cached_technician_skills_$userId', jsonEncode(list));
        if (!AppConfig.hasConfiguredBackend) {
          await FirestoreRestClient.upsertDocument('technician_profiles', userId, {
            'selectedSkills': list,
            'skills': list,
            'updatedAt': nowUtc,
          });
        }
      }
      final res = await _dioClient.dio.patch('/technicians/skills/$technicianSkillId/toggle');
      return res.statusCode == 200;
    } catch (e) {
      debugPrint('Error toggling skill: $e');
      return !AppConfig.hasConfiguredBackend;
    }
  }
}
