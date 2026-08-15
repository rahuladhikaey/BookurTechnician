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
  final String name;
  final double price;
  final double rating;
  final int reviewsCount;
  final int durationMinutes;
  final String description;
  final String warrantyText;
  final List<String> inclusions;
  final List<String> exclusions;
  final List<MapEntry<String, String>> faqs;
  final String imageUrl;

  const ServiceItem({
    required this.id,
    required this.name,
    required this.price,
    this.rating = 4.8,
    this.reviewsCount = 120,
    this.durationMinutes = 45,
    this.description = '',
    this.warrantyText = '30 Days Warranty',
    this.inclusions = const [],
    this.exclusions = const [],
    this.faqs = const [],
    this.imageUrl = 'https://images.unsplash.com/photo-1621905251189-08b45d6a269e?w=500&auto=format&fit=crop',
  });
}

class Subcategory {
  final String id;
  final String name;
  final List<ServiceItem> services;
  const Subcategory({required this.id, required this.name, required this.services});
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
    required this.grandTotal,
    this.address = 'Flat 402, Royal Palms Residency, Bengaluru',
    this.technicianName = 'Rahul Sharma',
    this.technicianPhone = '+91 98765 43210',
    this.otpCode = '4821',
    this.addOns = const [],
  });

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
      otpCode: otpCode ?? this.otpCode,
      addOns: addOns ?? this.addOns,
    );
  }
}

// ─── Mock Data ──────────────────────────────────────────────────────────────

class MockData {
  static final List<Category> categoriesList = [
    Category(
      id: 'cat_ac',
      name: 'AC Service',
      imageUrl: 'https://images.unsplash.com/photo-1581094288338-2314dddb7eed?w=500&auto=format&fit=crop',
      subcategories: [
        Subcategory(id: 'sub_ac', name: 'AC Services', services: [
          ServiceItem(
            id: 'ac_install',
            name: 'New AC Installation',
            price: 1499,
            imageUrl: 'https://images.unsplash.com/photo-1621905252507-b354bc25edac?w=500&auto=format&fit=crop',
            description: 'Professional wall-mounted split or window AC installation.',
          ),
          ServiceItem(
            id: 'ac_clean',
            name: 'AC Cleaning',
            price: 599,
            imageUrl: 'https://images.unsplash.com/photo-1581094288338-2314dddb7eed?w=500&auto=format&fit=crop',
            description: 'Filter wash, coil check, and complete sanitation service.',
          ),
        ]),
      ],
    ),
    Category(
      id: 'cat_laptop',
      name: 'Laptop Service',
      imageUrl: 'https://images.unsplash.com/photo-1588872657578-7efd1f1555ed?w=500&auto=format&fit=crop',
      subcategories: [
        Subcategory(id: 'sub_laptop', name: 'Laptop Services', services: [
          ServiceItem(
            id: 'laptop_kbd',
            name: 'Keyboard Replacement',
            price: 1899,
            imageUrl: 'https://images.unsplash.com/photo-1595225476474-87563907a212?w=500&auto=format&fit=crop',
            description: 'Genuine keyboard replacement for Windows and MacBook.',
          ),
          ServiceItem(
            id: 'laptop_scr',
            name: 'Screen Replacement',
            price: 3499,
            imageUrl: 'https://images.unsplash.com/photo-1588872657578-7efd1f1555ed?w=500&auto=format&fit=crop',
            description: 'High-quality screen replacement with 6-month warranty.',
          ),
          ServiceItem(
            id: 'laptop_rep',
            name: 'Laptop Repair & Service',
            price: 999,
            imageUrl: 'https://images.unsplash.com/photo-1597872200319-381442461a61?w=500&auto=format&fit=crop',
            description: 'General OS cleaning, thermal paste refresh, and diagnostics.',
          ),
        ]),
      ],
    ),
    Category(
      id: 'cat_fan',
      name: 'Fan Service',
      imageUrl: 'https://images.unsplash.com/photo-1618943716616-e41c4d9ad1bd?w=500&auto=format&fit=crop',
      subcategories: [
        Subcategory(id: 'sub_fan', name: 'Fan Services', services: [
          ServiceItem(
            id: 'fan_install',
            name: 'New Fan Installation',
            price: 299,
            imageUrl: 'https://images.unsplash.com/photo-1618943716616-e41c4d9ad1bd?w=500&auto=format&fit=crop',
            description: 'Standard ceiling or wall fan assembly and installation.',
          ),
          ServiceItem(
            id: 'fan_clean',
            name: 'Fan Service & Cleaning',
            price: 149,
            imageUrl: 'https://images.unsplash.com/photo-1563245372-f21724e3856d?w=500&auto=format&fit=crop',
            description: 'Deep motor oiling, blade cleaning, and regulator check.',
          ),
        ]),
      ],
    ),
    Category(
      id: 'cat_refrigerator',
      name: 'Refrigerator Service',
      imageUrl: 'https://images.unsplash.com/photo-1571887455898-ac2865c3dc4e?w=500&auto=format&fit=crop',
      subcategories: [
        Subcategory(id: 'sub_refrigerator', name: 'Refrigerator Services', services: [
          ServiceItem(
            id: 'fridge_rep',
            name: 'Refrigerator Repair',
            price: 899,
            imageUrl: 'https://images.unsplash.com/photo-1571887455898-ac2865c3dc4e?w=500&auto=format&fit=crop',
            description: 'Fixing cooling issues, compressor faults, or gas leaks.',
          ),
          ServiceItem(
            id: 'fridge_clean',
            name: 'Refrigerator Cleaning & Service',
            price: 599,
            imageUrl: 'https://images.unsplash.com/photo-1584622650111-993a426fbf0a?w=500&auto=format&fit=crop',
            description: 'Sanitization, tray wash, and complete coils cleaning.',
          ),
        ]),
      ],
    ),
    Category(
      id: 'cat_washing',
      name: 'Washing Machine Service',
      imageUrl: 'https://images.unsplash.com/photo-1582730147233-a3d82a170562?w=500&auto=format&fit=crop',
      subcategories: [
        Subcategory(id: 'sub_washing', name: 'Washing Machine Services', services: [
          ServiceItem(
            id: 'washing_rep',
            name: 'Washing Machine Repair',
            price: 999,
            imageUrl: 'https://images.unsplash.com/photo-1582730147233-a3d82a170562?w=500&auto=format&fit=crop',
            description: 'Fixing drum rotation issues, water leaks, or control board errors.',
          ),
          ServiceItem(
            id: 'washing_clean',
            name: 'Washing Machine Service',
            price: 699,
            imageUrl: 'https://images.unsplash.com/photo-1610557892470-76d74002fa5e?w=500&auto=format&fit=crop',
            description: 'Complete scaling removal and high-temp interior wash.',
          ),
        ]),
      ],
    ),
    Category(
      id: 'cat_light',
      name: 'Light Service',
      imageUrl: 'https://images.unsplash.com/photo-1565814636199-ae8133055c1c?w=500&auto=format&fit=crop',
      subcategories: [
        Subcategory(id: 'sub_light', name: 'Light Services', services: [
          ServiceItem(
            id: 'light_install',
            name: 'Light Installation',
            price: 199,
            imageUrl: 'https://images.unsplash.com/photo-1565814636199-ae8133055c1c?w=500&auto=format&fit=crop',
            description: 'Installing standard bulbs, decorative lights, or chandeliers.',
          ),
          ServiceItem(
            id: 'light_rep',
            name: 'Light Repair',
            price: 99,
            imageUrl: 'https://images.unsplash.com/photo-1550985616-10810253b84d?w=500&auto=format&fit=crop',
            description: 'Fixing bad sockets, holder replacements, and short circuits.',
          ),
          ServiceItem(
            id: 'light_led',
            name: 'LED/Tube Light Service',
            price: 149,
            imageUrl: 'https://images.unsplash.com/photo-1567427017947-545c5f8996ac?w=500&auto=format&fit=crop',
            description: 'Tube light choke, starter, or LED strip replacement.',
          ),
        ]),
      ],
    ),
  ];

  static final List<ServiceItem> popularServicesList = [
    const ServiceItem(
      id: 'pop_wiring',
      name: 'Full Home Wiring',
      price: 4999,
      imageUrl: 'https://images.unsplash.com/photo-1621905251189-08b45d6a269e?w=500&auto=format&fit=crop',
      description: 'Complete electrical wiring overhaul with safety certification.',
    ),
    const ServiceItem(
      id: 'pop_inspect',
      name: 'Electrical Inspection',
      price: 499,
      imageUrl: 'https://images.unsplash.com/photo-1581092921461-eab62e97a780?w=500&auto=format&fit=crop',
      description: 'Full inspection of panels, grounding, and power points.',
    ),
    const ServiceItem(
      id: 'pop_socket',
      name: 'Switch & Socket Installation',
      price: 249,
      imageUrl: 'https://images.unsplash.com/photo-1558223131-49193b8ae351?w=500&auto=format&fit=crop',
      description: 'Safe replacement or new mounting of switchboards.',
    ),
    const ServiceItem(
      id: 'pop_fault',
      name: 'Electrical Fault Repair',
      price: 399,
      imageUrl: 'https://images.unsplash.com/photo-1581092160607-ee22621dd758?w=500&auto=format&fit=crop',
      description: 'Locating and fixing short circuits, trips, and fluctuations.',
    ),
    const ServiceItem(
      id: 'pop_install',
      name: 'New Electrical Installation',
      price: 799,
      imageUrl: 'https://images.unsplash.com/photo-1621905252507-b354bc25edac?w=500&auto=format&fit=crop',
      description: 'Installing and wiring distribution boards, MCBs, or heavy appliances.',
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
