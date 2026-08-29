import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import '../../../core/config/app_config.dart';
import '../../../core/network/dio_client.dart';
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
    try {
      final res = await _dioClient.dio.get('/technician/skills');
      if (res.statusCode == 200 && res.data?['data'] != null) {
        return TechnicianSkillProfileModel.fromJson(res.data['data']);
      }
    } catch (e) {
      debugPrint('Error fetching technician skill profile: $e');
    }
    return null;
  }

  /// Bulk-save newly selected skills
  Future<TechnicianSkillProfileModel?> saveSelectedSkills(List<Map<String, dynamic>> skillsPayload) async {
    try {
      final res = await _dioClient.dio.post('/technician/skills/bulk', data: {
        'skills': skillsPayload,
      });
      if (res.statusCode == 200 && res.data?['data'] != null) {
        return TechnicianSkillProfileModel.fromJson(res.data['data']);
      }
    } catch (e) {
      debugPrint('Error saving technician skills: $e');
    }
    return null;
  }

  /// Toggle single skill active status
  Future<bool> toggleSkill(String technicianSkillId) async {
    try {
      final res = await _dioClient.dio.patch('/technician/skills/$technicianSkillId/toggle');
      return res.statusCode == 200;
    } catch (e) {
      debugPrint('Error toggling skill: $e');
      return false;
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
