// ─── Models ────────────────────────────────────────────────────────────────

enum BookingStatus {
  confirmed,
  techAssigned,
  techAccepted,
  techOnTheWay,
  techArrived,
  serviceStarted,
  forwarded,
  completed,
  cancelled,
}

enum PaymentStatus {
  idle,
  processing,
  success,
  errorTimeout,
  errorNetwork,
  pendingRestoration,
}

class ServiceItem {
  final String id;
  final String canonicalServiceId;
  final String categoryId;
  final String subcategoryId;
  final String name;
  final double price;
  final double basePrice;
  final double offerPrice;
  final double discountPrice;
  final double bookingCharge;
  final int advancePrepaymentPct;
  final double technicianPayoutAmount;
  final double rating;
  final int reviewsCount;
  final int durationMinutes;
  final String description;
  final String warrantyText;
  final List<String> inclusions;
  final List<String> exclusions;
  final List<MapEntry<String, String>> faqs;
  final String imageUrl;
  final bool isActive;
  final int displayOrder;
  final int usageCount;
  final int bookingCount;

  const ServiceItem({
    required this.id,
    this.canonicalServiceId = '',
    this.categoryId = '',
    this.subcategoryId = '',
    required this.name,
    required this.price,
    this.basePrice = 0.0,
    this.offerPrice = 0.0,
    this.discountPrice = 0.0,
    this.bookingCharge = 49.0,
    this.advancePrepaymentPct = 30,
    this.technicianPayoutAmount = 0.0,
    this.rating = 4.8,
    this.reviewsCount = 0,
    this.durationMinutes = 45,
    this.description = '',
    this.warrantyText = '30 Days Warranty',
    this.inclusions = const [],
    this.exclusions = const [],
    this.faqs = const [],
    this.imageUrl = '',
    this.isActive = true,
    this.displayOrder = 0,
    this.usageCount = 0,
    this.bookingCount = 0,
  });

  factory ServiceItem.fromJson(Map<String, dynamic> json) {
    final rawDiscount = (json['discountPrice'] as num?)?.toDouble() ??
        (json['offerPrice'] as num?)?.toDouble() ??
        (json['price'] as num?)?.toDouble() ??
        (json['basePrice'] as num?)?.toDouble() ??
        0.0;
    final rawBase = (json['basePrice'] as num?)?.toDouble() ?? rawDiscount;
    final rawBooking = (json['bookingCharge'] as num?)?.toDouble() ?? (rawDiscount >= 1000 ? 99.0 : 49.0);
    final rawPct = (json['advancePrepaymentPct'] as num?)?.toInt() ?? 30;
    final rawPayout = (json['technicianPayoutAmount'] as num?)?.toDouble() ?? (rawDiscount * 0.8);
    final rawActive = json['isActive'] != null
        ? json['isActive'] == true
        : (json['active'] != null ? json['active'] == true : true);
    final idStr = json['id']?.toString() ?? '';

    return ServiceItem(
      id: idStr,
      canonicalServiceId: json['canonicalServiceId']?.toString() ?? idStr,
      categoryId: json['categoryId']?.toString() ?? '',
      subcategoryId: json['subcategoryId']?.toString() ?? '',
      name: json['name']?.toString() ?? json['title']?.toString() ?? '',
      price: rawDiscount,
      basePrice: rawBase,
      offerPrice: rawDiscount,
      discountPrice: rawDiscount,
      bookingCharge: rawBooking,
      advancePrepaymentPct: rawPct,
      technicianPayoutAmount: rawPayout,
      durationMinutes: (json['durationMinutes'] as num?)?.toInt() ??
          (json['estimatedDurationMinutes'] as num?)?.toInt() ??
          45,
      warrantyText: json['warrantyText']?.toString() ?? '30 Days Warranty',
      description: json['description']?.toString() ?? '',
      imageUrl: json['imageUrl']?.toString() ?? '',
      isActive: rawActive,
      displayOrder: (json['displayOrder'] as num?)?.toInt() ?? 0,
      usageCount: (json['usageCount'] as num?)?.toInt() ?? 0,
      bookingCount: (json['bookingCount'] as num?)?.toInt() ?? 0,
    );
  }
}

class Subcategory {
  final String id;
  final String name;
  final List<ServiceItem> services;
  const Subcategory({required this.id, required this.name, required this.services});

  factory Subcategory.fromJson(Map<String, dynamic> json) {
    final parsedServices = (json['services'] as List?)
            ?.map((s) => ServiceItem.fromJson(s as Map<String, dynamic>))
            .where((s) => s.isActive)
            .toList() ??
        [];
    return Subcategory(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      services: parsedServices,
    );
  }
}

class Category {
  final String id;
  final String name;
  final String imageUrl;
  final List<Subcategory> subcategories;
  const Category({
    required this.id,
    required this.name,
    this.imageUrl = '',
    required this.subcategories,
  });

  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      imageUrl: json['iconUrl']?.toString() ?? json['bannerUrl']?.toString() ?? json['imageUrl']?.toString() ?? '',
      subcategories: (json['subcategories'] as List?)?.map((s) => Subcategory.fromJson(s as Map<String, dynamic>)).toList() ?? [],
    );
  }
}

class AddOnItem {
  final String id;
  final String name;
  final double price;
  final String reason;
  final bool isApproved;
  const AddOnItem({required this.id, required this.name, required this.price, required this.reason, this.isApproved = false});
}

class Booking {
  final String id;
  final List<ServiceItem> services;
  final String date;
  final String timeSlot;
  final BookingStatus status;
  final double baseCost;
  final double visitFee;
  final double discount;
  final double gstTax;
  final double grandTotal;
  final String address;
  final String technicianName;
  final String technicianPhone;
  final String technicianCode;
  final double technicianRating;
  final String technicianAvatar;
  final String otpCode;
  final List<AddOnItem> addOns;

  const Booking({
    required this.id,
    required this.services,
    required this.date,
    required this.timeSlot,
    required this.status,
    required this.baseCost,
    this.visitFee = 99.0,
    this.discount = 0.0,
    required this.gstTax,
    this.grandTotal = 0.0,
    this.address = '',
    this.technicianName = '',
    this.technicianPhone = '',
    this.technicianCode = '',
    this.technicianRating = 0.0,
    this.technicianAvatar = '',
    this.otpCode = '',
    this.addOns = const [],
  });

  String get bookingCode {
    if (id.startsWith('BT-') || id.startsWith('BK-')) return id;
    final clean = id.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');
    return 'BT-${clean.length >= 6 ? clean.substring(clean.length - 6).toUpperCase() : clean.toUpperCase()}';
  }

  factory Booking.fromJson(Map<String, dynamic> json) {
    final statusStr = json['status']?.toString().toUpperCase() ?? 'CONFIRMED';
    BookingStatus bookingStatus = BookingStatus.confirmed;
    if (statusStr == 'ASSIGNED' || statusStr == 'ACCEPTED' || statusStr == 'TECHASSIGNED') {
      bookingStatus = BookingStatus.techAssigned;
    } else if (statusStr == 'ON_THE_WAY' || statusStr == 'TECHONTHEWAY') {
      bookingStatus = BookingStatus.techOnTheWay;
    } else if (statusStr == 'ARRIVED' || statusStr == 'TECHARRIVED') {
      bookingStatus = BookingStatus.techArrived;
    } else if (statusStr == 'IN_PROGRESS' || statusStr == 'SERVICE_STARTED' || statusStr == 'SERVICESTARTED') {
      bookingStatus = BookingStatus.serviceStarted;
    } else if (statusStr == 'COMPLETED') {
      bookingStatus = BookingStatus.completed;
    } else if (statusStr == 'CANCELLED') {
      bookingStatus = BookingStatus.cancelled;
    } else if (statusStr == 'FORWARDED') {
      bookingStatus = BookingStatus.forwarded;
    }

    final rawBaseCost = (json['baseCost'] as num?)?.toDouble() ??
        (json['basePrice'] as num?)?.toDouble() ??
        (json['totalAmount'] as num?)?.toDouble() ??
        (json['grandTotal'] as num?)?.toDouble() ??
        0.0;

    final rawGrandTotal = (json['grandTotal'] as num?)?.toDouble() ??
        (json['totalAmount'] as num?)?.toDouble() ??
        rawBaseCost;

    final rawVisitFee = (json['visitFee'] as num?)?.toDouble() ??
        (json['safetyFee'] as num?)?.toDouble() ??
        49.0;

    final rawGst = (json['gstTax'] as num?)?.toDouble() ??
        (json['gstAmount'] as num?)?.toDouble() ??
        (rawBaseCost * 0.18);

    final rawDiscount = (json['discount'] as num?)?.toDouble() ?? 0.0;

    final sName = json['serviceName']?.toString() ??
        (json['services'] is List && (json['services'] as List).isNotEmpty
            ? ((json['services'] as List)[0]['name']?.toString() ?? 'Service')
            : 'Technician Service');
    final sId = json['serviceId']?.toString() ??
        (json['services'] is List && (json['services'] as List).isNotEmpty
            ? ((json['services'] as List)[0]['id']?.toString() ?? 'serv_1')
            : 'serv_1');

    final servicesList = <ServiceItem>[];
    if (json['services'] is List && (json['services'] as List).isNotEmpty) {
      for (var s in (json['services'] as List)) {
        if (s is Map<String, dynamic>) {
          servicesList.add(ServiceItem.fromJson(s));
        }
      }
    }
    if (servicesList.isEmpty) {
      servicesList.add(ServiceItem(id: sId, name: sName, price: rawBaseCost));
    }

    final rawTech = json['technician'] is Map ? Map<String, dynamic>.from(json['technician']) : null;
    final tName = json['technicianName']?.toString() ?? rawTech?['technicianName']?.toString() ?? rawTech?['name']?.toString() ?? '';
    final tPhone = json['technicianPhone']?.toString() ?? rawTech?['technicianPhone']?.toString() ?? rawTech?['phone']?.toString() ?? '';
    final tCode = json['technicianCode']?.toString() ??
        rawTech?['technicianCode']?.toString() ??
        rawTech?['code']?.toString() ??
        (rawTech?['id'] != null ? 'BT-TECH-${rawTech!['id'].toString().toUpperCase().padLeft(6, '0')}' : '');
    final tRating = (json['technicianRating'] as num?)?.toDouble() ??
        (rawTech?['technicianRating'] as num?)?.toDouble() ??
        (rawTech?['rating'] as num?)?.toDouble() ??
        0.0;
    final tAvatar = json['technicianAvatar']?.toString() ?? rawTech?['avatar']?.toString() ?? '';

    return Booking(
      id: json['bookingCode']?.toString() ?? json['id']?.toString() ?? 'BK-${DateTime.now().millisecondsSinceEpoch}',
      services: servicesList,
      date: json['scheduleDate']?.toString() ?? json['date']?.toString() ?? 'Today',
      timeSlot: json['scheduleSlot']?.toString() ?? json['timeSlot']?.toString() ?? '3:00 PM – 4:00 PM',
      status: bookingStatus,
      baseCost: rawBaseCost,
      visitFee: rawVisitFee,
      discount: rawDiscount,
      gstTax: rawGst,
      grandTotal: rawGrandTotal,
      address: json['fullAddress']?.toString() ?? json['address']?.toString() ?? '',
      technicianName: tName,
      technicianPhone: tPhone,
      technicianCode: tCode,
      technicianRating: tRating,
      technicianAvatar: tAvatar,
      otpCode: json['startServiceOtp']?.toString() ?? json['startOtp']?.toString() ?? json['otpCode']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'bookingCode': id,
      'serviceId': services.isNotEmpty ? services.first.id : '',
      'serviceName': services.isNotEmpty ? services.map((s) => s.name).join(', ') : '',
      'services': services
          .map((s) => {
                'id': s.id,
                'name': s.name,
                'price': s.price,
              })
          .toList(),
      'scheduleDate': date,
      'scheduleSlot': timeSlot,
      'date': date,
      'timeSlot': timeSlot,
      'status': status.name,
      'baseCost': baseCost,
      'basePrice': baseCost,
      'visitFee': visitFee,
      'discount': discount,
      'gstTax': gstTax,
      'grandTotal': grandTotal,
      'totalAmount': grandTotal,
      'address': address,
      'fullAddress': address,
      'technicianName': technicianName,
      'technicianPhone': technicianPhone,
      'technicianCode': technicianCode,
      'technicianRating': technicianRating,
      'technicianAvatar': technicianAvatar,
      'startOtp': otpCode,
      'startServiceOtp': otpCode,
      'otpCode': otpCode,
    };
  }

  Booking copyWith({
    String? id,
    List<ServiceItem>? services,
    String? date,
    String? timeSlot,
    BookingStatus? status,
    double? baseCost,
    double? visitFee,
    double? discount,
    double? gstTax,
    double? grandTotal,
    String? address,
    String? technicianName,
    String? technicianPhone,
    String? technicianCode,
    double? technicianRating,
    String? technicianAvatar,
    String? otpCode,
    List<AddOnItem>? addOns,
  }) {
    return Booking(
      id: id ?? this.id,
      services: services ?? this.services,
      date: date ?? this.date,
      timeSlot: timeSlot ?? this.timeSlot,
      status: status ?? this.status,
      baseCost: baseCost ?? this.baseCost,
      visitFee: visitFee ?? this.visitFee,
      discount: discount ?? this.discount,
      gstTax: gstTax ?? this.gstTax,
      grandTotal: grandTotal ?? this.grandTotal,
      address: address ?? this.address,
      technicianName: technicianName ?? this.technicianName,
      technicianPhone: technicianPhone ?? this.technicianPhone,
      technicianCode: technicianCode ?? this.technicianCode,
      technicianRating: technicianRating ?? this.technicianRating,
      technicianAvatar: technicianAvatar ?? this.technicianAvatar,
      otpCode: otpCode ?? this.otpCode,
      addOns: addOns ?? this.addOns,
    );
  }
}

// ─── Static Bundled Asset Defaults (Zero Fake Catalog/Service Records) ──────

class MockData {
  static const List<Category> categoriesList = [];
  static const List<ServiceItem> popularServices = [];

  static final List<PromotionalBanner> default3DHeroBanners = [
    const PromotionalBanner(
      id: 'banner_3d_1',
      title: 'Expert Home Services',
      subtitle: 'Certified Technicians at Your Doorstep',
      badgeText: 'Instant Booking',
      ctaText: 'Book Now',
      imageUrl: 'assets/images/banner_3d_1.png',
      autoSlide: true,
      slideDuration: 3500,
    ),
    const PromotionalBanner(
      id: 'banner_3d_2',
      title: 'AC & Electrical Repair',
      subtitle: 'Fast Dispatch · 30-Day Warranty',
      badgeText: 'Verified',
      ctaText: 'Book Service',
      imageUrl: 'assets/images/banner_3d_2.png',
      autoSlide: true,
      slideDuration: 3500,
    ),
    const PromotionalBanner(
      id: 'banner_3d_3',
      title: 'Verified & Certified Experts',
      subtitle: 'Transparent Pricing · 100% Safe',
      badgeText: 'Guaranteed',
      ctaText: 'Explore Now',
      imageUrl: 'assets/images/banner_3d_3.png',
      autoSlide: true,
      slideDuration: 3500,
    ),
  ];

  static final List<PromotionalBanner> defaultPopularBanners = [
    const PromotionalBanner(
      id: 'pop_slide_1',
      badgeText: 'TRENDING',
      title: 'Certified Electrician & Wiring',
      subtitle: 'Fast arrival with 30-day warranty',
      ctaText: 'Book Now',
      imageUrl: 'assets/images/popular_banner_1.png',
      categoryId: 'cat_electrical',
      serviceId: 'fan_install',
      autoSlide: true,
      slideDuration: 3500,
    ),
    const PromotionalBanner(
      id: 'pop_slide_2',
      badgeText: 'POPULAR',
      title: 'AC & Appliance Deep Repair',
      subtitle: 'Expert cooling, gas refill & foam jet service',
      ctaText: 'Explore',
      imageUrl: 'assets/images/popular_banner_2.png',
      categoryId: 'cat_ac',
      serviceId: 'ac_deep_cleaning',
      autoSlide: true,
      slideDuration: 3500,
    ),
    const PromotionalBanner(
      id: 'pop_slide_3',
      badgeText: 'SPECIAL OFFER',
      title: 'Smart CCTV & Security Setup',
      subtitle: 'Full HD surveillance & remote mobile view',
      ctaText: 'View Plans',
      imageUrl: 'assets/images/popular_banner_3.png',
      categoryId: 'cat_cctv',
      serviceId: 'cctv_install_gen',
      autoSlide: true,
      slideDuration: 3500,
    ),
  ];
}

class PromotionalBanner {
  final String id;
  final String title;
  final String subtitle;
  final String badgeText;
  final String ctaText;
  final String imageUrl;
  final String serviceId;
  final String categoryId;
  final int displayOrder;
  final bool autoSlide;
  final int slideDuration;
  final String startDate;
  final String endDate;

  const PromotionalBanner({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.badgeText,
    required this.ctaText,
    required this.imageUrl,
    this.serviceId = '',
    this.categoryId = '',
    this.displayOrder = 0,
    this.autoSlide = true,
    this.slideDuration = 3000,
    this.startDate = '',
    this.endDate = '',
  });

  factory PromotionalBanner.fromJson(Map<String, dynamic> json) {
    return PromotionalBanner(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      subtitle: json['subtitle'] ?? '',
      badgeText: json['badgeText'] ?? '',
      ctaText: json['ctaText'] ?? '',
      imageUrl: json['imageUrl'] ?? '',
      serviceId: json['serviceId'] ?? json['targetServiceId'] ?? '',
      categoryId: json['categoryId'] ?? '',
      displayOrder: json['displayOrder'] ?? 0,
      autoSlide: json['autoSlide'] ?? true,
      slideDuration: json['slideDuration'] ?? 3000,
      startDate: json['startDate'] ?? '',
      endDate: json['endDate'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'subtitle': subtitle,
      'badgeText': badgeText,
      'ctaText': ctaText,
      'imageUrl': imageUrl,
      'serviceId': serviceId,
      'categoryId': categoryId,
      'displayOrder': displayOrder,
      'autoSlide': autoSlide,
      'slideDuration': slideDuration,
      'startDate': startDate,
      'endDate': endDate,
    };
  }
}
