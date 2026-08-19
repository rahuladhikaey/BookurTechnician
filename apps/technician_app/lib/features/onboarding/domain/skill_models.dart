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
    var rawSkills = json['skills'] as List? ?? [];
    List<SkillItemModel> parsedSkills = rawSkills
        .map((s) => SkillItemModel.fromJson(s as Map<String, dynamic>))
        .toList();

    return SkillCategoryModel(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      slug: json['slug']?.toString() ?? '',
      iconUrl: json['iconUrl']?.toString() ?? '',
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

  factory SkillItemModel.fromJson(Map<String, dynamic> json) {
    return SkillItemModel(
      id: json['id']?.toString() ?? '',
      categoryId: json['categoryId']?.toString() ?? '',
      categoryName: json['categoryName']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      slug: json['slug']?.toString() ?? '',
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
    return TechnicianSkillItemModel(
      id: json['id']?.toString() ?? '',
      skillId: json['skillId']?.toString() ?? '',
      skillName: json['skillName']?.toString() ?? '',
      categoryId: json['categoryId']?.toString() ?? '',
      categoryName: json['categoryName']?.toString() ?? '',
      experienceYears: json['experienceYears'] is int ? json['experienceYears'] : 1,
      verificationStatus: json['verificationStatus']?.toString().toUpperCase() ?? 'PENDING',
      enabled: json['enabled'] == true,
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

    return TechnicianSkillProfileModel(
      technicianId: json['technicianId']?.toString() ?? '',
      technicianCode: json['technicianCode']?.toString() ?? '',
      fullName: json['fullName']?.toString() ?? 'Partner Technician',
      rating: parsedRating,
      totalRatingsCount: json['totalRatingsCount'] is int ? json['totalRatingsCount'] : 0,
      totalJobsCompleted: json['totalJobsCompleted'] is int ? json['totalJobsCompleted'] : 0,
      skills: parsedSkills,
      totalSkillsCount: json['totalSkillsCount'] is int ? json['totalSkillsCount'] : parsedSkills.length,
      verifiedSkillsCount: json['verifiedSkillsCount'] is int ? json['verifiedSkillsCount'] : 0,
      pendingSkillsCount: json['pendingSkillsCount'] is int ? json['pendingSkillsCount'] : 0,
    );
  }
}
