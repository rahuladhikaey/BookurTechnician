class SkillCategoryModel {
  final String id;
  final String name;
  final String slug;
  final String iconUrl;
  final int displayOrder;
  final List<SkillItemModel> skills;

  SkillCategoryModel({
    required this.id,
    required this.name,
    required this.slug,
    this.iconUrl = '',
    this.displayOrder = 0,
    required this.skills,
  });

  factory SkillCategoryModel.fromJson(Map<String, dynamic> json) {
    final catId = json['id']?.toString() ?? json['categoryId']?.toString() ?? '';
    final catName = json['name']?.toString() ?? 'Service Category';
    final catSlug = json['slug']?.toString() ?? catName.toLowerCase().replaceAll(' ', '-');
    final catIcon = json['iconUrl']?.toString() ?? json['imageUrl']?.toString() ?? '';

    List<SkillItemModel> parsedSkills = [];

    if (json['skills'] is List && (json['skills'] as List).isNotEmpty) {
      parsedSkills = (json['skills'] as List)
          .map((s) => SkillItemModel.fromJson(s as Map<String, dynamic>, defaultCatId: catId, defaultCatName: catName))
          .toList();
    } else if (json['subcategories'] is List && (json['subcategories'] as List).isNotEmpty) {
      for (final sub in json['subcategories']) {
        if (sub is Map<String, dynamic> && sub['services'] is List) {
          for (final s in sub['services']) {
            if (s is Map<String, dynamic>) {
              parsedSkills.add(SkillItemModel.fromJson(s, defaultCatId: catId, defaultCatName: catName));
            }
          }
        }
      }
    } else if (json['services'] is List && (json['services'] as List).isNotEmpty) {
      parsedSkills = (json['services'] as List)
          .map((s) => SkillItemModel.fromJson(s as Map<String, dynamic>, defaultCatId: catId, defaultCatName: catName))
          .toList();
    }

    return SkillCategoryModel(
      id: catId,
      name: catName,
      slug: catSlug,
      iconUrl: catIcon,
      displayOrder: json['displayOrder'] is int ? json['displayOrder'] : 0,
      skills: parsedSkills,
    );
  }
}

class SkillItemModel {
  final String id;
  final String categoryId;
  final String categoryName;
  final String name;
  final String slug;
  final String description;
  final int displayOrder;

  SkillItemModel({
    required this.id,
    required this.categoryId,
    this.categoryName = '',
    required this.name,
    required this.slug,
    this.description = '',
    this.displayOrder = 0,
  });

  factory SkillItemModel.fromJson(Map<String, dynamic> json, {String defaultCatId = '', String defaultCatName = ''}) {
    final skillId = json['id']?.toString() ?? json['serviceId']?.toString() ?? json['skillId']?.toString() ?? '';
    final skillName = json['name']?.toString() ?? json['title']?.toString() ?? 'Service';
    final resolvedCatId = json['categoryId']?.toString() ?? defaultCatId;
    final resolvedCatName = json['categoryName']?.toString() ?? defaultCatName;

    return SkillItemModel(
      id: skillId,
      categoryId: resolvedCatId,
      categoryName: resolvedCatName,
      name: skillName,
      slug: json['slug']?.toString() ?? skillName.toLowerCase().replaceAll(' ', '-'),
      description: json['description']?.toString() ?? '',
      displayOrder: json['displayOrder'] is int ? json['displayOrder'] : 0,
    );
  }
}

class TechnicianSkillItemModel {
  final String id;
  final String skillId;
  final String skillName;
  final String categoryId;
  final String categoryName;
  final int experienceYears;
  final String verificationStatus; // VERIFIED, PENDING, REJECTED
  final bool enabled;
  final String? rejectionReason;

  TechnicianSkillItemModel({
    required this.id,
    required this.skillId,
    required this.skillName,
    required this.categoryId,
    required this.categoryName,
    this.experienceYears = 1,
    this.verificationStatus = 'PENDING',
    this.enabled = true,
    this.rejectionReason,
  });

  factory TechnicianSkillItemModel.fromJson(Map<String, dynamic> json) {
    int parsedExp = 2;
    if (json['experienceYears'] is int) {
      parsedExp = json['experienceYears'];
    } else if (json['experienceYears'] is num) {
      parsedExp = (json['experienceYears'] as num).toInt();
    } else if (json['experienceYears'] != null) {
      parsedExp = int.tryParse(json['experienceYears'].toString()) ?? 2;
    }

    final sId = json['skillId']?.toString() ?? json['id']?.toString() ?? '';
    final sName = json['skillName']?.toString() ?? json['name']?.toString() ?? sId;

    return TechnicianSkillItemModel(
      id: json['id']?.toString() ?? sId,
      skillId: sId,
      skillName: sName,
      categoryId: json['categoryId']?.toString() ?? '',
      categoryName: json['categoryName']?.toString() ?? '',
      experienceYears: parsedExp,
      verificationStatus: json['verificationStatus']?.toString().toUpperCase() ?? 'VERIFIED',
      enabled: json['enabled'] != false,
      rejectionReason: json['rejectionReason']?.toString(),
    );
  }

  TechnicianSkillItemModel copyWith({
    bool? enabled,
    String? verificationStatus,
  }) {
    return TechnicianSkillItemModel(
      id: id,
      skillId: skillId,
      skillName: skillName,
      categoryId: categoryId,
      categoryName: categoryName,
      experienceYears: experienceYears,
      verificationStatus: verificationStatus ?? this.verificationStatus,
      enabled: enabled ?? this.enabled,
      rejectionReason: rejectionReason,
    );
  }
}

class TechnicianSkillProfileModel {
  final String technicianId;
  final String technicianCode;
  final String fullName;
  final double rating;
  final int totalRatingsCount;
  final int totalJobsCompleted;
  final List<TechnicianSkillItemModel> skills;
  final int totalSkillsCount;
  final int verifiedSkillsCount;
  final int pendingSkillsCount;

  TechnicianSkillProfileModel({
    required this.technicianId,
    required this.technicianCode,
    required this.fullName,
    required this.rating,
    required this.totalRatingsCount,
    required this.totalJobsCompleted,
    required this.skills,
    required this.totalSkillsCount,
    required this.verifiedSkillsCount,
    required this.pendingSkillsCount,
  });

  factory TechnicianSkillProfileModel.fromJson(Map<String, dynamic> json) {
    var rawSkills = json['skills'] as List? ?? [];
    List<TechnicianSkillItemModel> parsedSkills = rawSkills
        .map((s) => TechnicianSkillItemModel.fromJson(s as Map<String, dynamic>))
        .toList();

    double parsedRating = 4.88;
    if (json['rating'] is num) {
      parsedRating = (json['rating'] as num).toDouble();
    }

    int totalCount = json['totalSkillsCount'] is int ? json['totalSkillsCount'] : parsedSkills.length;
    int verifiedCount = json['verifiedSkillsCount'] is int ? json['verifiedSkillsCount'] : parsedSkills.where((s) => s.verificationStatus == 'VERIFIED').length;
    int pendingCount = json['pendingSkillsCount'] is int ? json['pendingSkillsCount'] : parsedSkills.where((s) => s.verificationStatus == 'PENDING').length;

    return TechnicianSkillProfileModel(
      technicianId: json['technicianId']?.toString() ?? '',
      technicianCode: json['technicianCode']?.toString() ?? 'BT-PARTNER',
      fullName: json['fullName']?.toString() ?? 'Partner Technician',
      rating: parsedRating,
      totalRatingsCount: json['totalRatingsCount'] is int ? json['totalRatingsCount'] : 0,
      totalJobsCompleted: json['totalJobsCompleted'] is int ? json['totalJobsCompleted'] : 0,
      skills: parsedSkills,
      totalSkillsCount: totalCount,
      verifiedSkillsCount: verifiedCount,
      pendingSkillsCount: pendingCount,
    );
  }
}
