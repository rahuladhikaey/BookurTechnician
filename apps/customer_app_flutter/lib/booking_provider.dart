import 'dart:convert';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:http/http.dart' as http;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'models.dart';
import 'models/customer_profile_models.dart';

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

  const AppState({
    this.isGuest = false,
    required this.profile,
    this.selectedScheduleDate = 'Tomorrow',
    this.selectedScheduleSlot = '3:00 PM – 4:00 PM',
    this.selectedAddressTitle = 'Flat 402, Royal Palms, Bellary Road, Bengaluru',
    this.selectedAddressType = 'Home',
    this.categories = const [],
    this.isCatalogLoading = false,
    this.heroBanners = const [],
    this.spotlightBanners = const [],
    this.isBannersLoading = false,
    this.cartItems = const [],
    this.address = 'Flat 402, Royal Palms, Bellary Road, Bengaluru',
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

  // Convenience getters for backward compatibility
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
          profile: CustomerProfile.createWithCalculation(
            customerId: 'cust_rahul_01',
            userId: 'usr_rahul_01',
            fullName: 'Rahul Sharma',
            phone: '+91 98765 43210',
            isPhoneVerified: true,
            email: 'rahul.sharma@example.com',
            isEmailVerified: true,
            addresses: [
              CustomerAddress(
                id: 'addr_1',
                customerId: 'cust_rahul_01',
                addressType: AddressType.home,
                houseFlat: 'Flat 402, Royal Palms',
                street: 'Bellary Road',
                area: 'Hebbal',
                city: 'Bengaluru',
                state: 'Karnataka',
                postalCode: '560024',
                isPrimary: true,
                createdAt: DateTime(2026, 1, 15),
                updatedAt: DateTime(2026, 1, 15),
              ),
              CustomerAddress(
                id: 'addr_2',
                customerId: 'cust_rahul_01',
                addressType: AddressType.work,
                houseFlat: 'Tech Park, Tower B',
                street: 'Outer Ring Road',
                area: 'Koramangala',
                city: 'Bengaluru',
                state: 'Karnataka',
                postalCode: '560034',
                isPrimary: false,
                createdAt: DateTime(2026, 2, 10),
                updatedAt: DateTime(2026, 2, 10),
              ),
            ],
          ),
        )) {
    _loadCatalog();
    loadBanners();
  }

  void setGuestMode(bool guest) {
    state = state.copyWith(isGuest: guest);
  }

  /// Called after successful phone/email OTP login
  void loginUser({
    required String name,
    required String phone,
    required String email,
    bool isNewRegistration = false,
  }) {
    final cleanPhone = phone.startsWith('+91') ? phone : '+91 $phone';
    
    // For new registrations, simulate an incomplete profile requiring completion
    if (isNewRegistration || name.trim().isEmpty) {
      final incompleteProfile = CustomerProfile.createWithCalculation(
        customerId: 'cust_${DateTime.now().millisecondsSinceEpoch}',
        userId: 'usr_${DateTime.now().millisecondsSinceEpoch}',
        fullName: name.trim(),
        phone: cleanPhone,
        isPhoneVerified: true,
        email: email,
        isEmailVerified: true,
        addresses: const [], // No address yet -> triggers completion
      );

      state = state.copyWith(
        isGuest: false,
        profile: incompleteProfile,
        address: '',
        selectedAddressTitle: '',
      );
    } else {
      // Returning user with mock address
      final completeProfile = CustomerProfile.createWithCalculation(
        customerId: 'cust_${DateTime.now().millisecondsSinceEpoch}',
        userId: 'usr_${DateTime.now().millisecondsSinceEpoch}',
        fullName: name.trim(),
        phone: cleanPhone,
        isPhoneVerified: true,
        email: email,
        isEmailVerified: true,
        addresses: [
          CustomerAddress(
            id: 'addr_${DateTime.now().millisecondsSinceEpoch}',
            customerId: 'cust_user',
            addressType: AddressType.home,
            houseFlat: 'Flat 402, Royal Palms',
            street: 'Bellary Road',
            area: 'Hebbal',
            city: 'Bengaluru',
            state: 'Karnataka',
            postalCode: '560024',
            isPrimary: true,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        ],
      );

      state = state.copyWith(
        isGuest: false,
        profile: completeProfile,
        address: completeProfile.primaryAddress?.formattedAddress ?? 'Bellary Road, Bengaluru',
        selectedAddressTitle: completeProfile.primaryAddress?.formattedAddress ?? 'Bellary Road, Bengaluru',
      );
    }
  }

  /// Update profile details & recalculate
  void updateProfileDetails({
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
  }) {
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
  }

  /// Add a new service address
  void addCustomerAddress(CustomerAddress address) {
    final currentList = [...state.profile.addresses];
    
    // If first address or marked primary, ensure others are non-primary
    final shouldBePrimary = address.isPrimary || currentList.isEmpty;
    final updatedList = currentList.map((a) => shouldBePrimary ? a.copyWith(isPrimary: false) : a).toList();
    
    updatedList.add(address.copyWith(isPrimary: shouldBePrimary));

    final updatedProfile = state.profile.copyWith(addresses: updatedList);
    final primary = updatedProfile.primaryAddress;

    state = state.copyWith(
      profile: updatedProfile,
      address: primary?.formattedAddress ?? state.address,
      selectedAddressTitle: primary?.formattedAddress ?? state.selectedAddressTitle,
      selectedAddressType: primary?.typeLabel ?? state.selectedAddressType,
    );
  }

  /// Update an existing address
  void updateCustomerAddress(CustomerAddress address) {
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
      selectedAddressTitle: primary?.formattedAddress ?? state.selectedAddressTitle,
      selectedAddressType: primary?.typeLabel ?? state.selectedAddressType,
    );
  }

  /// Delete a service address (with safety checks)
  bool deleteCustomerAddress(String addressId) {
    final currentList = [...state.profile.addresses];
    final target = currentList.firstWhere((a) => a.id == addressId, orElse: () => currentList.first);
    
    currentList.removeWhere((a) => a.id == addressId);

    // If we deleted the primary address and there are remaining addresses, promote the first one
    if (target.isPrimary && currentList.isNotEmpty) {
      currentList[0] = currentList[0].copyWith(isPrimary: true);
    }

    final updatedProfile = state.profile.copyWith(addresses: currentList);
    final primary = updatedProfile.primaryAddress;

    state = state.copyWith(
      profile: updatedProfile,
      address: primary?.formattedAddress ?? '',
      selectedAddressTitle: primary?.formattedAddress ?? '',
      selectedAddressType: primary?.typeLabel ?? 'Home',
    );

    return true;
  }

  /// Set an address as primary
  void setPrimaryAddress(String addressId) {
    final updatedList = state.profile.addresses.map((a) {
      return a.copyWith(isPrimary: a.id == addressId);
    }).toList();

    final updatedProfile = state.profile.copyWith(addresses: updatedList);
    final primary = updatedProfile.primaryAddress;

    state = state.copyWith(
      profile: updatedProfile,
      address: primary?.formattedAddress ?? state.address,
      selectedAddressTitle: primary?.formattedAddress ?? state.selectedAddressTitle,
      selectedAddressType: primary?.typeLabel ?? state.selectedAddressType,
    );
  }

  Future<void> _loadCatalog() async {
    state = state.copyWith(isCatalogLoading: true);
    await Future.delayed(const Duration(seconds: 1));
    state = state.copyWith(
      categories: MockData.categoriesList,
      isCatalogLoading: false,
    );
  }

  Future<void> loadBanners() async {
    state = state.copyWith(isBannersLoading: true);
    final prefs = await SharedPreferences.getInstance();
    
    // Load from local storage cache initially
    final cachedHeroJson = prefs.getString('bt_hero_banners_cache');
    final cachedSpotlightJson = prefs.getString('bt_spotlight_banners_cache');
    List<PromotionalBanner> initialHeroes = [];
    List<PromotionalBanner> initialSpotlights = [];
    if (cachedHeroJson != null) {
      try {
        final List decoded = jsonDecode(cachedHeroJson);
        initialHeroes = decoded.map((j) => PromotionalBanner.fromJson(j)).toList();
      } catch (_) {}
    }
    if (cachedSpotlightJson != null) {
      try {
        final List decoded = jsonDecode(cachedSpotlightJson);
        initialSpotlights = decoded.map((j) => PromotionalBanner.fromJson(j)).toList();
      } catch (_) {}
    }

    if (initialHeroes.isNotEmpty || initialSpotlights.isNotEmpty) {
      state = state.copyWith(
        heroBanners: initialHeroes.isNotEmpty ? initialHeroes : state.heroBanners,
        spotlightBanners: initialSpotlights.isNotEmpty ? initialSpotlights : state.spotlightBanners,
      );
    }

    try {
      final uri = Uri.parse('http://10.0.2.2:5000/api/banners/active?role=CUSTOMER');
      final res = await http.get(uri).timeout(const Duration(seconds: 4));

      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        final List heroList = decoded['heroBanners'] ?? [];
        final List spotlightList = decoded['spotlightBanners'] ?? [];

        final heroes = heroList.map((j) => PromotionalBanner.fromJson(j)).toList();
        final spotlights = spotlightList.map((j) => PromotionalBanner.fromJson(j)).toList();

        // Save to cache
        await prefs.setString('bt_hero_banners_cache', jsonEncode(heroList));
        await prefs.setString('bt_spotlight_banners_cache', jsonEncode(spotlightList));

        state = state.copyWith(
          heroBanners: heroes,
          spotlightBanners: spotlights,
          isBannersLoading: false,
        );
      } else {
        state = state.copyWith(isBannersLoading: false);
      }
    } catch (e) {
      debugPrint('Error fetching banners from API: $e. Falling back to cache.');
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

  void updateAddress(String address) {
    state = state.copyWith(
      address: address,
      selectedAddressTitle: address,
    );
  }

  Future<void> _recalculatePrices() async {
    state = state.copyWith(isCalculatingPrice: true);
    await Future.delayed(const Duration(milliseconds: 300));
    final base = state.cartItems.fold(0.0, (sum, s) => sum + s.price);
    final bookingCharge = base > 0 ? 99.0 : 0.0;
    final taxable = base + bookingCharge;
    final gst = taxable * 0.18;
    final total = taxable + gst;
    state = state.copyWith(
      baseCost: base,
      visitFee: bookingCharge,
      discount: 0.0,
      gstTax: gst,
      grandTotal: total,
      isCalculatingPrice: false,
    );
  }

  void confirmOrder(String date, String slot) {
    final now = DateTime.now();
    final booking = Booking(
      id: 'BKG-${now.millisecondsSinceEpoch}',
      services: [...state.cartItems],
      date: date,
      timeSlot: slot,
      status: BookingStatus.confirmed,
      baseCost: state.baseCost,
      visitFee: state.visitFee,
      discount: state.discount,
      gstTax: state.gstTax,
      grandTotal: state.grandTotal,
    );
    state = state.copyWith(
      activeBooking: booking,
      cartItems: [],
      baseCost: 0, visitFee: 99, discount: 0, gstTax: 0, grandTotal: 0,
    );
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

  Future<void> startPayment() async {
    state = state.copyWith(paymentStatus: PaymentStatus.processing, clearPaymentError: true);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_pending', true);
    await prefs.setDouble('grand_total', state.grandTotal);
  }

  Future<void> simulatePaymentOutcome(String outcome) async {
    switch (outcome) {
      case 'SUCCESS':
        await _clearPaymentSession();
        confirmOrder('Tomorrow', '10:00 AM – 11:00 AM');
        state = state.copyWith(paymentStatus: PaymentStatus.success, clearPaymentError: true);
        break;
      case 'TIMEOUT':
        state = state.copyWith(
          paymentStatus: PaymentStatus.errorTimeout,
          paymentError: 'Gateway transaction timed out. Please try again.',
        );
        break;
      case 'NETWORK_DISCONNECT':
        state = state.copyWith(
          paymentStatus: PaymentStatus.errorNetwork,
          paymentError: 'Network connection lost. Please check your internet.',
        );
        break;
      case 'APP_TERMINATION':
        // SharedPrefs remain as-is (pending=true). Reset runtime.
        state = state.copyWith(paymentStatus: PaymentStatus.idle, clearPaymentError: true);
        break;
    }
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
    await _clearPaymentSession();
    state = state.copyWith(paymentStatus: PaymentStatus.idle);
  }

  Future<void> discardRestoration() async {
    await _clearPaymentSession();
    state = state.copyWith(paymentStatus: PaymentStatus.idle);
  }

  void clearPaymentStatus() {
    state = state.copyWith(paymentStatus: PaymentStatus.idle, clearPaymentError: true);
  }

  Future<void> _clearPaymentSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }
}

final bookingProvider = StateNotifierProvider<BookingNotifier, AppState>((ref) {
  return BookingNotifier();
});
