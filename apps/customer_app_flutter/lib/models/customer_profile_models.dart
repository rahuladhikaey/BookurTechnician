// ─── Customer Profile & Address Models ───────────────────────────────────

enum AddressType {
  home,
  work,
  other,
}

enum CustomerProfileStatus {
  incomplete,       // 0–49%
  partiallyComplete,// 50–99%
  complete,         // 100%
}

class CustomerAddress {
  final String id;
  final String customerId;
  final AddressType addressType;
  final String houseFlat;
  final String street;
  final String area;
  final String city;
  final String state;
  final String postalCode;
  final String landmark;
  final double latitude;
  final double longitude;
  final bool isPrimary;
  final DateTime createdAt;
  final DateTime updatedAt;

  const CustomerAddress({
    required this.id,
    required this.customerId,
    this.addressType = AddressType.home,
    required this.houseFlat,
    required this.street,
    required this.area,
    required this.city,
    this.state = 'Karnataka',
    required this.postalCode,
    this.landmark = '',
    this.latitude = 12.9716,
    this.longitude = 77.5946,
    this.isPrimary = false,
    required this.createdAt,
    required this.updatedAt,
  });

  String get formattedAddress {
    final parts = [
      if (houseFlat.isNotEmpty) houseFlat,
      if (street.isNotEmpty) street,
      if (area.isNotEmpty) area,
      if (city.isNotEmpty) city,
      if (postalCode.isNotEmpty) postalCode,
    ];
    return parts.join(', ');
  }

  String get typeLabel {
    switch (addressType) {
      case AddressType.home:
        return 'Home';
      case AddressType.work:
        return 'Work';
      case AddressType.other:
        return 'Other';
    }
  }

  CustomerAddress copyWith({
    String? id,
    String? customerId,
    AddressType? addressType,
    String? houseFlat,
    String? street,
    String? area,
    String? city,
    String? state,
    String? postalCode,
    String? landmark,
    double? latitude,
    double? longitude,
    bool? isPrimary,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return CustomerAddress(
      id: id ?? this.id,
      customerId: customerId ?? this.customerId,
      addressType: addressType ?? this.addressType,
      houseFlat: houseFlat ?? this.houseFlat,
      street: street ?? this.street,
      area: area ?? this.area,
      city: city ?? this.city,
      state: state ?? this.state,
      postalCode: postalCode ?? this.postalCode,
      landmark: landmark ?? this.landmark,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      isPrimary: isPrimary ?? this.isPrimary,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'customerId': customerId,
    'addressType': addressType.name,
    'houseFlat': houseFlat,
    'street': street,
    'area': area,
    'city': city,
    'state': state,
    'postalCode': postalCode,
    'landmark': landmark,
    'latitude': latitude,
    'longitude': longitude,
    'isPrimary': isPrimary,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory CustomerAddress.fromJson(Map<String, dynamic> json) => CustomerAddress(
    id: json['id'] as String,
    customerId: json['customerId'] as String,
    addressType: AddressType.values.firstWhere(
      (e) => e.name == json['addressType'],
      orElse: () => AddressType.home,
    ),
    houseFlat: json['houseFlat'] as String? ?? '',
    street: json['street'] as String? ?? '',
    area: json['area'] as String? ?? '',
    city: json['city'] as String? ?? '',
    state: json['state'] as String? ?? 'Karnataka',
    postalCode: json['postalCode'] as String? ?? '',
    landmark: json['landmark'] as String? ?? '',
    latitude: (json['latitude'] as num?)?.toDouble() ?? 12.9716,
    longitude: (json['longitude'] as num?)?.toDouble() ?? 77.5946,
    isPrimary: json['isPrimary'] as bool? ?? false,
    createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
    updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '') ?? DateTime.now(),
  );
}

class CustomerProfile {
  final String customerId;
  final String userId;
  final String fullName;
  final String phone;
  final bool isPhoneVerified;
  final String email;
  final bool isEmailVerified;
  final String? profilePhotoUrl;
  final DateTime? dateOfBirth;
  final DateTime? anniversary;
  final String? gender;
  final List<CustomerAddress> addresses;
  final int profileCompletion; // 0 to 100
  final bool isProfileComplete;
  final List<String> missingFields;
  final CustomerProfileStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;

  const CustomerProfile({
    required this.customerId,
    required this.userId,
    required this.fullName,
    required this.phone,
    required this.isPhoneVerified,
    required this.email,
    required this.isEmailVerified,
    this.profilePhotoUrl,
    this.dateOfBirth,
    this.anniversary,
    this.gender,
    this.addresses = const [],
    this.profileCompletion = 0,
    this.isProfileComplete = false,
    this.missingFields = const [],
    this.status = CustomerProfileStatus.incomplete,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Factory that executes strict backend-aligned dynamic calculation
  factory CustomerProfile.createWithCalculation({
    required String customerId,
    required String userId,
    required String fullName,
    required String phone,
    required bool isPhoneVerified,
    required String email,
    required bool isEmailVerified,
    String? profilePhotoUrl,
    DateTime? dateOfBirth,
    DateTime? anniversary,
    String? gender,
    List<CustomerAddress> addresses = const [],
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    final missing = <String>[];
    int score = 0;

    // 1. Full Name check: at least 2 chars, not pure digits, trimmed
    final trimmedName = fullName.trim();
    final isPureDigits = RegExp(r'^[0-9]+$').hasMatch(trimmedName);
    if (trimmedName.length >= 2 && !isPureDigits) {
      score += 25;
    } else {
      missing.add('FULL_NAME');
    }

    // 2. Verified Phone Number check
    if (phone.isNotEmpty && isPhoneVerified) {
      score += 25;
    } else {
      missing.add('VERIFIED_PHONE');
    }

    // 3. Verified Email Address check
    if (email.isNotEmpty && isEmailVerified) {
      score += 25;
    } else {
      missing.add('VERIFIED_EMAIL');
    }

    // 4. Valid Service Address check
    final hasValidAddress = addresses.any((a) =>
      a.houseFlat.trim().isNotEmpty &&
      a.area.trim().isNotEmpty &&
      a.city.trim().isNotEmpty
    );
    if (hasValidAddress) {
      score += 25;
    } else {
      missing.add('SERVICE_ADDRESS');
    }

    final isComplete = score == 100;
    final status = score == 100
        ? CustomerProfileStatus.complete
        : score >= 50
            ? CustomerProfileStatus.partiallyComplete
            : CustomerProfileStatus.incomplete;

    return CustomerProfile(
      customerId: customerId,
      userId: userId,
      fullName: trimmedName,
      phone: phone,
      isPhoneVerified: isPhoneVerified,
      email: email,
      isEmailVerified: isEmailVerified,
      profilePhotoUrl: profilePhotoUrl,
      dateOfBirth: dateOfBirth,
      anniversary: anniversary,
      gender: gender,
      addresses: addresses,
      profileCompletion: score,
      isProfileComplete: isComplete,
      missingFields: missing,
      status: status,
      createdAt: createdAt ?? DateTime.now(),
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  CustomerAddress? get primaryAddress {
    if (addresses.isEmpty) return null;
    return addresses.firstWhere((a) => a.isPrimary, orElse: () => addresses.first);
  }

  String get missingFieldsReadable {
    final list = <String>[];
    if (missingFields.contains('FULL_NAME')) list.add('Full Name');
    if (missingFields.contains('VERIFIED_PHONE')) list.add('Phone Verification');
    if (missingFields.contains('VERIFIED_EMAIL')) list.add('Email Verification');
    if (missingFields.contains('SERVICE_ADDRESS')) list.add('Service Address');
    return list.join(', ');
  }

  CustomerProfile copyWith({
    String? customerId,
    String? userId,
    String? fullName,
    String? phone,
    bool? isPhoneVerified,
    String? email,
    bool? isEmailVerified,
    String? profilePhotoUrl,
    bool clearProfilePhoto = false,
    DateTime? dateOfBirth,
    bool clearDob = false,
    DateTime? anniversary,
    bool clearAnniversary = false,
    String? gender,
    List<CustomerAddress>? addresses,
  }) {
    return CustomerProfile.createWithCalculation(
      customerId: customerId ?? this.customerId,
      userId: userId ?? this.userId,
      fullName: fullName ?? this.fullName,
      phone: phone ?? this.phone,
      isPhoneVerified: isPhoneVerified ?? this.isPhoneVerified,
      email: email ?? this.email,
      isEmailVerified: isEmailVerified ?? this.isEmailVerified,
      profilePhotoUrl: clearProfilePhoto ? null : (profilePhotoUrl ?? this.profilePhotoUrl),
      dateOfBirth: clearDob ? null : (dateOfBirth ?? this.dateOfBirth),
      anniversary: clearAnniversary ? null : (anniversary ?? this.anniversary),
      gender: gender ?? this.gender,
      addresses: addresses ?? this.addresses,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }
}
