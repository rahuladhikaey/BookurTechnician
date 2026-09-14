class NearbyTechnician {
  final String technicianId;
  final String technicianCode;
  final String fullName;
  final String phone;
  final String category;
  final String profileImageUrl;
  final int experienceYears;
  final double rating;
  final int totalRatingsCount;
  final int totalJobsCompleted;
  final double currentLatitude;
  final double currentLongitude;
  final double distanceKm;
  final double distanceMeters;
  final int estimatedArrivalMinutes;
  final bool isOnline;
  final String availabilityStatus;

  NearbyTechnician({
    required this.technicianId,
    required this.technicianCode,
    required this.fullName,
    required this.phone,
    required this.category,
    required this.profileImageUrl,
    required this.experienceYears,
    required this.rating,
    required this.totalRatingsCount,
    required this.totalJobsCompleted,
    required this.currentLatitude,
    required this.currentLongitude,
    required this.distanceKm,
    required this.distanceMeters,
    required this.estimatedArrivalMinutes,
    required this.isOnline,
    required this.availabilityStatus,
  });

  factory NearbyTechnician.fromJson(Map<String, dynamic> json) {
    return NearbyTechnician(
      technicianId: json['technicianId']?.toString() ?? '',
      technicianCode: json['technicianCode']?.toString() ?? '',
      fullName: json['fullName']?.toString() ?? 'Service Partner',
      phone: json['phone']?.toString() ?? '',
      category: json['category']?.toString() ?? 'GENERAL',
      profileImageUrl: json['profileImageUrl']?.toString() ?? '',
      experienceYears: (json['experienceYears'] as num?)?.toInt() ?? 2,
      rating: (json['rating'] as num?)?.toDouble() ?? 4.8,
      totalRatingsCount: (json['totalRatingsCount'] as num?)?.toInt() ?? 0,
      totalJobsCompleted: (json['totalJobsCompleted'] as num?)?.toInt() ?? 0,
      currentLatitude: (json['currentLatitude'] as num?)?.toDouble() ?? 0.0,
      currentLongitude: (json['currentLongitude'] as num?)?.toDouble() ?? 0.0,
      distanceKm: (json['distanceKm'] as num?)?.toDouble() ?? 0.0,
      distanceMeters: (json['distanceMeters'] as num?)?.toDouble() ?? 0.0,
      estimatedArrivalMinutes: (json['estimatedArrivalMinutes'] as num?)?.toInt() ?? 15,
      isOnline: json['isOnline'] == true,
      availabilityStatus: json['availabilityStatus']?.toString() ?? 'AVAILABLE',
    );
  }

  String get displayDistance {
    if (distanceKm < 1.0) {
      return '${distanceMeters.round()} m away';
    }
    return '${distanceKm.toStringAsFixed(1)} km away';
  }

  String get displayEta {
    return '~$estimatedArrivalMinutes mins';
  }
}

class NearbyTechniciansResult {
  final String serviceId;
  final String serviceName;
  final String categoryId;
  final double latitude;
  final double longitude;
  final double radiusKm;
  final int totalOnlineTechnicians;
  final DateTime updatedAt;
  final List<NearbyTechnician> technicians;

  NearbyTechniciansResult({
    required this.serviceId,
    required this.serviceName,
    required this.categoryId,
    required this.latitude,
    required this.longitude,
    required this.radiusKm,
    required this.totalOnlineTechnicians,
    required this.updatedAt,
    required this.technicians,
  });

  factory NearbyTechniciansResult.fromJson(Map<String, dynamic> json) {
    final rawList = json['technicians'] as List<dynamic>? ?? [];
    final techs = rawList
        .whereType<Map<String, dynamic>>()
        .map((e) => NearbyTechnician.fromJson(e))
        .toList();

    return NearbyTechniciansResult(
      serviceId: json['serviceId']?.toString() ?? '',
      serviceName: json['serviceName']?.toString() ?? '',
      categoryId: json['categoryId']?.toString() ?? '',
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0.0,
      radiusKm: (json['radiusKm'] as num?)?.toDouble() ?? 15.0,
      totalOnlineTechnicians: (json['totalOnlineTechnicians'] as num?)?.toInt() ?? techs.length,
      updatedAt: DateTime.tryParse(json['updatedAt']?.toString() ?? '') ?? DateTime.now(),
      technicians: techs,
    );
  }
}
