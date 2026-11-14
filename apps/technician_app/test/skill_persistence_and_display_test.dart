import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:technician_app/core/network/firestore_rest_client.dart';
import 'package:technician_app/features/onboarding/data/skill_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FirestoreRestClient.clearMemoryCache();
  });

  test('Skill persistence: saveSelectedSkills caches locally and fetchMySkillProfile retrieves it', () async {
    final service = SkillService();

    final testSkills = [
      {
        'id': 'sk_ac_installation',
        'name': 'AC Installation',
        'experienceYears': 3,
        'categoryName': 'AC Services',
      },
    ];

    // 1. Save skills
    final savedProfile = await service.saveSelectedSkills(testSkills);
    expect(savedProfile, isNotNull);
    expect(savedProfile!.skills.length, 1);
    expect(savedProfile.skills.first.canonicalServiceId, 'ac_install');

    // 2. Fetch profile - must return persisted skills even without live backend
    final fetchedProfile = await service.fetchMySkillProfile();
    expect(fetchedProfile, isNotNull);
    expect(fetchedProfile!.skills.length, 1);
    expect(fetchedProfile.skills.first.canonicalServiceId, 'ac_install');
    expect(fetchedProfile.totalSkillsCount, 1);
  });
}

