import 'package:flutter/foundation.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/security/secure_storage.dart';

class TechnicianProfileData {
  final String id;
  final String technicianCode;
  final String fullName;
  final String phone;
  final String email;
  final String profileImageUrl;
  final double rating;
  final int totalRatingsCount;
  final int totalJobsCompleted;
  final String kycStatus;
  final bool isOnline;
  final String upiId;
  final bool isUpiVerified;

  TechnicianProfileData({
    required this.id,
    required this.technicianCode,
    required this.fullName,
    required this.phone,
    required this.email,
    required this.profileImageUrl,
    required this.rating,
    required this.totalRatingsCount,
    required this.totalJobsCompleted,
    required this.kycStatus,
    required this.isOnline,
    required this.upiId,
    required this.isUpiVerified,
  });

  factory TechnicianProfileData.fromJson(Map<String, dynamic> json) {
    return TechnicianProfileData(
      id: json['id']?.toString() ?? '',
      technicianCode: json['technicianCode']?.toString() ?? 'BT-TECH-ACTIVE',
      fullName: json['fullName']?.toString() ?? 'Partner Technician',
      phone: json['phone']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      profileImageUrl: json['profileImageUrl']?.toString() ?? '',
      rating: (json['rating'] is num) ? (json['rating'] as num).toDouble() : 5.0,
      totalRatingsCount: (json['totalRatingsCount'] is num) ? (json['totalRatingsCount'] as num).toInt() : 0,
      totalJobsCompleted: (json['totalJobsCompleted'] is num) ? (json['totalJobsCompleted'] as num).toInt() : 0,
      kycStatus: json['kycStatus']?.toString().toUpperCase() ?? 'VERIFIED',
      isOnline: json['isOnline'] == true || json['online'] == true,
      upiId: json['upiId']?.toString() ?? '',
      isUpiVerified: json['isUpiVerified'] == true || json['upiVerified'] == true,
    );
  }

  TechnicianProfileData copyWith({
    String? id,
    String? technicianCode,
    String? fullName,
    String? phone,
    String? email,
    String? profileImageUrl,
    double? rating,
    int? totalRatingsCount,
    int? totalJobsCompleted,
    String? kycStatus,
    bool? isOnline,
    String? upiId,
    bool? isUpiVerified,
  }) {
    return TechnicianProfileData(
      id: id ?? this.id,
      technicianCode: technicianCode ?? this.technicianCode,
      fullName: fullName ?? this.fullName,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      rating: rating ?? this.rating,
      totalRatingsCount: totalRatingsCount ?? this.totalRatingsCount,
      totalJobsCompleted: totalJobsCompleted ?? this.totalJobsCompleted,
      kycStatus: kycStatus ?? this.kycStatus,
      isOnline: isOnline ?? this.isOnline,
      upiId: upiId ?? this.upiId,
      isUpiVerified: isUpiVerified ?? this.isUpiVerified,
    );
  }
}

class TechnicianProfileService {
  final DioClient _dioClient;

  TechnicianProfileService({SecureStorage? storage})
      : _dioClient = DioClient(storage ?? SecureStorage());

  Future<TechnicianProfileData?> fetchProfile() async {
    try {
      final res = await _dioClient.dio.get('/technician/profile');
      if (res.statusCode == 200 && res.data?['data'] != null) {
        return TechnicianProfileData.fromJson(res.data['data']);
      }
    } catch (e) {
      debugPrint('[TechnicianProfileService] fetchProfile warning: $e');
    }
    return null;
  }

  Future<TechnicianProfileData?> updateProfile({
    String? fullName,
    String? profileImageUrl,
    String? upiId,
  }) async {
    try {
      final payload = <String, dynamic>{};
      if (fullName != null) payload['fullName'] = fullName;
      if (profileImageUrl != null) payload['profileImageUrl'] = profileImageUrl;
      if (upiId != null) payload['upiId'] = upiId;

      final res = await _dioClient.dio.put('/technician/profile', data: payload);
      if (res.statusCode == 200 && res.data?['data'] != null) {
        return TechnicianProfileData.fromJson(res.data['data']);
      }
    } catch (e) {
      debugPrint('[TechnicianProfileService] updateProfile warning: $e');
    }
    return null;
  }

  Future<String?> reportIncident(String category, String description) async {
    try {
      final res = await _dioClient.dio.post('/technician/incident', data: {
        'category': category,
        'description': description,
      });
      if (res.statusCode == 200 && res.data?['data'] != null) {
        return res.data['data']['incidentId']?.toString();
      }
    } catch (e) {
      debugPrint('[TechnicianProfileService] reportIncident warning: $e');
    }
    return null;
  }
}
