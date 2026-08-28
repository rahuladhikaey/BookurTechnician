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
  final double basePrice;
  final double offerPrice;
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

  const ServiceItem({
    required this.id,
    required this.name,
    required this.price,
    this.basePrice = 0.0,
    this.offerPrice = 0.0,
    this.bookingCharge = 49.0,
    this.advancePrepaymentPct = 30,
    this.technicianPayoutAmount = 0.0,
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

  factory ServiceItem.fromJson(Map<String, dynamic> json) {
    final rawPrice = (json['price'] as num?)?.toDouble() ?? (json['basePrice'] as num?)?.toDouble() ?? 0.0;
    final rawBase = (json['basePrice'] as num?)?.toDouble() ?? rawPrice;
    final rawOffer = (json['offerPrice'] as num?)?.toDouble() ?? rawPrice;
    final rawBooking = (json['bookingCharge'] as num?)?.toDouble() ?? (rawPrice >= 1000 ? 99.0 : 49.0);
    final rawPct = json['advancePrepaymentPct'] as int? ?? 30;
    final rawPayout = (json['technicianPayoutAmount'] as num?)?.toDouble() ?? (rawPrice * 0.8);

    return ServiceItem(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? json['title']?.toString() ?? '',
      price: rawPrice,
      basePrice: rawBase,
      offerPrice: rawOffer,
      bookingCharge: rawBooking,
      advancePrepaymentPct: rawPct,
      technicianPayoutAmount: rawPayout,
      durationMinutes: json['durationMinutes'] as int? ?? (json['estimatedDurationMinutes'] as int?) ?? 45,
      warrantyText: json['warrantyText']?.toString() ?? '30 Days Warranty',
      description: json['description']?.toString() ?? '',
      imageUrl: json['imageUrl']?.toString() ?? 'https://images.unsplash.com/photo-1621905251189-08b45d6a269e?w=500&auto=format&fit=crop',
    );
  }
}

class Subcategory {
  final String id;
  final String name;
  final List<ServiceItem> services;
  const Subcategory({required this.id, required this.name, required this.services});

  factory Subcategory.fromJson(Map<String, dynamic> json) {
    return Subcategory(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      services: (json['services'] as List?)?.map((s) => ServiceItem.fromJson(s as Map<String, dynamic>)).toList() ?? [],
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
    this.otpCode = '',
    this.addOns = const [],
  });

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
                        (json['grandTotal'] as num?)?.toDouble() ?? 0.0;

    final rawGrandTotal = (json['grandTotal'] as num?)?.toDouble() ?? 
                          (json['totalAmount'] as num?)?.toDouble() ?? 
                          rawBaseCost;

    final rawVisitFee = (json['visitFee'] as num?)?.toDouble() ?? 
                        (json['safetyFee'] as num?)?.toDouble() ?? 49.0;

    final rawGst = (json['gstTax'] as num?)?.toDouble() ?? 
                   (json['gstAmount'] as num?)?.toDouble() ?? 
                   (rawBaseCost * 0.18);

    final rawDiscount = (json['discount'] as num?)?.toDouble() ?? 0.0;

    final sName = json['serviceName']?.toString() ?? 
                  (json['services'] is List && (json['services'] as List).isNotEmpty ? ((json['services'] as List)[0]['name']?.toString() ?? 'Service') : 'Technician Service');
    final sId = json['serviceId']?.toString() ?? 
                (json['services'] is List && (json['services'] as List).isNotEmpty ? ((json['services'] as List)[0]['id']?.toString() ?? 'serv_1') : 'serv_1');

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
      technicianName: json['technicianName']?.toString() ?? '',
      technicianPhone: json['technicianPhone']?.toString() ?? '',
      otpCode: json['startServiceOtp']?.toString() ?? json['startOtp']?.toString() ?? json['otpCode']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'bookingCode': id,
      'serviceId': services.isNotEmpty ? services.first.id : '',
      'serviceName': services.isNotEmpty ? services.map((s) => s.name).join(', ') : '',
      'services': services.map((s) => {
        'id': s.id,
        'name': s.name,
        'price': s.price,
      }).toList(),
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
    // 1. ⚡ Electrical Services
    Category(
      id: 'cat_electrical',
      name: 'Electrical Services',
      imageUrl: 'https://images.unsplash.com/photo-1621905252507-b354bc25edac?w=500&auto=format&fit=crop',
      subcategories: [
        Subcategory(id: 'sub_fan', name: 'Fan Services', services: [
          ServiceItem(
            id: 'fan_rep',
            name: 'Fan repair',
            price: 149,
            durationMinutes: 30,
            imageUrl: 'https://images.unsplash.com/photo-1618943716616-e41c4d9ad1bd?w=500&auto=format&fit=crop',
            description: 'Fixing blade speed, capacitor, winding, or noise issues.',
          ),
          ServiceItem(
            id: 'fan_install',
            name: 'Fan installation',
            price: 199,
            durationMinutes: 35,
            imageUrl: 'https://images.unsplash.com/photo-1618943716616-e41c4d9ad1bd?w=500&auto=format&fit=crop',
            description: 'Standard fan mounting and secure hook installation.',
          ),
          ServiceItem(
            id: 'fan_ceiling_install',
            name: 'Ceiling fan installation',
            price: 249,
            durationMinutes: 40,
            imageUrl: 'https://images.unsplash.com/photo-1563245372-f21724e3856d?w=500&auto=format&fit=crop',
            description: 'Ceiling assembly, rod fitting, downrod check, and balancing.',
          ),
          ServiceItem(
            id: 'fan_exhaust_install',
            name: 'Exhaust fan installation',
            price: 199,
            durationMinutes: 35,
            imageUrl: 'https://images.unsplash.com/photo-1618943716616-e41c4d9ad1bd?w=500&auto=format&fit=crop',
            description: 'Kitchen and bathroom exhaust fan fitting and connection.',
          ),
        ]),
        Subcategory(id: 'sub_switch_socket', name: 'Switch & Socket', services: [
          ServiceItem(
            id: 'switch_rep',
            name: 'Switch repair',
            price: 99,
            durationMinutes: 20,
            imageUrl: 'https://images.unsplash.com/photo-1558223131-49193b8ae351?w=500&auto=format&fit=crop',
            description: 'Fixing loose, spark, or non-working electrical switches.',
          ),
          ServiceItem(
            id: 'socket_rep',
            name: 'Socket repair',
            price: 99,
            durationMinutes: 20,
            imageUrl: 'https://images.unsplash.com/photo-1558223131-49193b8ae351?w=500&auto=format&fit=crop',
            description: 'Repairing power sockets, 3-pin plugs, and loose points.',
          ),
          ServiceItem(
            id: 'switchboard_rep',
            name: 'Switchboard repair',
            price: 199,
            durationMinutes: 35,
            imageUrl: 'https://images.unsplash.com/photo-1558223131-49193b8ae351?w=500&auto=format&fit=crop',
            description: 'Internal board rewiring, sparking repair, and modular fixing.',
          ),
        ]),
        Subcategory(id: 'sub_lighting', name: 'Lighting Solutions', services: [
          ServiceItem(
            id: 'light_rep',
            name: 'Light repair',
            price: 99,
            durationMinutes: 20,
            imageUrl: 'https://images.unsplash.com/photo-1550985616-10810253b84d?w=500&auto=format&fit=crop',
            description: 'Troubleshooting dim, flickering, or dead light fixtures.',
          ),
          ServiceItem(
            id: 'light_install',
            name: 'Light installation',
            price: 149,
            durationMinutes: 25,
            imageUrl: 'https://images.unsplash.com/photo-1565814636199-ae8133055c1c?w=500&auto=format&fit=crop',
            description: 'Installing wall lamps, brackets, and bulb fixtures.',
          ),
          ServiceItem(
            id: 'led_install',
            name: 'LED light installation',
            price: 149,
            durationMinutes: 25,
            imageUrl: 'https://images.unsplash.com/photo-1567427017947-545c5f8996ac?w=500&auto=format&fit=crop',
            description: 'Ceiling LED panel, concealed COB, or strip light mounting.',
          ),
          ServiceItem(
            id: 'tubelight_svc',
            name: 'Tube light installation/repair',
            price: 129,
            durationMinutes: 25,
            imageUrl: 'https://images.unsplash.com/photo-1567427017947-545c5f8996ac?w=500&auto=format&fit=crop',
            description: 'Batten tube light fitting, choke, or driver replacement.',
          ),
          ServiceItem(
            id: 'decorative_light_install',
            name: 'Decorative light installation',
            price: 299,
            durationMinutes: 45,
            imageUrl: 'https://images.unsplash.com/photo-1565814636199-ae8133055c1c?w=500&auto=format&fit=crop',
            description: 'Chandelier, festive lights, wall art lights, and track lighting.',
          ),
        ]),
        Subcategory(id: 'sub_mcb_protection', name: 'MCB, Fuse & Safety', services: [
          ServiceItem(
            id: 'mcb_rep',
            name: 'MCB repair/replacement',
            price: 199,
            durationMinutes: 30,
            imageUrl: 'https://images.unsplash.com/photo-1581092160607-ee22621dd758?w=500&auto=format&fit=crop',
            description: 'Replacing tripped or burning single/double-pole MCB.',
          ),
          ServiceItem(
            id: 'fuse_rep',
            name: 'Fuse repair',
            price: 99,
            durationMinutes: 20,
            imageUrl: 'https://images.unsplash.com/photo-1581092160607-ee22621dd758?w=500&auto=format&fit=crop',
            description: 'Rewiring or replacement of blown ceramic/cartridge fuses.',
          ),
          ServiceItem(
            id: 'rccb_install',
            name: 'RCCB/ELCB installation',
            price: 399,
            durationMinutes: 45,
            imageUrl: 'https://images.unsplash.com/photo-1581092160607-ee22621dd758?w=500&auto=format&fit=crop',
            description: 'Earth leakage circuit breaker installation for shock prevention.',
          ),
          ServiceItem(
            id: 'short_circuit_fix',
            name: 'Short-circuit troubleshooting',
            price: 349,
            durationMinutes: 45,
            imageUrl: 'https://images.unsplash.com/photo-1581092160607-ee22621dd758?w=500&auto=format&fit=crop',
            description: 'Tracing line shorts, burning smell diagnosis, and isolation.',
          ),
          ServiceItem(
            id: 'elec_fault_diag',
            name: 'Electrical fault diagnosis',
            price: 299,
            durationMinutes: 40,
            imageUrl: 'https://images.unsplash.com/photo-1581092921461-eab62e97a780?w=500&auto=format&fit=crop',
            description: 'Complete multi-meter voltage, phase, and ground diagnostic.',
          ),
        ]),
        Subcategory(id: 'sub_appliance_connection', name: 'Appliance Connections', services: [
          ServiceItem(
            id: 'doorbell_svc',
            name: 'Doorbell installation/repair',
            price: 149,
            durationMinutes: 25,
            imageUrl: 'https://images.unsplash.com/photo-1558223131-49193b8ae351?w=500&auto=format&fit=crop',
            description: 'Wired or wireless doorbell chime fitting and wiring.',
          ),
          ServiceItem(
            id: 'geyser_connection',
            name: 'Geyser electrical connection',
            price: 249,
            durationMinutes: 30,
            imageUrl: 'https://images.unsplash.com/photo-1581092160607-ee22621dd758?w=500&auto=format&fit=crop',
            description: 'Heavy duty 16A/20A socket and DP switch wiring for geyser.',
          ),
          ServiceItem(
            id: 'inverter_rep',
            name: 'Inverter installation/repair',
            price: 499,
            durationMinutes: 60,
            imageUrl: 'https://images.unsplash.com/photo-1621905251189-08b45d6a269e?w=500&auto=format&fit=crop',
            description: 'Inverter & battery setup, charging calibration, and backup check.',
          ),
          ServiceItem(
            id: 'stabilizer_install',
            name: 'Stabilizer installation',
            price: 249,
            durationMinutes: 30,
            imageUrl: 'https://images.unsplash.com/photo-1581092160607-ee22621dd758?w=500&auto=format&fit=crop',
            description: 'AC, fridge, or mainline voltage stabilizer connection.',
          ),
          ServiceItem(
            id: 'appliance_connect',
            name: 'Electrical appliance connection',
            price: 199,
            durationMinutes: 30,
            imageUrl: 'https://images.unsplash.com/photo-1581092160607-ee22621dd758?w=500&auto=format&fit=crop',
            description: 'Safe high-load electrical connection for home appliances.',
          ),
        ]),
      ],
    ),

    // 2. 🏠 Home Wiring & Electrical Projects
    Category(
      id: 'cat_wiring',
      name: 'Home Wiring & Projects',
      imageUrl: 'https://images.unsplash.com/photo-1621905251189-08b45d6a269e?w=500&auto=format&fit=crop',
      subcategories: [
        Subcategory(id: 'sub_complete_wiring', name: 'Complete Home Wiring', services: [
          ServiceItem(
            id: 'house_wiring_new',
            name: 'New house complete wiring',
            price: 14999,
            durationMinutes: 480,
            imageUrl: 'https://images.unsplash.com/photo-1621905251189-08b45d6a269e?w=500&auto=format&fit=crop',
            description: 'End-to-end multi-room wiring with conduits, boxes, and testing.',
          ),
          ServiceItem(
            id: 'flat_wiring',
            name: 'Flat complete wiring',
            price: 8999,
            durationMinutes: 360,
            imageUrl: 'https://images.unsplash.com/photo-1621905251189-08b45d6a269e?w=500&auto=format&fit=crop',
            description: '1BHK/2BHK/3BHK complete electrical distribution and wiring.',
          ),
          ServiceItem(
            id: 'room_wiring',
            name: 'Room wiring',
            price: 1999,
            durationMinutes: 120,
            imageUrl: 'https://images.unsplash.com/photo-1621905251189-08b45d6a269e?w=500&auto=format&fit=crop',
            description: 'Dedicated single bedroom or living area wiring from main DB.',
          ),
          ServiceItem(
            id: 'kitchen_wiring',
            name: 'Kitchen wiring',
            price: 1499,
            durationMinutes: 90,
            imageUrl: 'https://images.unsplash.com/photo-1556911220-e15b29be8c8f?w=500&auto=format&fit=crop',
            description: 'High load wiring for microwave, chimney, induction, and fridge.',
          ),
          ServiceItem(
            id: 'bathroom_wiring',
            name: 'Bathroom wiring',
            price: 999,
            durationMinutes: 60,
            imageUrl: 'https://images.unsplash.com/photo-1584622650111-993a426fbf0a?w=500&auto=format&fit=crop',
            description: 'Moisture-proof wiring for geyser, mirror lights, and exhaust.',
          ),
          ServiceItem(
            id: 'shop_wiring',
            name: 'Commercial shop wiring',
            price: 6999,
            durationMinutes: 240,
            imageUrl: 'https://images.unsplash.com/photo-1621905251189-08b45d6a269e?w=500&auto=format&fit=crop',
            description: 'Showroom and retail shop lighting and point distribution.',
          ),
          ServiceItem(
            id: 'office_wiring',
            name: 'Office wiring',
            price: 9999,
            durationMinutes: 300,
            imageUrl: 'https://images.unsplash.com/photo-1621905251189-08b45d6a269e?w=500&auto=format&fit=crop',
            description: 'Workstation UPS, server rack, and office lighting layout.',
          ),
        ]),
        Subcategory(id: 'sub_electrical_installation', name: 'Electrical Installation', services: [
          ServiceItem(
            id: 'new_switchboard_install',
            name: 'New switchboard installation',
            price: 299,
            durationMinutes: 45,
            imageUrl: 'https://images.unsplash.com/photo-1558223131-49193b8ae351?w=500&auto=format&fit=crop',
            description: 'Cutting, box embedding, modular board mounting and wiring.',
          ),
          ServiceItem(
            id: 'db_install',
            name: 'Distribution board installation',
            price: 999,
            durationMinutes: 90,
            imageUrl: 'https://images.unsplash.com/photo-1581092160607-ee22621dd758?w=500&auto=format&fit=crop',
            description: 'Main sub-distribution board setup with busbar and circuit tags.',
          ),
          ServiceItem(
            id: 'mcb_box_install',
            name: 'MCB box installation',
            price: 599,
            durationMinutes: 60,
            imageUrl: 'https://images.unsplash.com/photo-1581092160607-ee22621dd758?w=500&auto=format&fit=crop',
            description: '4-way to 12-way MCB enclosure installation and dressing.',
          ),
          ServiceItem(
            id: 'main_panel_install',
            name: 'Main electrical panel installation',
            price: 1999,
            durationMinutes: 180,
            imageUrl: 'https://images.unsplash.com/photo-1581092160607-ee22621dd758?w=500&auto=format&fit=crop',
            description: 'Heavy duty commercial or multi-floor main electrical panel setup.',
          ),
          ServiceItem(
            id: 'meter_board_prep',
            name: 'Meter board preparation',
            price: 899,
            durationMinutes: 90,
            imageUrl: 'https://images.unsplash.com/photo-1581092160607-ee22621dd758?w=500&auto=format&fit=crop',
            description: 'Electric supply meter board setup complying with electricity board.',
          ),
          ServiceItem(
            id: 'earthing_install',
            name: 'Earthing installation',
            price: 1499,
            durationMinutes: 120,
            imageUrl: 'https://images.unsplash.com/photo-1621905251189-08b45d6a269e?w=500&auto=format&fit=crop',
            description: 'Chemical earthing / copper rod pit for total shock & surge safety.',
          ),
          ServiceItem(
            id: 'load_distribution',
            name: 'Electrical load distribution',
            price: 799,
            durationMinutes: 60,
            imageUrl: 'https://images.unsplash.com/photo-1581092921461-eab62e97a780?w=500&auto=format&fit=crop',
            description: 'Balancing loads between phases to prevent tripping and overheated wires.',
          ),
        ]),
        Subcategory(id: 'sub_wiring_repair', name: 'Wiring Repair & Upgrade', services: [
          ServiceItem(
            id: 'old_house_rewiring',
            name: 'Old house rewiring',
            price: 4999,
            durationMinutes: 240,
            imageUrl: 'https://images.unsplash.com/photo-1621905251189-08b45d6a269e?w=500&auto=format&fit=crop',
            description: 'Replacing aged wires with high-grade fire retardant cables.',
          ),
          ServiceItem(
            id: 'damaged_wire_replace',
            name: 'Damaged wire replacement',
            price: 399,
            durationMinutes: 45,
            imageUrl: 'https://images.unsplash.com/photo-1581092160607-ee22621dd758?w=500&auto=format&fit=crop',
            description: 'Pulling new wires through conduits to replace burnt sections.',
          ),
          ServiceItem(
            id: 'concealed_wiring_repair',
            name: 'Concealed wiring repair',
            price: 699,
            durationMinutes: 90,
            imageUrl: 'https://images.unsplash.com/photo-1621905251189-08b45d6a269e?w=500&auto=format&fit=crop',
            description: 'Locating in-wall broken circuits without excessive plaster damage.',
          ),
          ServiceItem(
            id: 'open_wiring_install',
            name: 'Open wiring installation',
            price: 499,
            durationMinutes: 60,
            imageUrl: 'https://images.unsplash.com/photo-1621905251189-08b45d6a269e?w=500&auto=format&fit=crop',
            description: 'Neat casing-capping surface wiring for rental or new rooms.',
          ),
          ServiceItem(
            id: 'wire_extension',
            name: 'Wire extension',
            price: 249,
            durationMinutes: 30,
            imageUrl: 'https://images.unsplash.com/photo-1558223131-49193b8ae351?w=500&auto=format&fit=crop',
            description: 'Extending electrical line to balconies, terraces, or garden areas.',
          ),
          ServiceItem(
            id: 'power_point_install',
            name: 'Power point installation',
            price: 299,
            durationMinutes: 40,
            imageUrl: 'https://images.unsplash.com/photo-1558223131-49193b8ae351?w=500&auto=format&fit=crop',
            description: 'Installing dedicated 16A/20A power plugs for heavy appliances.',
          ),
          ServiceItem(
            id: 'new_socket_point',
            name: 'New socket point installation',
            price: 199,
            durationMinutes: 30,
            imageUrl: 'https://images.unsplash.com/photo-1558223131-49193b8ae351?w=500&auto=format&fit=crop',
            description: 'Adding an extra wall socket point next to desk or bed.',
          ),
          ServiceItem(
            id: 'new_switch_point',
            name: 'New switch point installation',
            price: 149,
            durationMinutes: 25,
            imageUrl: 'https://images.unsplash.com/photo-1558223131-49193b8ae351?w=500&auto=format&fit=crop',
            description: 'Connecting an additional switch for fan, lamp, or appliance.',
          ),
        ]),
        Subcategory(id: 'sub_special_electrical', name: 'Special Electrical Work', services: [
          ServiceItem(
            id: 'three_phase_wiring',
            name: 'Three-phase wiring',
            price: 3499,
            durationMinutes: 180,
            imageUrl: 'https://images.unsplash.com/photo-1581092160607-ee22621dd758?w=500&auto=format&fit=crop',
            description: '415V three-phase commercial and residential power setup.',
          ),
          ServiceItem(
            id: 'single_phase_wiring',
            name: 'Single-phase wiring',
            price: 1499,
            durationMinutes: 90,
            imageUrl: 'https://images.unsplash.com/photo-1581092160607-ee22621dd758?w=500&auto=format&fit=crop',
            description: 'Standard 230V domestic supply wiring and breaker protection.',
          ),
          ServiceItem(
            id: 'generator_connect',
            name: 'Generator connection',
            price: 799,
            durationMinutes: 60,
            imageUrl: 'https://images.unsplash.com/photo-1621905251189-08b45d6a269e?w=500&auto=format&fit=crop',
            description: 'Manual or automatic changeover switch installation for genset.',
          ),
          ServiceItem(
            id: 'inverter_wiring',
            name: 'Inverter wiring',
            price: 599,
            durationMinutes: 60,
            imageUrl: 'https://images.unsplash.com/photo-1621905251189-08b45d6a269e?w=500&auto=format&fit=crop',
            description: 'Separating inverter line circuits across rooms.',
          ),
          ServiceItem(
            id: 'ups_wiring',
            name: 'UPS wiring',
            price: 499,
            durationMinutes: 45,
            imageUrl: 'https://images.unsplash.com/photo-1588872657578-7efd1f1555ed?w=500&auto=format&fit=crop',
            description: 'Dedicated noise-free power line for computers and work setups.',
          ),
          ServiceItem(
            id: 'safety_inspect',
            name: 'Electrical safety inspection',
            price: 499,
            durationMinutes: 45,
            imageUrl: 'https://images.unsplash.com/photo-1581092921461-eab62e97a780?w=500&auto=format&fit=crop',
            description: 'Full audit of grounding, insulation resistance, and hazard prevention.',
          ),
          ServiceItem(
            id: 'load_calc',
            name: 'Load calculation',
            price: 399,
            durationMinutes: 35,
            imageUrl: 'https://images.unsplash.com/photo-1581092921461-eab62e97a780?w=500&auto=format&fit=crop',
            description: 'Wattage and amperage calculation for meter upgrade or solar install.',
          ),
          ServiceItem(
            id: 'fault_inspect',
            name: 'Electrical fault inspection',
            price: 349,
            durationMinutes: 40,
            imageUrl: 'https://images.unsplash.com/photo-1581092160607-ee22621dd758?w=500&auto=format&fit=crop',
            description: 'Expert inspection for intermittent trips, high bill causes, and earthing faults.',
          ),
        ]),
      ],
    ),

    // 3. ❄️ AC Services
    Category(
      id: 'cat_ac',
      name: 'AC Services',
      imageUrl: 'https://images.unsplash.com/photo-1581094288338-2314dddb7eed?w=500&auto=format&fit=crop',
      subcategories: [
        Subcategory(id: 'sub_ac_install_service', name: 'Installation & Servicing', services: [
          ServiceItem(
            id: 'ac_install',
            name: 'AC installation',
            price: 1299,
            durationMinutes: 90,
            imageUrl: 'https://images.unsplash.com/photo-1621905252507-b354bc25edac?w=500&auto=format&fit=crop',
            description: 'Split or window AC installation with precision bracket leveling.',
          ),
          ServiceItem(
            id: 'ac_uninstall',
            name: 'AC uninstallation',
            price: 699,
            durationMinutes: 45,
            imageUrl: 'https://images.unsplash.com/photo-1581094288338-2314dddb7eed?w=500&auto=format&fit=crop',
            description: 'Safe gas lock and indoor/outdoor unit unmounting.',
          ),
          ServiceItem(
            id: 'ac_general_service',
            name: 'AC general servicing',
            price: 499,
            durationMinutes: 45,
            imageUrl: 'https://images.unsplash.com/photo-1581094288338-2314dddb7eed?w=500&auto=format&fit=crop',
            description: 'Filter wash, cooling coil brushing, drain tray cleaning.',
          ),
          ServiceItem(
            id: 'ac_deep_cleaning',
            name: 'Deep cleaning service',
            price: 799,
            durationMinutes: 60,
            imageUrl: 'https://images.unsplash.com/photo-1581094288338-2314dddb7eed?w=500&auto=format&fit=crop',
            description: 'Foam jet high-pressure wash for indoor and outdoor units.',
          ),
          ServiceItem(
            id: 'ac_relocation',
            name: 'AC relocation',
            price: 1699,
            durationMinutes: 120,
            imageUrl: 'https://images.unsplash.com/photo-1621905252507-b354bc25edac?w=500&auto=format&fit=crop',
            description: 'Complete uninstallation, transport packing, and reinstall.',
          ),
        ]),
        Subcategory(id: 'sub_ac_repairs', name: 'Repair & Troubleshooting', services: [
          ServiceItem(
            id: 'ac_repair_general',
            name: 'AC repair',
            price: 399,
            durationMinutes: 45,
            imageUrl: 'https://images.unsplash.com/photo-1581094288338-2314dddb7eed?w=500&auto=format&fit=crop',
            description: 'Diagnosis and fixing of all AC mechanical or electrical issues.',
          ),
          ServiceItem(
            id: 'ac_cooling_problem',
            name: 'AC cooling problem',
            price: 499,
            durationMinutes: 45,
            imageUrl: 'https://images.unsplash.com/photo-1581094288338-2314dddb7eed?w=500&auto=format&fit=crop',
            description: 'Resolving low airflow, warm air blowing, or slow cooling.',
          ),
          ServiceItem(
            id: 'ac_gas_charging',
            name: 'AC gas charging/refilling',
            price: 1899,
            durationMinutes: 60,
            imageUrl: 'https://images.unsplash.com/photo-1581094288338-2314dddb7eed?w=500&auto=format&fit=crop',
            description: 'Nitrogen leak test, vacuuming, and 100% genuine refrigerant refill.',
          ),
          ServiceItem(
            id: 'ac_water_leakage',
            name: 'AC water leakage repair',
            price: 399,
            durationMinutes: 35,
            imageUrl: 'https://images.unsplash.com/photo-1581094288338-2314dddb7eed?w=500&auto=format&fit=crop',
            description: 'Clearing clogged drain pipe, tray alignment, and ice buildup.',
          ),
          ServiceItem(
            id: 'ac_pcb_repair',
            name: 'AC PCB repair',
            price: 999,
            durationMinutes: 60,
            imageUrl: 'https://images.unsplash.com/photo-1581092160607-ee22621dd758?w=500&auto=format&fit=crop',
            description: 'Inverter motherboard repair, display board fixing, and sensor reset.',
          ),
          ServiceItem(
            id: 'ac_electrical_repair',
            name: 'AC electrical repair',
            price: 349,
            durationMinutes: 40,
            imageUrl: 'https://images.unsplash.com/photo-1581092160607-ee22621dd758?w=500&auto=format&fit=crop',
            description: 'Capacitor replacement, contactor fixing, and wiring overhaul.',
          ),
          ServiceItem(
            id: 'ac_compressor_issue',
            name: 'AC compressor issue',
            price: 1499,
            durationMinutes: 90,
            imageUrl: 'https://images.unsplash.com/photo-1581094288338-2314dddb7eed?w=500&auto=format&fit=crop',
            description: 'Compressor tripping, starting relay, and pump replacement.',
          ),
          ServiceItem(
            id: 'ac_noise_vibration',
            name: 'AC noise/vibration issue',
            price: 399,
            durationMinutes: 35,
            imageUrl: 'https://images.unsplash.com/photo-1581094288338-2314dddb7eed?w=500&auto=format&fit=crop',
            description: 'Blower fan balancing, motor bush oiling, and dampener installation.',
          ),
          ServiceItem(
            id: 'ac_remote_sensor',
            name: 'AC remote/sensor issue',
            price: 249,
            durationMinutes: 25,
            imageUrl: 'https://images.unsplash.com/photo-1581094288338-2314dddb7eed?w=500&auto=format&fit=crop',
            description: 'IR receiver repair, sensor replacement, and remote pairing.',
          ),
          ServiceItem(
            id: 'ac_outdoor_repair',
            name: 'AC outdoor unit repair',
            price: 599,
            durationMinutes: 60,
            imageUrl: 'https://images.unsplash.com/photo-1581094288338-2314dddb7eed?w=500&auto=format&fit=crop',
            description: 'Fan motor fixing, condenser coil cleaning, and valve repair.',
          ),
          ServiceItem(
            id: 'outdoor_mounting',
            name: 'Outdoor unit mounting',
            price: 499,
            durationMinutes: 45,
            imageUrl: 'https://images.unsplash.com/photo-1581094288338-2314dddb7eed?w=500&auto=format&fit=crop',
            description: 'Heavy duty rust-proof wall bracket installation.',
          ),
          ServiceItem(
            id: 'copper_pipe_install',
            name: 'Copper pipe installation',
            price: 799,
            durationMinutes: 60,
            imageUrl: 'https://images.unsplash.com/photo-1581094288338-2314dddb7eed?w=500&auto=format&fit=crop',
            description: 'Insulated copper tubing with flare nuts per running meter.',
          ),
        ]),
      ],
    ),

    // 4. 🧊 Refrigerator Services
    Category(
      id: 'cat_refrigerator',
      name: 'Refrigerator Services',
      imageUrl: 'https://images.unsplash.com/photo-1571887455898-ac2865c3dc4e?w=500&auto=format&fit=crop',
      subcategories: [
        Subcategory(id: 'sub_fridge_repair', name: 'Refrigerator Repair & Maintenance', services: [
          ServiceItem(
            id: 'fridge_general_rep',
            name: 'Refrigerator general repair',
            price: 399,
            durationMinutes: 45,
            imageUrl: 'https://images.unsplash.com/photo-1571887455898-ac2865c3dc4e?w=500&auto=format&fit=crop',
            description: 'Complete inspection and minor fixes for single & double door fridges.',
          ),
          ServiceItem(
            id: 'fridge_cooling_problem',
            name: 'Cooling problem',
            price: 499,
            durationMinutes: 45,
            imageUrl: 'https://images.unsplash.com/photo-1571887455898-ac2865c3dc4e?w=500&auto=format&fit=crop',
            description: 'Troubleshooting low cooling in bottom or top freezer compartment.',
          ),
          ServiceItem(
            id: 'fridge_gas_charging',
            name: 'Gas charging',
            price: 1499,
            durationMinutes: 60,
            imageUrl: 'https://images.unsplash.com/photo-1571887455898-ac2865c3dc4e?w=500&auto=format&fit=crop',
            description: 'Leak identification, capillary tube flushing, and gas refill.',
          ),
          ServiceItem(
            id: 'fridge_compressor_issue',
            name: 'Compressor issue',
            price: 1299,
            durationMinutes: 75,
            imageUrl: 'https://images.unsplash.com/photo-1571887455898-ac2865c3dc4e?w=500&auto=format&fit=crop',
            description: 'Relay replacement, OLP fixing, or new compressor installation.',
          ),
          ServiceItem(
            id: 'fridge_thermostat_rep',
            name: 'Thermostat repair',
            price: 449,
            durationMinutes: 35,
            imageUrl: 'https://images.unsplash.com/photo-1571887455898-ac2865c3dc4e?w=500&auto=format&fit=crop',
            description: 'Replacing faulty temperature sensor or mechanical thermostat.',
          ),
          ServiceItem(
            id: 'fridge_water_leakage',
            name: 'Water leakage',
            price: 349,
            durationMinutes: 30,
            imageUrl: 'https://images.unsplash.com/photo-1584622650111-993a426fbf0a?w=500&auto=format&fit=crop',
            description: 'Unclogging defrost drain hole and defrost heater check.',
          ),
          ServiceItem(
            id: 'fridge_door_seal_rep',
            name: 'Door/seal repair',
            price: 299,
            durationMinutes: 30,
            imageUrl: 'https://images.unsplash.com/photo-1571887455898-ac2865c3dc4e?w=500&auto=format&fit=crop',
            description: 'Magnetic gasket rubber seal replacement and door hinge adjustment.',
          ),
          ServiceItem(
            id: 'fridge_not_starting',
            name: 'Refrigerator not starting',
            price: 399,
            durationMinutes: 35,
            imageUrl: 'https://images.unsplash.com/photo-1571887455898-ac2865c3dc4e?w=500&auto=format&fit=crop',
            description: 'Power cord, thermal fuse, or inverter board diagnostics.',
          ),
          ServiceItem(
            id: 'fridge_excessive_cooling',
            name: 'Excessive cooling/freezing',
            price: 349,
            durationMinutes: 35,
            imageUrl: 'https://images.unsplash.com/photo-1571887455898-ac2865c3dc4e?w=500&auto=format&fit=crop',
            description: 'Fixing ice buildup in vegetable tray and thermostat over-cycling.',
          ),
          ServiceItem(
            id: 'fridge_pcb_rep',
            name: 'PCB/electrical repair',
            price: 899,
            durationMinutes: 60,
            imageUrl: 'https://images.unsplash.com/photo-1581092160607-ee22621dd758?w=500&auto=format&fit=crop',
            description: 'Inverter control circuit board diagnostics and soldering.',
          ),
          ServiceItem(
            id: 'fridge_installation',
            name: 'Refrigerator installation',
            price: 299,
            durationMinutes: 30,
            imageUrl: 'https://images.unsplash.com/photo-1571887455898-ac2865c3dc4e?w=500&auto=format&fit=crop',
            description: 'Unpacking, base level adjustment, stabilizer connection, and demo.',
          ),
          ServiceItem(
            id: 'deep_freezer_rep',
            name: 'Deep freezer repair',
            price: 699,
            durationMinutes: 60,
            imageUrl: 'https://images.unsplash.com/photo-1571887455898-ac2865c3dc4e?w=500&auto=format&fit=crop',
            description: 'Commercial and domestic chest freezer cooling and thermostat repair.',
          ),
        ]),
      ],
    ),

    // 5. 🧺 Washing Machine Services
    Category(
      id: 'cat_washing',
      name: 'Washing Machine Services',
      imageUrl: 'https://images.unsplash.com/photo-1582730147233-a3d82a170562?w=500&auto=format&fit=crop',
      subcategories: [
        Subcategory(id: 'sub_washing_repair', name: 'Washing Machine Repair & Care', services: [
          ServiceItem(
            id: 'wm_repair_general',
            name: 'Washing machine repair',
            price: 399,
            durationMinutes: 45,
            imageUrl: 'https://images.unsplash.com/photo-1582730147233-a3d82a170562?w=500&auto=format&fit=crop',
            description: 'General diagnostics and fixing for top load & front load machines.',
          ),
          ServiceItem(
            id: 'wm_installation',
            name: 'Installation',
            price: 349,
            durationMinutes: 35,
            imageUrl: 'https://images.unsplash.com/photo-1582730147233-a3d82a170562?w=500&auto=format&fit=crop',
            description: 'Inlet hose fitting, drain pipe setup, transit bolt removal & leveling.',
          ),
          ServiceItem(
            id: 'wm_uninstallation',
            name: 'Uninstallation',
            price: 249,
            durationMinutes: 25,
            imageUrl: 'https://images.unsplash.com/photo-1582730147233-a3d82a170562?w=500&auto=format&fit=crop',
            description: 'Safe disconnection and transit preparation.',
          ),
          ServiceItem(
            id: 'wm_drainage_problem',
            name: 'Drainage problem',
            price: 349,
            durationMinutes: 35,
            imageUrl: 'https://images.unsplash.com/photo-1582730147233-a3d82a170562?w=500&auto=format&fit=crop',
            description: 'Clearing clogged drain pump, lint filter, and drain valve repair.',
          ),
          ServiceItem(
            id: 'wm_spin_problem',
            name: 'Spin problem',
            price: 399,
            durationMinutes: 40,
            imageUrl: 'https://images.unsplash.com/photo-1582730147233-a3d82a170562?w=500&auto=format&fit=crop',
            description: 'Fixing spin basket not rotating, belt slipping, or capacitor issue.',
          ),
          ServiceItem(
            id: 'wm_water_inlet',
            name: 'Water inlet problem',
            price: 299,
            durationMinutes: 30,
            imageUrl: 'https://images.unsplash.com/photo-1582730147233-a3d82a170562?w=500&auto=format&fit=crop',
            description: 'Inlet solenoid valve replacement and low pressure troubleshooting.',
          ),
          ServiceItem(
            id: 'wm_motor_repair',
            name: 'Motor repair',
            price: 899,
            durationMinutes: 60,
            imageUrl: 'https://images.unsplash.com/photo-1582730147233-a3d82a170562?w=500&auto=format&fit=crop',
            description: 'Drive motor rewinding, carbon brush, and coupler replacement.',
          ),
          ServiceItem(
            id: 'wm_pcb_repair',
            name: 'PCB/electrical repair',
            price: 999,
            durationMinutes: 60,
            imageUrl: 'https://images.unsplash.com/photo-1581092160607-ee22621dd758?w=500&auto=format&fit=crop',
            description: 'Microcontroller board repair, error code clearing (dE, OE, UE, etc.).',
          ),
          ServiceItem(
            id: 'wm_drum_issue',
            name: 'Drum issue',
            price: 599,
            durationMinutes: 60,
            imageUrl: 'https://images.unsplash.com/photo-1582730147233-a3d82a170562?w=500&auto=format&fit=crop',
            description: 'Drum spider arm repair, bearing replacement, and pulsator fixing.',
          ),
          ServiceItem(
            id: 'wm_noise_vibration',
            name: 'Noise/vibration issue',
            price: 349,
            durationMinutes: 35,
            imageUrl: 'https://images.unsplash.com/photo-1582730147233-a3d82a170562?w=500&auto=format&fit=crop',
            description: 'Shock absorber suspension rod replacement and base balance.',
          ),
          ServiceItem(
            id: 'wm_door_lock_issue',
            name: 'Door lock issue',
            price: 299,
            durationMinutes: 25,
            imageUrl: 'https://images.unsplash.com/photo-1582730147233-a3d82a170562?w=500&auto=format&fit=crop',
            description: 'Front load thermal door lock latch replacement.',
          ),
          ServiceItem(
            id: 'wm_not_starting',
            name: 'Washing machine not starting',
            price: 399,
            durationMinutes: 35,
            imageUrl: 'https://images.unsplash.com/photo-1582730147233-a3d82a170562?w=500&auto=format&fit=crop',
            description: 'Mains fuse, door interlock switch, and power supply check.',
          ),
        ]),
      ],
    ),

    // 6. 💻 Laptop & Computer Services
    Category(
      id: 'cat_computer',
      name: 'Laptop & Computer',
      imageUrl: 'https://images.unsplash.com/photo-1588872657578-7efd1f1555ed?w=500&auto=format&fit=crop',
      subcategories: [
        Subcategory(id: 'sub_laptop', name: 'Laptop Services', services: [
          ServiceItem(
            id: 'laptop_rep_gen',
            name: 'Laptop repair',
            price: 499,
            durationMinutes: 45,
            imageUrl: 'https://images.unsplash.com/photo-1597872200319-381442461a61?w=500&auto=format&fit=crop',
            description: 'Hardware and software troubleshooting for all major laptop brands.',
          ),
          ServiceItem(
            id: 'laptop_diag',
            name: 'Laptop diagnosis',
            price: 199,
            durationMinutes: 30,
            imageUrl: 'https://images.unsplash.com/photo-1588872657578-7efd1f1555ed?w=500&auto=format&fit=crop',
            description: 'Complete health checkup of battery, SSD, RAM, and motherboard.',
          ),
          ServiceItem(
            id: 'windows_install',
            name: 'Windows installation',
            price: 499,
            durationMinutes: 60,
            imageUrl: 'https://images.unsplash.com/photo-1588872657578-7efd1f1555ed?w=500&auto=format&fit=crop',
            description: 'Fresh Windows 10/11 installation with genuine drivers and updates.',
          ),
          ServiceItem(
            id: 'software_install',
            name: 'Software installation',
            price: 299,
            durationMinutes: 30,
            imageUrl: 'https://images.unsplash.com/photo-1597872200319-381442461a61?w=500&auto=format&fit=crop',
            description: 'MS Office, Adobe suite, development tools, and antivirus setup.',
          ),
          ServiceItem(
            id: 'virus_cleanup',
            name: 'Virus/malware cleanup',
            price: 399,
            durationMinutes: 45,
            imageUrl: 'https://images.unsplash.com/photo-1588872657578-7efd1f1555ed?w=500&auto=format&fit=crop',
            description: 'Deep scanning, spyware removal, and startup speed optimization.',
          ),
          ServiceItem(
            id: 'ssd_upgrade',
            name: 'SSD upgrade',
            price: 499,
            durationMinutes: 45,
            imageUrl: 'https://images.unsplash.com/photo-1597872200319-381442461a61?w=500&auto=format&fit=crop',
            description: 'NVMe/SATA SSD installation with OS cloning for 10x faster speed.',
          ),
          ServiceItem(
            id: 'ram_upgrade',
            name: 'RAM upgrade',
            price: 299,
            durationMinutes: 25,
            imageUrl: 'https://images.unsplash.com/photo-1597872200319-381442461a61?w=500&auto=format&fit=crop',
            description: 'DDR4/DDR5 RAM memory expansion and dual-channel testing.',
          ),
          ServiceItem(
            id: 'laptop_cleaning',
            name: 'Laptop cleaning',
            price: 349,
            durationMinutes: 40,
            imageUrl: 'https://images.unsplash.com/photo-1588872657578-7efd1f1555ed?w=500&auto=format&fit=crop',
            description: 'Internal heat sink and fan dust cleaning to prevent overheating.',
          ),
          ServiceItem(
            id: 'thermal_paste_rep',
            name: 'Thermal paste replacement',
            price: 399,
            durationMinutes: 45,
            imageUrl: 'https://images.unsplash.com/photo-1597872200319-381442461a61?w=500&auto=format&fit=crop',
            description: 'High thermal conductivity paste application on CPU & GPU.',
          ),
          ServiceItem(
            id: 'laptop_screen_rep',
            name: 'Screen replacement',
            price: 1999,
            durationMinutes: 60,
            imageUrl: 'https://images.unsplash.com/photo-1588872657578-7efd1f1555ed?w=500&auto=format&fit=crop',
            description: 'FHD / IPS / OLED laptop display panel replacement.',
          ),
          ServiceItem(
            id: 'laptop_kbd_rep',
            name: 'Keyboard replacement',
            price: 999,
            durationMinutes: 60,
            imageUrl: 'https://images.unsplash.com/photo-1595225476474-87563907a212?w=500&auto=format&fit=crop',
            description: 'Original backlit or standard keyboard installation.',
          ),
          ServiceItem(
            id: 'laptop_battery_rep',
            name: 'Battery replacement',
            price: 699,
            durationMinutes: 30,
            imageUrl: 'https://images.unsplash.com/photo-1588872657578-7efd1f1555ed?w=500&auto=format&fit=crop',
            description: 'OEM battery replacement with extended backup warranty.',
          ),
          ServiceItem(
            id: 'charging_port_rep',
            name: 'Charging port repair',
            price: 499,
            durationMinutes: 45,
            imageUrl: 'https://images.unsplash.com/photo-1588872657578-7efd1f1555ed?w=500&auto=format&fit=crop',
            description: 'Type-C / DC jack soldering and loose port replacement.',
          ),
          ServiceItem(
            id: 'motherboard_diag',
            name: 'Motherboard diagnosis',
            price: 699,
            durationMinutes: 60,
            imageUrl: 'https://images.unsplash.com/photo-1597872200319-381442461a61?w=500&auto=format&fit=crop',
            description: 'Chip level short-circuit detection, IO chip, and power rail check.',
          ),
          ServiceItem(
            id: 'laptop_not_turning_on',
            name: 'Laptop not turning on',
            price: 499,
            durationMinutes: 45,
            imageUrl: 'https://images.unsplash.com/photo-1588872657578-7efd1f1555ed?w=500&auto=format&fit=crop',
            description: 'Fixing dead laptop, charging light blinking, or black screen.',
          ),
        ]),
        Subcategory(id: 'sub_desktop', name: 'Desktop Services', services: [
          ServiceItem(
            id: 'desktop_repair',
            name: 'Desktop repair',
            price: 399,
            durationMinutes: 45,
            imageUrl: 'https://images.unsplash.com/photo-1588872657578-7efd1f1555ed?w=500&auto=format&fit=crop',
            description: 'Complete PC hardware and software troubleshooting.',
          ),
          ServiceItem(
            id: 'pc_assembly',
            name: 'PC assembly',
            price: 799,
            durationMinutes: 90,
            imageUrl: 'https://images.unsplash.com/photo-1588872657578-7efd1f1555ed?w=500&auto=format&fit=crop',
            description: 'Custom gaming or workstation PC building with cable management.',
          ),
          ServiceItem(
            id: 'desktop_windows',
            name: 'Windows installation',
            price: 499,
            durationMinutes: 60,
            imageUrl: 'https://images.unsplash.com/photo-1588872657578-7efd1f1555ed?w=500&auto=format&fit=crop',
            description: 'Clean OS install with BIOS optimization and driver installation.',
          ),
          ServiceItem(
            id: 'hardware_upgrade',
            name: 'Hardware upgrade',
            price: 399,
            durationMinutes: 45,
            imageUrl: 'https://images.unsplash.com/photo-1597872200319-381442461a61?w=500&auto=format&fit=crop',
            description: 'GPU, CPU cooler, cabinet fans, or storage installation.',
          ),
          ServiceItem(
            id: 'desktop_ssd_ram',
            name: 'SSD/RAM upgrade',
            price: 299,
            durationMinutes: 30,
            imageUrl: 'https://images.unsplash.com/photo-1597872200319-381442461a61?w=500&auto=format&fit=crop',
            description: 'Desktop RAM and SSD expansion.',
          ),
          ServiceItem(
            id: 'motherboard_troubleshoot',
            name: 'Motherboard troubleshooting',
            price: 499,
            durationMinutes: 45,
            imageUrl: 'https://images.unsplash.com/photo-1597872200319-381442461a61?w=500&auto=format&fit=crop',
            description: 'Fixing no post, RAM beep errors, and CMOS battery replacement.',
          ),
          ServiceItem(
            id: 'smps_replace',
            name: 'Power supply replacement',
            price: 349,
            durationMinutes: 35,
            imageUrl: 'https://images.unsplash.com/photo-1588872657578-7efd1f1555ed?w=500&auto=format&fit=crop',
            description: 'SMPS testing and installation.',
          ),
          ServiceItem(
            id: 'desktop_cleaning',
            name: 'Desktop cleaning',
            price: 299,
            durationMinutes: 35,
            imageUrl: 'https://images.unsplash.com/photo-1588872657578-7efd1f1555ed?w=500&auto=format&fit=crop',
            description: 'Blower cleaning, thermal re-pasting, and fan lubrication.',
          ),
        ]),
        Subcategory(id: 'sub_network', name: 'Network & Internet', services: [
          ServiceItem(
            id: 'wifi_troubleshoot',
            name: 'Wi-Fi troubleshooting',
            price: 249,
            durationMinutes: 30,
            imageUrl: 'https://images.unsplash.com/photo-1588872657578-7efd1f1555ed?w=500&auto=format&fit=crop',
            description: 'Fixing frequent Wi-Fi drops, speed issues, and channel congestion.',
          ),
          ServiceItem(
            id: 'router_setup',
            name: 'Router setup',
            price: 299,
            durationMinutes: 30,
            imageUrl: 'https://images.unsplash.com/photo-1588872657578-7efd1f1555ed?w=500&auto=format&fit=crop',
            description: 'Dual-band Wi-Fi router / mesh node configuration and security.',
          ),
          ServiceItem(
            id: 'internet_troubleshoot',
            name: 'Internet connection troubleshooting',
            price: 249,
            durationMinutes: 30,
            imageUrl: 'https://images.unsplash.com/photo-1588872657578-7efd1f1555ed?w=500&auto=format&fit=crop',
            description: 'DNS, gateway, IP conflict, and adapter diagnosis.',
          ),
          ServiceItem(
            id: 'network_setup',
            name: 'Home/office network setup',
            price: 999,
            durationMinutes: 90,
            imageUrl: 'https://images.unsplash.com/photo-1588872657578-7efd1f1555ed?w=500&auto=format&fit=crop',
            description: 'Switch, printer sharing, NAS, and multi-room network setup.',
          ),
          ServiceItem(
            id: 'lan_cable_setup',
            name: 'LAN cable setup',
            price: 399,
            durationMinutes: 45,
            imageUrl: 'https://images.unsplash.com/photo-1588872657578-7efd1f1555ed?w=500&auto=format&fit=crop',
            description: 'Cat6 LAN cable routing, RJ45 crimping, and I/O wall faceplate.',
          ),
        ]),
      ],
    ),

    // 7. 📹 CCTV & Security Services
    Category(
      id: 'cat_cctv',
      name: 'CCTV & Security',
      imageUrl: 'https://images.unsplash.com/photo-1557597774-9d273605dfa9?w=500&auto=format&fit=crop',
      subcategories: [
        Subcategory(id: 'sub_cctv_install', name: 'CCTV Installation', services: [
          ServiceItem(
            id: 'cctv_install_gen',
            name: 'CCTV camera installation',
            price: 399,
            durationMinutes: 45,
            imageUrl: 'https://images.unsplash.com/photo-1557597774-9d273605dfa9?w=500&auto=format&fit=crop',
            description: 'Standard camera mounting, angle calibration, and power supply.',
          ),
          ServiceItem(
            id: 'indoor_camera_install',
            name: 'Indoor camera installation',
            price: 349,
            durationMinutes: 35,
            imageUrl: 'https://images.unsplash.com/photo-1557597774-9d273605dfa9?w=500&auto=format&fit=crop',
            description: 'Dome camera ceiling mounting for home and office rooms.',
          ),
          ServiceItem(
            id: 'outdoor_camera_install',
            name: 'Outdoor camera installation',
            price: 449,
            durationMinutes: 45,
            imageUrl: 'https://images.unsplash.com/photo-1557597774-9d273605dfa9?w=500&auto=format&fit=crop',
            description: 'Weatherproof bullet camera mounting with junction box.',
          ),
          ServiceItem(
            id: 'wireless_cctv_setup',
            name: 'Wireless CCTV setup',
            price: 499,
            durationMinutes: 40,
            imageUrl: 'https://images.unsplash.com/photo-1557597774-9d273605dfa9?w=500&auto=format&fit=crop',
            description: 'Wi-Fi 360-degree smart camera setup and cloud sync.',
          ),
          ServiceItem(
            id: 'wired_cctv_setup',
            name: 'Wired CCTV setup',
            price: 599,
            durationMinutes: 60,
            imageUrl: 'https://images.unsplash.com/photo-1557597774-9d273605dfa9?w=500&auto=format&fit=crop',
            description: 'Coaxial / CAT6 conduit routing and BNC / DC connection.',
          ),
          ServiceItem(
            id: 'ip_camera_install',
            name: 'IP camera installation',
            price: 499,
            durationMinutes: 45,
            imageUrl: 'https://images.unsplash.com/photo-1557597774-9d273605dfa9?w=500&auto=format&fit=crop',
            description: 'PoE IP camera configuration with static IP and NVR integration.',
          ),
          ServiceItem(
            id: 'analog_camera_install',
            name: 'Analog camera installation',
            price: 349,
            durationMinutes: 35,
            imageUrl: 'https://images.unsplash.com/photo-1557597774-9d273605dfa9?w=500&auto=format&fit=crop',
            description: 'HD Analog camera setup with BNC video balun.',
          ),
        ]),
        Subcategory(id: 'sub_cctv_repair', name: 'CCTV Repair', services: [
          ServiceItem(
            id: 'cctv_repair_gen',
            name: 'CCTV camera repair',
            price: 299,
            durationMinutes: 35,
            imageUrl: 'https://images.unsplash.com/photo-1557597774-9d273605dfa9?w=500&auto=format&fit=crop',
            description: 'Fixing blurry lens, water condensation, or power adapter failure.',
          ),
          ServiceItem(
            id: 'dvr_repair',
            name: 'DVR repair',
            price: 499,
            durationMinutes: 45,
            imageUrl: 'https://images.unsplash.com/photo-1557597774-9d273605dfa9?w=500&auto=format&fit=crop',
            description: 'DVR power supply, video channel board, or firmware issue fix.',
          ),
          ServiceItem(
            id: 'nvr_repair',
            name: 'NVR setup/repair',
            price: 599,
            durationMinutes: 60,
            imageUrl: 'https://images.unsplash.com/photo-1557597774-9d273605dfa9?w=500&auto=format&fit=crop',
            description: 'Network Video Recorder PoE port check and camera stream binding.',
          ),
          ServiceItem(
            id: 'camera_not_working',
            name: 'Camera not working',
            price: 249,
            durationMinutes: 30,
            imageUrl: 'https://images.unsplash.com/photo-1557597774-9d273605dfa9?w=500&auto=format&fit=crop',
            description: 'Power line, BNC connector, or voltage drop diagnostics.',
          ),
          ServiceItem(
            id: 'no_video_signal',
            name: 'No video signal',
            price: 299,
            durationMinutes: 30,
            imageUrl: 'https://images.unsplash.com/photo-1557597774-9d273605dfa9?w=500&auto=format&fit=crop',
            description: 'Resolving black screen, video loss, or flickering camera feed.',
          ),
          ServiceItem(
            id: 'night_vision_issue',
            name: 'Night vision problem',
            price: 299,
            durationMinutes: 30,
            imageUrl: 'https://images.unsplash.com/photo-1557597774-9d273605dfa9?w=500&auto=format&fit=crop',
            description: 'IR LED board repair, IR cut filter sticking, or color night vision fix.',
          ),
          ServiceItem(
            id: 'storage_recording_issue',
            name: 'Storage/recording problem',
            price: 349,
            durationMinutes: 35,
            imageUrl: 'https://images.unsplash.com/photo-1557597774-9d273605dfa9?w=500&auto=format&fit=crop',
            description: 'Fixing HDD not detected, overwrite error, or playback loss.',
          ),
          ServiceItem(
            id: 'cctv_wiring_repair',
            name: 'CCTV wiring repair',
            price: 399,
            durationMinutes: 45,
            imageUrl: 'https://images.unsplash.com/photo-1557597774-9d273605dfa9?w=500&auto=format&fit=crop',
            description: 'Re-splicing broken cables and renewing connectors.',
          ),
        ]),
        Subcategory(id: 'sub_cctv_system_setup', name: 'CCTV System Setup', services: [
          ServiceItem(
            id: 'dvr_install',
            name: 'DVR installation',
            price: 499,
            durationMinutes: 45,
            imageUrl: 'https://images.unsplash.com/photo-1557597774-9d273605dfa9?w=500&auto=format&fit=crop',
            description: '4/8/16 channel DVR setup with HDMI/VGA display connection.',
          ),
          ServiceItem(
            id: 'nvr_install',
            name: 'NVR installation',
            price: 599,
            durationMinutes: 60,
            imageUrl: 'https://images.unsplash.com/photo-1557597774-9d273605dfa9?w=500&auto=format&fit=crop',
            description: 'NVR rack installation, PoE switch connection, and IP assign.',
          ),
          ServiceItem(
            id: 'hdd_install',
            name: 'Hard disk installation',
            price: 249,
            durationMinutes: 25,
            imageUrl: 'https://images.unsplash.com/photo-1557597774-9d273605dfa9?w=500&auto=format&fit=crop',
            description: 'Surveillance HDD formatting and continuous recording schedule.',
          ),
          ServiceItem(
            id: 'cctv_mobile_viewing',
            name: 'CCTV mobile viewing setup',
            price: 349,
            durationMinutes: 30,
            imageUrl: 'https://images.unsplash.com/photo-1557597774-9d273605dfa9?w=500&auto=format&fit=crop',
            description: 'Configuring smartphone app for live 24x7 HD camera stream.',
          ),
          ServiceItem(
            id: 'remote_monitoring',
            name: 'Remote monitoring setup',
            price: 499,
            durationMinutes: 45,
            imageUrl: 'https://images.unsplash.com/photo-1557597774-9d273605dfa9?w=500&auto=format&fit=crop',
            description: 'Static IP, DDNS, and port forwarding for PC and remote screens.',
          ),
          ServiceItem(
            id: 'multi_camera_config',
            name: 'Multi-camera configuration',
            price: 799,
            durationMinutes: 60,
            imageUrl: 'https://images.unsplash.com/photo-1557597774-9d273605dfa9?w=500&auto=format&fit=crop',
            description: 'Configuring motion alerts, masking zones, and AI human detection.',
          ),
          ServiceItem(
            id: 'camera_relocation',
            name: 'Camera relocation',
            price: 399,
            durationMinutes: 45,
            imageUrl: 'https://images.unsplash.com/photo-1557597774-9d273605dfa9?w=500&auto=format&fit=crop',
            description: 'Dismantling camera and reinstalling in new point.',
          ),
        ]),
        Subcategory(id: 'sub_security_systems', name: 'Security Systems', services: [
          ServiceItem(
            id: 'video_doorbell_install',
            name: 'Video doorbell installation',
            price: 499,
            durationMinutes: 45,
            imageUrl: 'https://images.unsplash.com/photo-1558223131-49193b8ae351?w=500&auto=format&fit=crop',
            description: 'Smart Wi-Fi video doorbell mounting with two-way audio setup.',
          ),
          ServiceItem(
            id: 'smart_doorbell_setup',
            name: 'Smart doorbell setup',
            price: 399,
            durationMinutes: 35,
            imageUrl: 'https://images.unsplash.com/photo-1558223131-49193b8ae351?w=500&auto=format&fit=crop',
            description: 'Smartphone app pairing, chime sync, and cloud notification test.',
          ),
          ServiceItem(
            id: 'biometric_install',
            name: 'Biometric attendance device installation',
            price: 899,
            durationMinutes: 60,
            imageUrl: 'https://images.unsplash.com/photo-1557597774-9d273605dfa9?w=500&auto=format&fit=crop',
            description: 'Fingerprint / face recognition attendance device mounting & software.',
          ),
          ServiceItem(
            id: 'access_control_install',
            name: 'Access control installation',
            price: 1199,
            durationMinutes: 90,
            imageUrl: 'https://images.unsplash.com/photo-1557597774-9d273605dfa9?w=500&auto=format&fit=crop',
            description: 'Electromagnetic EM lock, RFID card reader, and exit switch.',
          ),
          ServiceItem(
            id: 'electronic_door_lock',
            name: 'Electronic door lock installation',
            price: 799,
            durationMinutes: 60,
            imageUrl: 'https://images.unsplash.com/photo-1558223131-49193b8ae351?w=500&auto=format&fit=crop',
            description: 'Smart digital keypad & fingerprint door lock installation on wooden/glass door.',
          ),
          ServiceItem(
            id: 'home_security_system',
            name: 'Home security system installation',
            price: 1999,
            durationMinutes: 120,
            imageUrl: 'https://images.unsplash.com/photo-1557597774-9d273605dfa9?w=500&auto=format&fit=crop',
            description: 'Siren alarm, magnetic door sensors, and PIR motion sensor setup.',
          ),
        ]),
      ],
    ),

    // 8. 🔌 Home Appliance Services
    Category(
      id: 'cat_appliances',
      name: 'Home Appliances',
      imageUrl: 'https://images.unsplash.com/photo-1556911220-e15b29be8c8f?w=500&auto=format&fit=crop',
      subcategories: [
        Subcategory(id: 'sub_kitchen_appliances', name: 'Kitchen & Home Appliance Care', services: [
          ServiceItem(
            id: 'microwave_rep',
            name: 'Microwave repair',
            price: 399,
            durationMinutes: 45,
            imageUrl: 'https://images.unsplash.com/photo-1556911220-e15b29be8c8f?w=500&auto=format&fit=crop',
            description: 'Fixing not heating, turntable not spinning, keypad error, or sparks.',
          ),
          ServiceItem(
            id: 'chimney_svc',
            name: 'Chimney repair/service',
            price: 499,
            durationMinutes: 60,
            imageUrl: 'https://images.unsplash.com/photo-1556911220-e15b29be8c8f?w=500&auto=format&fit=crop',
            description: 'Baffle filter degreasing, motor suction repair, and duct checking.',
          ),
          ServiceItem(
            id: 'induction_rep',
            name: 'Induction cooktop repair',
            price: 299,
            durationMinutes: 35,
            imageUrl: 'https://images.unsplash.com/photo-1556911220-e15b29be8c8f?w=500&auto=format&fit=crop',
            description: 'IGBT replacement, sensor error fix, and glass surface replacement.',
          ),
          ServiceItem(
            id: 'mixer_grinder_rep',
            name: 'Mixer/grinder repair',
            price: 199,
            durationMinutes: 30,
            imageUrl: 'https://images.unsplash.com/photo-1556911220-e15b29be8c8f?w=500&auto=format&fit=crop',
            description: 'Jar coupler replacement, motor carbon brush, and blade sharpening.',
          ),
          ServiceItem(
            id: 'ro_service',
            name: 'Water purifier/RO service',
            price: 399,
            durationMinutes: 45,
            imageUrl: 'https://images.unsplash.com/photo-1584622650111-993a426fbf0a?w=500&auto=format&fit=crop',
            description: 'TDS testing, complete pipeline sanitization, and booster pump check.',
          ),
          ServiceItem(
            id: 'ro_installation',
            name: 'Water purifier installation',
            price: 499,
            durationMinutes: 45,
            imageUrl: 'https://images.unsplash.com/photo-1584622650111-993a426fbf0a?w=500&auto=format&fit=crop',
            description: 'Wall mounting, diverter valve connection, and waste pipe routing.',
          ),
          ServiceItem(
            id: 'ro_filter_replacement',
            name: 'Water purifier filter replacement',
            price: 299,
            durationMinutes: 35,
            imageUrl: 'https://images.unsplash.com/photo-1584622650111-993a426fbf0a?w=500&auto=format&fit=crop',
            description: 'Sediment, pre-carbon, RO membrane, and post-carbon cartridge change.',
          ),
          ServiceItem(
            id: 'ro_repair',
            name: 'Water purifier repair',
            price: 349,
            durationMinutes: 40,
            imageUrl: 'https://images.unsplash.com/photo-1584622650111-993a426fbf0a?w=500&auto=format&fit=crop',
            description: 'Fixing water leakage, auto cutoff failure, and low water output.',
          ),
          ServiceItem(
            id: 'kitchen_appliance_troubleshoot',
            name: 'Kitchen appliance troubleshooting',
            price: 249,
            durationMinutes: 30,
            imageUrl: 'https://images.unsplash.com/photo-1556911220-e15b29be8c8f?w=500&auto=format&fit=crop',
            description: 'General electrical troubleshooting for toasters, kettles, and blenders.',
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

  static final List<PromotionalBanner> default3DHeroBanners = [
    const PromotionalBanner(
      id: 'banner_3d_1',
      title: 'Expert 3D Home Services',
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
      subtitle: 'Fast 15-Min Dispatch · 30-Day Warranty',
      badgeText: 'Top Rated',
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
      subtitle: 'Fast 15-min arrival with 30-day warranty',
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
