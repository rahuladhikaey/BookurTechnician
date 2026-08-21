import 'dart:convert';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'models.dart';
import 'models/customer_profile_models.dart';
import 'services/api_client.dart';

// ─── App State ───────────────────────────────────────────────────────────────

class AppState {
  final List<Category> categories;
  final bool isCatalogLoading;
  final List<PromotionalBanner> heroBanners;
  final List<PromotionalBanner> spotlightBanners;
  final bool isBannersLoading;
  final List<ServiceItem> cartItems;
  final String address;
  final String couponCode;
  final double baseCost;
  final double visitFee;
  final double discount;
  final double gstTax;
  final double grandTotal;
  final bool isCalculatingPrice;
  final Booking? activeBooking;
  final List<Booking> bookingHistory;
  final String trackingOtpStatus;
  final PaymentStatus paymentStatus;
  final String? paymentError;
  final double restoredCartTotal;
  final bool isGuest;
  final CustomerProfile profile;
  final String selectedScheduleDate;
  final String selectedScheduleSlot;
  final String selectedAddressTitle;
  final String selectedAddressType;
  final double? selectedLatitude;
  final double? selectedLongitude;
  final bool isAcquiringLocation;

  const AppState({
    this.isGuest = true,
    required this.profile,
    this.selectedScheduleDate = 'Tomorrow',
    this.selectedScheduleSlot = '3:00 PM – 4:00 PM',
    this.selectedAddressTitle = 'Locating...',
    this.selectedAddressType = 'Home',
    this.selectedLatitude,
    this.selectedLongitude,
    this.isAcquiringLocation = false,
    this.categories = const [],
    this.isCatalogLoading = false,
    this.heroBanners = const [],
    this.spotlightBanners = const [],
    this.isBannersLoading = false,
    this.cartItems = const [],
    this.address = 'Fetching live address...',
    this.couponCode = '',
    this.baseCost = 0.0,
    this.visitFee = 99.0,
    this.discount = 0.0,
    this.gstTax = 0.0,
    this.grandTotal = 0.0,
    this.isCalculatingPrice = false,
    this.activeBooking,
    this.bookingHistory = const [],
    this.trackingOtpStatus = 'PENDING',
    this.paymentStatus = PaymentStatus.idle,
    this.paymentError,
    this.restoredCartTotal = 0.0,
  });

  // Convenience getters
  String get userName => profile.fullName;
  String get userPhone => profile.phone;
  String get userEmail => profile.email;

  AppState copyWith({
    bool? isGuest,
    CustomerProfile? profile,
    String? selectedScheduleDate,
    String? selectedScheduleSlot,
    String? selectedAddressTitle,
    String? selectedAddressType,
    double? selectedLatitude,
    double? selectedLongitude,
    bool? isAcquiringLocation,
    List<Category>? categories,
    bool? isCatalogLoading,
    List<PromotionalBanner>? heroBanners,
    List<PromotionalBanner>? spotlightBanners,
    bool? isBannersLoading,
    List<ServiceItem>? cartItems,
    String? address,
    String? couponCode,
    double? baseCost,
    double? visitFee,
    double? discount,
    double? gstTax,
    double? grandTotal,
    bool? isCalculatingPrice,
    Booking? activeBooking,
    bool clearActiveBooking = false,
    List<Booking>? bookingHistory,
    String? trackingOtpStatus,
    PaymentStatus? paymentStatus,
    String? paymentError,
    bool clearPaymentError = false,
    double? restoredCartTotal,
  }) {
    return AppState(
      isGuest: isGuest ?? this.isGuest,
      profile: profile ?? this.profile,
      selectedScheduleDate: selectedScheduleDate ?? this.selectedScheduleDate,
      selectedScheduleSlot: selectedScheduleSlot ?? this.selectedScheduleSlot,
      selectedAddressTitle: selectedAddressTitle ?? this.selectedAddressTitle,
      selectedAddressType: selectedAddressType ?? this.selectedAddressType,
      selectedLatitude: selectedLatitude ?? this.selectedLatitude,
      selectedLongitude: selectedLongitude ?? this.selectedLongitude,
      isAcquiringLocation: isAcquiringLocation ?? this.isAcquiringLocation,
      categories: categories ?? this.categories,
      isCatalogLoading: isCatalogLoading ?? this.isCatalogLoading,
      heroBanners: heroBanners ?? this.heroBanners,
      spotlightBanners: spotlightBanners ?? this.spotlightBanners,
      isBannersLoading: isBannersLoading ?? this.isBannersLoading,
      cartItems: cartItems ?? this.cartItems,
      address: address ?? this.address,
      couponCode: couponCode ?? this.couponCode,
      baseCost: baseCost ?? this.baseCost,
      visitFee: visitFee ?? this.visitFee,
      discount: discount ?? this.discount,
      gstTax: gstTax ?? this.gstTax,
      grandTotal: grandTotal ?? this.grandTotal,
      isCalculatingPrice: isCalculatingPrice ?? this.isCalculatingPrice,
      activeBooking: clearActiveBooking ? null : activeBooking ?? this.activeBooking,
      bookingHistory: bookingHistory ?? this.bookingHistory,
      trackingOtpStatus: trackingOtpStatus ?? this.trackingOtpStatus,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      paymentError: clearPaymentError ? null : paymentError ?? this.paymentError,
      restoredCartTotal: restoredCartTotal ?? this.restoredCartTotal,
    );
  }
}

// ─── Notifier / Provider ─────────────────────────────────────────────────────

class BookingNotifier extends StateNotifier<AppState> {
  BookingNotifier()
      : super(AppState(
          isGuest: true,
          profile: CustomerProfile.createWithCalculation(
            customerId: '',
            userId: '',
            fullName: '',
            phone: '',
            isPhoneVerified: false,
            email: '',
            isEmailVerified: false,
            addresses: const [],
          ),
        )) {
    initAppSession();
  }

  /// Initialize application session: restore persisted login state & real GPS location
  Future<void> initAppSession() async {
    await restoreSession();
    _loadCatalog();
    loadBanners();
    autoAcquireGpsLocation();
  }

  /// Restore persisted authentication session from local storage & sync backend
  Future<bool> restoreSession() async {
    try {
      final session = await ApiClient.getUserSession();
      final token = session['accessToken'];
      final name = session['name'];
      final phone = session['phone'];
      final email = session['email'];

      if (token != null && token.isNotEmpty) {
        // Immediate in-memory session restore from persistent storage
        final restoredProfile = CustomerProfile.createWithCalculation(
          customerId: session['userId'] ?? 'user',
          userId: session['userId'] ?? 'user',
          fullName: name ?? 'Customer',
          phone: phone ?? '',
          isPhoneVerified: phone != null && phone.isNotEmpty,
          email: email ?? '',
          isEmailVerified: email != null && email.isNotEmpty,
          addresses: const [],
        );

        state = state.copyWith(
          isGuest: false,
          profile: restoredProfile,
        );

        // Asynchronously sync latest profile & saved addresses from backend
        _syncProfileAndAddresses();
        loadBookingHistory();
        return true;
      }
    } catch (e) {
      debugPrint('Session restore warning: $e');
    }
    return false;
  }

  Future<void> _syncProfileAndAddresses() async {
    try {
      final profileRes = await ApiClient.get('/customer/profile');
      final addressesRes = await ApiClient.get('/customer/addresses');

      Map<String, dynamic>? user;
      if (profileRes.statusCode == 200) {
        final decoded = jsonDecode(profileRes.body);
        final profileData = decoded['data'];
        user = profileData?['user'];
      }

      final List<CustomerAddress> parsedAddrs = [];
      if (addressesRes.statusCode == 200) {
        final decoded = jsonDecode(addressesRes.body);
        final addrList = decoded['data'] as List? ?? [];
        for (var a in addrList) {
          try {
            double lat = 12.9716;
            double lng = 77.5946;
            if (a['coordinates'] != null && a['coordinates'] is Map) {
              lat = (a['coordinates']['y'] as num?)?.toDouble() ?? 12.9716;
              lng = (a['coordinates']['x'] as num?)?.toDouble() ?? 77.5946;
            } else {
              lat = (a['latitude'] as num?)?.toDouble() ?? 12.9716;
              lng = (a['longitude'] as num?)?.toDouble() ?? 77.5946;
            }

            parsedAddrs.add(CustomerAddress(
              id: a['id']?.toString() ?? '',
              customerId: a['customerId']?.toString() ?? (user?['id']?.toString() ?? state.profile.customerId),
              addressType: (a['addressType']?.toString().toUpperCase() == 'WORK') ? AddressType.work : AddressType.home,
              houseFlat: a['houseFlat'] ?? '',
              street: a['street'] ?? '',
              area: a['area'] ?? '',
              city: a['city'] ?? '',
              state: a['state'] ?? 'Karnataka',
              postalCode: a['postalCode'] ?? '',
              latitude: lat,
              longitude: lng,
              isPrimary: a['primary'] == true || a['isPrimary'] == true,
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            ));
          } catch (_) {}
        }
      }

      final updatedName = user?['fullName'] ?? state.profile.fullName;
      final updatedPhone = user?['phone'] ?? state.profile.phone;
      final updatedEmail = user?['email'] ?? state.profile.email;
      final updatedUserId = user?['id']?.toString() ?? state.profile.userId;

      final syncedProfile = CustomerProfile.createWithCalculation(
        customerId: updatedUserId,
        userId: updatedUserId,
        fullName: updatedName,
        phone: updatedPhone,
        isPhoneVerified: true,
        email: updatedEmail,
        isEmailVerified: true,
        addresses: parsedAddrs,
      );

      state = state.copyWith(
        isGuest: false,
        profile: syncedProfile,
      );

      // Keep locally saved session in sync
      final currentSession = await ApiClient.getUserSession();
      if (currentSession['accessToken'] != null) {
        await ApiClient.saveUserSession(
          accessToken: currentSession['accessToken']!,
          refreshToken: currentSession['refreshToken'] ?? '',
          userId: updatedUserId,
          name: updatedName,
          phone: updatedPhone,
          email: updatedEmail,
        );
      }

      if (parsedAddrs.isNotEmpty) {
        final primary = syncedProfile.primaryAddress;
        if (primary != null) {
          state = state.copyWith(
            address: primary.formattedAddress,
            selectedAddressTitle: primary.area.isNotEmpty ? primary.area : primary.city,
            selectedLatitude: primary.latitude,
            selectedLongitude: primary.longitude,
          );
        }
      }
    } catch (e) {
      debugPrint('Failed to sync backend profile: $e');
    }
  }

  /// Automatically acquire device live GPS location on app launch
  Future<void> autoAcquireGpsLocation() async {
    state = state.copyWith(isAcquiringLocation: true);

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        state = state.copyWith(
          isAcquiringLocation: false,
          selectedAddressTitle: 'Enable GPS',
          address: 'Please enable GPS location services',
        );
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          state = state.copyWith(
            isAcquiringLocation: false,
            selectedAddressTitle: 'Location Permission',
            address: 'Allow location access to find nearby technicians',
          );
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        state = state.copyWith(
          isAcquiringLocation: false,
          selectedAddressTitle: 'GPS Denied',
          address: 'Location permissions are permanently denied in settings',
        );
        return;
      }

      // Fetch real high accuracy GPS coordinates
      Position pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 8),
      );

      final lat = pos.latitude;
      final lng = pos.longitude;

      // Reverse geocode via OpenStreetMap Nominatim
      try {
        final url = Uri.parse(
          'https://nominatim.openstreetmap.org/reverse?format=json&lat=$lat&lon=$lng&zoom=18&addressdetails=1',
        );
        final response = await http.get(url, headers: {
          'User-Agent': 'BookUrTechnician/1.0 (contact@bookurtechnician.com)',
        }).timeout(const Duration(seconds: 5));

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          final displayName = data['display_name'] as String?;
          final addressObj = data['address'] as Map<String, dynamic>?;

          final suburb = addressObj?['suburb'] ?? addressObj?['neighbourhood'] ?? addressObj?['residential'] ?? addressObj?['subdistrict'] ?? '';
          final city = addressObj?['city'] ?? addressObj?['town'] ?? addressObj?['county'] ?? 'Bengaluru';
          final title = suburb.isNotEmpty ? suburb : city;

          state = state.copyWith(
            selectedLatitude: lat,
            selectedLongitude: lng,
            selectedAddressTitle: title,
            address: displayName ?? '$title, $city',
            isAcquiringLocation: false,
          );
          return;
        }
      } catch (e) {
        debugPrint('Reverse geocoding lookup warning: $e');
      }

      state = state.copyWith(
        selectedLatitude: lat,
        selectedLongitude: lng,
        selectedAddressTitle: 'Live GPS Location',
        address: 'Lat: ${lat.toStringAsFixed(4)}, Lng: ${lng.toStringAsFixed(4)}',
        isAcquiringLocation: false,
      );
    } catch (e) {
      debugPrint('Auto GPS error: $e');
      state = state.copyWith(
        isAcquiringLocation: false,
        selectedAddressTitle: 'Select Location',
        address: 'Tap to pick service location',
      );
    }
  }

  void setGuestMode(bool guest) {
    state = state.copyWith(isGuest: guest);
  }

  /// Called after successful OTP login / verification
  Future<void> loginUser({
    required String name,
    required String phone,
    required String email,
    String? userId,
    String? accessToken,
    String? refreshToken,
  }) async {
    final cleanPhone = phone.startsWith('+91') ? phone : '+91 $phone';
    final uid = userId ?? 'usr_${DateTime.now().millisecondsSinceEpoch}';

    // Persist credentials locally
    if (accessToken != null && refreshToken != null) {
      await ApiClient.saveUserSession(
        accessToken: accessToken,
        refreshToken: refreshToken,
        userId: uid,
        name: name.trim(),
        phone: cleanPhone,
        email: email.trim(),
      );
    }

    final userProfile = CustomerProfile.createWithCalculation(
      customerId: uid,
      userId: uid,
      fullName: name.trim(),
      phone: cleanPhone,
      isPhoneVerified: true,
      email: email.trim(),
      isEmailVerified: true,
      addresses: const [],
    );

    state = state.copyWith(
      isGuest: false,
      profile: userProfile,
    );

    // Sync with backend & load history
    _syncProfileAndAddresses();
    loadBookingHistory();
  }

  /// Complete Sign Out & Session Erasure
  Future<void> logoutUser() async {
    await ApiClient.clearTokens();
    
    state = state.copyWith(
      isGuest: true,
      profile: CustomerProfile.createWithCalculation(
        customerId: '',
        userId: '',
        fullName: '',
        phone: '',
        isPhoneVerified: false,
        email: '',
        isEmailVerified: false,
        addresses: const [],
      ),
      cartItems: [],
      activeBooking: null,
      clearActiveBooking: true,
      bookingHistory: [],
    );
  }

  /// Update profile details and sync to backend
  Future<void> updateProfileDetails({
    String? fullName,
    String? email,
    bool? isEmailVerified,
    String? phone,
    bool? isPhoneVerified,
    String? profilePhotoUrl,
    bool clearPhoto = false,
    DateTime? dateOfBirth,
    bool clearDob = false,
    DateTime? anniversary,
    bool clearAnniversary = false,
    String? gender,
  }) async {
    final updated = state.profile.copyWith(
      fullName: fullName,
      email: email,
      isEmailVerified: isEmailVerified,
      phone: phone,
      isPhoneVerified: isPhoneVerified,
      profilePhotoUrl: profilePhotoUrl,
      clearProfilePhoto: clearPhoto,
      dateOfBirth: dateOfBirth,
      clearDob: clearDob,
      anniversary: anniversary,
      clearAnniversary: clearAnniversary,
      gender: gender,
    );

    state = state.copyWith(profile: updated);

    // Persist to session locally
    final session = await ApiClient.getUserSession();
    if (session['accessToken'] != null) {
      await ApiClient.saveUserSession(
        accessToken: session['accessToken']!,
        refreshToken: session['refreshToken'] ?? '',
        userId: state.profile.userId,
        name: updated.fullName,
        phone: updated.phone,
        email: updated.email,
      );
    }

    // Persist to backend database
    try {
      final payload = <String, dynamic>{};
      if (fullName != null && fullName.trim().isNotEmpty) {
        payload['fullName'] = fullName.trim();
      }
      if (gender != null) {
        payload['gender'] = gender;
      }
      if (dateOfBirth != null) {
        payload['dateOfBirth'] = "${dateOfBirth.year.toString().padLeft(4, '0')}-${dateOfBirth.month.toString().padLeft(2, '0')}-${dateOfBirth.day.toString().padLeft(2, '0')}";
      }

      await ApiClient.put('/customer/profile', payload);
    } catch (e) {
      debugPrint('Profile update backend sync warning: $e');
    }
  }

  /// Add a new service address and persist to backend
  Future<void> addCustomerAddress(CustomerAddress address) async {
    final currentList = [...state.profile.addresses];
    final shouldBePrimary = address.isPrimary || currentList.isEmpty;
    final updatedList = currentList.map((a) => shouldBePrimary ? a.copyWith(isPrimary: false) : a).toList();
    
    updatedList.add(address.copyWith(isPrimary: shouldBePrimary));

    final updatedProfile = state.profile.copyWith(addresses: updatedList);
    final primary = updatedProfile.primaryAddress;

    state = state.copyWith(
      profile: updatedProfile,
      address: primary?.formattedAddress ?? state.address,
      selectedAddressTitle: primary?.area.isNotEmpty == true ? primary!.area : (primary?.city ?? state.selectedAddressTitle),
      selectedAddressType: primary?.typeLabel ?? state.selectedAddressType,
      selectedLatitude: primary?.latitude ?? state.selectedLatitude,
      selectedLongitude: primary?.longitude ?? state.selectedLongitude,
    );

    // Sync to backend database
    try {
      final payload = {
        'houseFlat': address.houseFlat,
        'street': address.street,
        'area': address.area,
        'city': address.city,
        'state': address.state,
        'postalCode': address.postalCode,
        'landmark': address.landmark,
        'addressType': address.typeLabel.toUpperCase(),
        'latitude': address.latitude,
        'longitude': address.longitude,
        'primary': shouldBePrimary,
      };

      final res = await ApiClient.post('/customer/addresses', payload);
      if (res.statusCode == 200) {
        // Sync refreshed IDs from backend
        _syncProfileAndAddresses();
      }
    } catch (e) {
      debugPrint('Add address backend sync warning: $e');
    }
  }

  /// Update an existing address and sync to backend
  Future<void> updateCustomerAddress(CustomerAddress address) async {
    final updatedList = state.profile.addresses.map((a) {
      if (a.id == address.id) {
        return address;
      }
      if (address.isPrimary) {
        return a.copyWith(isPrimary: false);
      }
      return a;
    }).toList();

    final updatedProfile = state.profile.copyWith(addresses: updatedList);
    final primary = updatedProfile.primaryAddress;

    state = state.copyWith(
      profile: updatedProfile,
      address: primary?.formattedAddress ?? state.address,
      selectedAddressTitle: primary?.area.isNotEmpty == true ? primary!.area : (primary?.city ?? state.selectedAddressTitle),
      selectedAddressType: primary?.typeLabel ?? state.selectedAddressType,
    );

    try {
      final payload = {
        'houseFlat': address.houseFlat,
        'street': address.street,
        'area': address.area,
        'city': address.city,
        'state': address.state,
        'postalCode': address.postalCode,
        'landmark': address.landmark,
        'addressType': address.typeLabel.toUpperCase(),
        'latitude': address.latitude,
        'longitude': address.longitude,
        'primary': address.isPrimary,
      };

      await ApiClient.put('/customer/addresses/${address.id}', payload);
    } catch (e) {
      debugPrint('Update address backend sync warning: $e');
    }
  }

  /// Delete a service address and sync to backend
  Future<bool> deleteCustomerAddress(String addressId) async {
    final currentList = [...state.profile.addresses];
    final target = currentList.firstWhere((a) => a.id == addressId, orElse: () => currentList.first);
    
    currentList.removeWhere((a) => a.id == addressId);

    if (target.isPrimary && currentList.isNotEmpty) {
      currentList[0] = currentList[0].copyWith(isPrimary: true);
    }

    final updatedProfile = state.profile.copyWith(addresses: currentList);
    final primary = updatedProfile.primaryAddress;

    state = state.copyWith(
      profile: updatedProfile,
      address: primary?.formattedAddress ?? '',
      selectedAddressTitle: primary?.area.isNotEmpty == true ? primary!.area : (primary?.city ?? 'Select Location'),
      selectedAddressType: primary?.typeLabel ?? 'Home',
    );

    try {
      await ApiClient.delete('/customer/addresses/$addressId');
    } catch (e) {
      debugPrint('Delete address backend sync warning: $e');
    }

    return true;
  }

  /// Set an address as primary
  Future<void> setPrimaryAddress(String addressId) async {
    final updatedList = state.profile.addresses.map((a) {
      return a.copyWith(isPrimary: a.id == addressId);
    }).toList();

    final updatedProfile = state.profile.copyWith(addresses: updatedList);
    final primary = updatedProfile.primaryAddress;

    state = state.copyWith(
      profile: updatedProfile,
      address: primary?.formattedAddress ?? state.address,
      selectedAddressTitle: primary?.area.isNotEmpty == true ? primary!.area : (primary?.city ?? state.selectedAddressTitle),
      selectedAddressType: primary?.typeLabel ?? state.selectedAddressType,
      selectedLatitude: primary?.latitude ?? state.selectedLatitude,
      selectedLongitude: primary?.longitude ?? state.selectedLongitude,
    );

    if (primary != null) {
      await updateCustomerAddress(primary);
    }
  }

  /// Update selected service address with real GPS coordinates
  void updateAddress(String address, {double? latitude, double? longitude}) {
    state = state.copyWith(
      address: address,
      selectedAddressTitle: address,
      selectedLatitude: latitude,
      selectedLongitude: longitude,
    );
  }

  Future<void> _loadCatalog() async {
    state = state.copyWith(isCatalogLoading: true);
    try {
      final res = await ApiClient.get('/catalog/categories');
      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        final List list = decoded['data'] ?? [];
        final categories = list.map((c) => Category.fromJson(c as Map<String, dynamic>)).toList();
        if (categories.isNotEmpty) {
          state = state.copyWith(
            categories: categories,
            isCatalogLoading: false,
          );
          return;
        }
      }
    } catch (e) {
      debugPrint('Catalog live load warning: $e');
    }
    state = state.copyWith(
      categories: MockData.categoriesList,
      isCatalogLoading: false,
    );
  }

  Future<void> loadBanners() async {
    state = state.copyWith(isBannersLoading: true);
    try {
      final heroRes = await ApiClient.get('/banners/hero');
      final spotRes = await ApiClient.get('/banners/spotlight');

      List<PromotionalBanner> heroes = [];
      List<PromotionalBanner> spotlights = [];

      if (heroRes.statusCode == 200) {
        final decoded = jsonDecode(heroRes.body);
        final List list = decoded['data'] ?? [];
        heroes = list.map((b) => PromotionalBanner.fromJson(b as Map<String, dynamic>)).toList();
      }

      if (spotRes.statusCode == 200) {
        final decoded = jsonDecode(spotRes.body);
        final List list = decoded['data'] ?? [];
        spotlights = list.map((b) => PromotionalBanner.fromJson(b as Map<String, dynamic>)).toList();
      }

      state = state.copyWith(
        heroBanners: heroes.isNotEmpty ? heroes : state.heroBanners,
        spotlightBanners: spotlights.isNotEmpty ? spotlights : state.spotlightBanners,
        isBannersLoading: false,
      );
    } catch (e) {
      debugPrint('Banners load warning: $e');
      state = state.copyWith(isBannersLoading: false);
    }
  }

  void toggleCartItem(ServiceItem service) {
    final list = [...state.cartItems];
    if (list.any((s) => s.id == service.id)) {
      list.removeWhere((s) => s.id == service.id);
    } else {
      list.add(service);
    }
    state = state.copyWith(cartItems: list);
    _recalculatePrices();
  }

  void removeFromCart(String serviceId) {
    final list = [...state.cartItems];
    list.removeWhere((s) => s.id == serviceId);
    state = state.copyWith(cartItems: list);
    _recalculatePrices();
  }

  void updateSchedule(String date, String slot) {
    state = state.copyWith(selectedScheduleDate: date, selectedScheduleSlot: slot);
  }

  void updateAddressDetails(String address, String type) {
    state = state.copyWith(
      address: address,
      selectedAddressTitle: address,
      selectedAddressType: type,
    );
  }

  Future<void> _recalculatePrices() async {
    state = state.copyWith(isCalculatingPrice: true);
    await Future.delayed(const Duration(milliseconds: 50));
    final base = state.cartItems.fold(0.0, (sum, s) => sum + s.price);
    final bookingCharge = state.cartItems.isNotEmpty
        ? state.cartItems.map((s) => s.bookingCharge).reduce((a, b) => a > b ? a : b)
        : 0.0;
    final taxable = base + bookingCharge;
    final gst = taxable * 0.18;
    final total = taxable + gst;
    state = state.copyWith(
      baseCost: base,
      visitFee: bookingCharge,
      gstTax: gst,
      grandTotal: total,
      isCalculatingPrice: false,
    );
  }

  Future<bool> confirmOrder(String date, String slot) async {
    if (state.cartItems.isEmpty) return false;
    final service = state.cartItems.first;
    final primaryAddr = state.profile.primaryAddress;
    final addressId = primaryAddr?.id ?? 'default_address';

    try {
      final res = await ApiClient.post('/bookings', {
        'serviceId': service.id,
        'addressId': addressId,
        'scheduleDate': date == 'Tomorrow' ? DateTime.now().add(const Duration(days: 1)).toIso8601String().split('T').first : date,
        'scheduleSlot': slot,
      });

      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        final data = decoded['data'];
        if (data != null) {
          final liveBooking = Booking.fromJson(data);
          state = state.copyWith(
            activeBooking: liveBooking,
            cartItems: [],
            baseCost: 0, visitFee: 49, discount: 0, gstTax: 0, grandTotal: 0,
          );
          return true;
        }
      }
    } catch (e) {
      debugPrint('Confirm booking error: $e');
    }
    return false;
  }

  Future<void> loadBookingHistory() async {
    try {
      final res = await ApiClient.get('/bookings/my-bookings');
      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        final List list = decoded['data'] ?? [];
        final history = list.map((b) => Booking.fromJson(b as Map<String, dynamic>)).toList();
        state = state.copyWith(bookingHistory: history);
      }
    } catch (e) {
      debugPrint('Error loading booking history: $e');
    }
  }

  void setBookingStatus(BookingStatus status) {
    final b = state.activeBooking;
    if (b != null) {
      state = state.copyWith(activeBooking: b.copyWith(status: status));
    }
  }

  void verifyOtp(String otp) {
    final b = state.activeBooking;
    if (b != null && otp == b.otpCode) {
      state = state.copyWith(
        trackingOtpStatus: 'VERIFIED',
        activeBooking: b.copyWith(status: BookingStatus.serviceStarted),
      );
    }
  }

  void completeService() {
    final b = state.activeBooking;
    if (b != null) {
      final completed = b.copyWith(status: BookingStatus.completed);
      state = state.copyWith(
        activeBooking: null,
        clearActiveBooking: true,
        bookingHistory: [...state.bookingHistory, completed],
        trackingOtpStatus: 'PENDING',
      );
    }
  }

  // ─── Payments ─────────────────────────────────────────────────

  Future<Map<String, dynamic>?> createPaymentOrder(String bookingId) async {
    state = state.copyWith(paymentStatus: PaymentStatus.processing, clearPaymentError: true);
    try {
      final res = await ApiClient.post('/payments/create-order', {'bookingId': bookingId});
      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        return decoded['data'];
      }
    } catch (e) {
      state = state.copyWith(paymentStatus: PaymentStatus.errorNetwork, paymentError: e.toString());
    }
    return null;
  }

  Future<bool> verifyPaymentSignature({
    required String bookingId,
    required String razorpayOrderId,
    required String razorpayPaymentId,
    required String razorpaySignature,
  }) async {
    try {
      final res = await ApiClient.post('/payments/verify-signature', {
        'bookingId': bookingId,
        'razorpayOrderId': razorpayOrderId,
        'razorpayPaymentId': razorpayPaymentId,
        'razorpaySignature': razorpaySignature,
      });
      if (res.statusCode == 200) {
        state = state.copyWith(paymentStatus: PaymentStatus.success, clearPaymentError: true);
        return true;
      }
    } catch (e) {
      state = state.copyWith(paymentStatus: PaymentStatus.errorNetwork, paymentError: e.toString());
    }
    return false;
  }

  Future<void> checkRestoration() async {
    final prefs = await SharedPreferences.getInstance();
    final isPending = prefs.getBool('is_pending') ?? false;
    if (isPending) {
      final total = prefs.getDouble('grand_total') ?? 0.0;
      state = state.copyWith(
        paymentStatus: PaymentStatus.pendingRestoration,
        restoredCartTotal: total,
      );
    }
  }

  Future<void> restoreCart() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    state = state.copyWith(paymentStatus: PaymentStatus.idle);
  }

  Future<void> discardRestoration() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    state = state.copyWith(paymentStatus: PaymentStatus.idle);
  }

  void clearPaymentStatus() {
    state = state.copyWith(paymentStatus: PaymentStatus.idle, clearPaymentError: true);
  }
}

final bookingProvider = StateNotifierProvider<BookingNotifier, AppState>((ref) {
  return BookingNotifier();
});
