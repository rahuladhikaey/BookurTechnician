import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import '../data/technician_banner_service.dart';
import '../domain/technician_banner.dart';

enum ActiveJobStep {
  accepted,
  onTheWay,
  arrived,
  serviceStarted,
  completed,
}

class ActiveJobModel {
  final String id;
  final String title;
  final String customerName;
  final String customerAddress;
  final String customerPhone;
  final double distanceKm;
  final int travelMinutes;
  final double price;
  final ActiveJobStep step;

  const ActiveJobModel({
    required this.id,
    required this.title,
    required this.customerName,
    required this.customerAddress,
    this.customerPhone = '+91 98765 43210',
    this.distanceKm = 2.4,
    this.travelMinutes = 8,
    this.price = 399.0,
    this.step = ActiveJobStep.onTheWay,
  });

  ActiveJobModel copyWith({
    String? id,
    String? title,
    String? customerName,
    String? customerAddress,
    String? customerPhone,
    double? distanceKm,
    int? travelMinutes,
    double? price,
    ActiveJobStep? step,
  }) {
    return ActiveJobModel(
      id: id ?? this.id,
      title: title ?? this.title,
      customerName: customerName ?? this.customerName,
      customerAddress: customerAddress ?? this.customerAddress,
      customerPhone: customerPhone ?? this.customerPhone,
      distanceKm: distanceKm ?? this.distanceKm,
      travelMinutes: travelMinutes ?? this.travelMinutes,
      price: price ?? this.price,
      step: step ?? this.step,
    );
  }
}

class JobProposalModel {
  final String id;
  final String title;
  final String customerName;
  final String customerAddress;
  final double distanceKm;
  final int travelMinutes;
  final double estimatedEarning;
  final int countdownSeconds;

  const JobProposalModel({
    required this.id,
    required this.title,
    required this.customerName,
    required this.customerAddress,
    required this.distanceKm,
    required this.travelMinutes,
    required this.estimatedEarning,
    this.countdownSeconds = 25,
  });

  JobProposalModel copyWith({
    String? id,
    String? title,
    String? customerName,
    String? customerAddress,
    double? distanceKm,
    int? travelMinutes,
    double? estimatedEarning,
    int? countdownSeconds,
  }) {
    return JobProposalModel(
      id: id ?? this.id,
      title: title ?? this.title,
      customerName: customerName ?? this.customerName,
      customerAddress: customerAddress ?? this.customerAddress,
      distanceKm: distanceKm ?? this.distanceKm,
      travelMinutes: travelMinutes ?? this.travelMinutes,
      estimatedEarning: estimatedEarning ?? this.estimatedEarning,
      countdownSeconds: countdownSeconds ?? this.countdownSeconds,
    );
  }
}

class PayoutTransaction {
  final String id;
  final String date;
  final double amount;
  final String upiId;
  final String status;

  const PayoutTransaction({
    required this.id,
    required this.date,
    required this.amount,
    required this.upiId,
    this.status = 'Settled (Instant UPI)',
  });
}

class DashboardState {
  final bool isOnline;
  final List<TechnicianBanner> banners;
  final bool isLoadingBanners;
  
  // Real-time GPS Location
  final double? currentLatitude;
  final double? currentLongitude;
  final String currentLocationAddress;
  final bool isFetchingLocation;

  // Stats
  final int todayJobsCount;
  final double todayEarnings;
  final int completedJobsCount;
  final double rating;

  // Weekly Stats & Wallet
  final double weeklyEarnings;
  final int weeklyCompletedJobs;
  final double platformFee;
  final double netEarnings;

  // UPI Withdrawal Data
  final String savedUpiId;
  final List<PayoutTransaction> payoutHistory;

  // Performance
  final double acceptanceRate;
  final double completionRate;

  // Active Proposal / Incoming Request
  final JobProposalModel? currentProposal;
  final int proposalCountdown;
  
  // Active Running Job
  final ActiveJobModel? activeJob;

  DashboardState({
    required this.isOnline,
    required this.banners,
    this.isLoadingBanners = false,
    this.currentLatitude = 12.9716,
    this.currentLongitude = 77.5946,
    this.currentLocationAddress = 'Bellary Road, Bengaluru',
    this.isFetchingLocation = false,
    this.todayJobsCount = 4,
    this.todayEarnings = 1850.0,
    this.completedJobsCount = 3,
    this.rating = 4.8,
    this.weeklyEarnings = 12450.0,
    this.weeklyCompletedJobs = 24,
    this.platformFee = 1245.0,
    this.netEarnings = 11205.0,
    this.savedUpiId = 'rahulsharma@sbi',
    this.payoutHistory = const [
      PayoutTransaction(id: 'PAY-8392019A', date: '10 Aug 2026', amount: 4580.0, upiId: 'rahulsharma@sbi'),
      PayoutTransaction(id: 'PAY-7482910D', date: '03 Aug 2026', amount: 6240.0, upiId: 'rahulsharma@sbi'),
    ],
    this.acceptanceRate = 98.0,
    this.completionRate = 96.0,
    this.currentProposal,
    this.proposalCountdown = 25,
    this.activeJob,
  });

  DashboardState copyWith({
    bool? isOnline,
    List<TechnicianBanner>? banners,
    bool? isLoadingBanners,
    double? currentLatitude,
    double? currentLongitude,
    String? currentLocationAddress,
    bool? isFetchingLocation,
    int? todayJobsCount,
    double? todayEarnings,
    int? completedJobsCount,
    double? rating,
    double? weeklyEarnings,
    int? weeklyCompletedJobs,
    double? platformFee,
    double? netEarnings,
    String? savedUpiId,
    List<PayoutTransaction>? payoutHistory,
    double? acceptanceRate,
    double? completionRate,
    JobProposalModel? currentProposal,
    bool clearProposal = false,
    int? proposalCountdown,
    ActiveJobModel? activeJob,
    bool clearActiveJob = false,
  }) {
    return DashboardState(
      isOnline: isOnline ?? this.isOnline,
      banners: banners ?? this.banners,
      isLoadingBanners: isLoadingBanners ?? this.isLoadingBanners,
      currentLatitude: currentLatitude ?? this.currentLatitude,
      currentLongitude: currentLongitude ?? this.currentLongitude,
      currentLocationAddress: currentLocationAddress ?? this.currentLocationAddress,
      isFetchingLocation: isFetchingLocation ?? this.isFetchingLocation,
      todayJobsCount: todayJobsCount ?? this.todayJobsCount,
      todayEarnings: todayEarnings ?? this.todayEarnings,
      completedJobsCount: completedJobsCount ?? this.completedJobsCount,
      rating: rating ?? this.rating,
      weeklyEarnings: weeklyEarnings ?? this.weeklyEarnings,
      weeklyCompletedJobs: weeklyCompletedJobs ?? this.weeklyCompletedJobs,
      platformFee: platformFee ?? this.platformFee,
      netEarnings: netEarnings ?? this.netEarnings,
      savedUpiId: savedUpiId ?? this.savedUpiId,
      payoutHistory: payoutHistory ?? this.payoutHistory,
      acceptanceRate: acceptanceRate ?? this.acceptanceRate,
      completionRate: completionRate ?? this.completionRate,
      currentProposal: clearProposal ? null : (currentProposal ?? this.currentProposal),
      proposalCountdown: proposalCountdown ?? this.proposalCountdown,
      activeJob: clearActiveJob ? null : (activeJob ?? this.activeJob),
    );
  }
}

class DashboardNotifier extends StateNotifier<DashboardState> {
  Timer? _countdownTimer;

  DashboardNotifier()
      : super(
          DashboardState(
            isOnline: true,
            banners: TechnicianBanner.getDefaultBanners(),
            currentProposal: const JobProposalModel(
              id: 'SR-92841',
              title: 'AC Service',
              customerName: 'Amit Kumar',
              customerAddress: 'Flat 302, Green Glen Layout, Bellandur, Bengaluru',
              distanceKm: 2.4,
              travelMinutes: 8,
              estimatedEarning: 399.0,
              countdownSeconds: 25,
            ),
            proposalCountdown: 25,
          ),
        ) {
    _initBanners();
    _startCountdownTimer();
  }

  Future<void> _initBanners() async {
    state = state.copyWith(isLoadingBanners: true);
    final banners = await TechnicianBannerService.fetchActiveBanners();
    state = state.copyWith(banners: banners, isLoadingBanners: false);
  }

  void _startCountdownTimer() {
    _countdownTimer?.cancel();
    if (state.currentProposal == null) return;

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (state.proposalCountdown > 1) {
        state = state.copyWith(proposalCountdown: state.proposalCountdown - 1);
      } else {
        timer.cancel();
        rejectProposal();
      }
    });
  }

  /// ─── AUTOMATIC GPS LOCATION ACCESS ON ONLINE TOGGLE ───────────────────────
  Future<void> toggleOnline(bool val) async {
    HapticFeedback.mediumImpact();
    state = state.copyWith(isOnline: val);

    if (val) {
      // Automatically fetch current GPS location upon going online
      await fetchAndUpdateLocation();

      if (state.activeJob == null && state.currentProposal == null) {
        simulateNewBookingRequest();
      }
    } else {
      // Going offline rejects pending proposals
      rejectProposal();
    }
  }

  Future<void> fetchAndUpdateLocation() async {
    state = state.copyWith(isFetchingLocation: true);
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.whileInUse || permission == LocationPermission.always) {
        final position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: const Duration(seconds: 5),
        );
        state = state.copyWith(
          currentLatitude: position.latitude,
          currentLongitude: position.longitude,
          currentLocationAddress: 'GPS: ${position.latitude.toStringAsFixed(4)}° N, ${position.longitude.toStringAsFixed(4)}° E (Bengaluru)',
          isFetchingLocation: false,
        );
      } else {
        // Fallback default mock coordinates if permission was denied
        state = state.copyWith(
          currentLatitude: 12.9716,
          currentLongitude: 77.5946,
          currentLocationAddress: 'Bellary Road, Bengaluru (Simulated)',
          isFetchingLocation: false,
        );
      }
    } catch (_) {
      state = state.copyWith(
        currentLatitude: 12.9716,
        currentLongitude: 77.5946,
        currentLocationAddress: 'Bellary Road, Bengaluru',
        isFetchingLocation: false,
      );
    }
  }

  /// ─── UPI INSTANT WITHDRAWAL & WALLET ACTIONS ──────────────────────────────
  bool withdrawToUpi({required double amount, required String upiId}) {
    if (amount <= 0 || amount > state.netEarnings) {
      return false;
    }

    HapticFeedback.heavyImpact();
    final newTxnId = 'PAY-${1000000 + DateTime.now().millisecondsSinceEpoch % 9000000}';
    final now = DateTime.now();
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final dateStr = '${now.day} ${months[now.month - 1]} ${now.year}';

    final newTxn = PayoutTransaction(
      id: newTxnId,
      date: dateStr,
      amount: amount,
      upiId: upiId,
      status: 'Settled (Instant UPI: $upiId)',
    );

    state = state.copyWith(
      netEarnings: state.netEarnings - amount,
      payoutHistory: [newTxn, ...state.payoutHistory],
      savedUpiId: upiId,
    );
    return true;
  }

  void updateUpiId(String newUpiId) {
    HapticFeedback.selectionClick();
    state = state.copyWith(savedUpiId: newUpiId);
  }

  void acceptProposal() {
    HapticFeedback.heavyImpact();
    _countdownTimer?.cancel();
    final proposal = state.currentProposal;
    if (proposal != null) {
      state = state.copyWith(
        clearProposal: true,
        activeJob: ActiveJobModel(
          id: proposal.id,
          title: proposal.title,
          customerName: proposal.customerName,
          customerAddress: proposal.customerAddress,
          distanceKm: proposal.distanceKm,
          travelMinutes: proposal.travelMinutes,
          price: proposal.estimatedEarning,
          step: ActiveJobStep.onTheWay,
        ),
      );
    }
  }

  void rejectProposal() {
    HapticFeedback.lightImpact();
    _countdownTimer?.cancel();
    state = state.copyWith(clearProposal: true);
  }

  void updateActiveJobStep(ActiveJobStep nextStep) {
    HapticFeedback.selectionClick();
    if (state.activeJob != null) {
      if (nextStep == ActiveJobStep.completed) {
        state = state.copyWith(
          todayEarnings: state.todayEarnings + state.activeJob!.price,
          todayJobsCount: state.todayJobsCount + 1,
          completedJobsCount: state.completedJobsCount + 1,
          clearActiveJob: true,
        );
      } else {
        state = state.copyWith(
          activeJob: state.activeJob!.copyWith(step: nextStep),
        );
      }
    }
  }

  void addEarnings(double amount) {
    state = state.copyWith(
      todayEarnings: state.todayEarnings + amount,
      todayJobsCount: state.todayJobsCount + 1,
      completedJobsCount: state.completedJobsCount + 1,
      weeklyEarnings: state.weeklyEarnings + amount,
      weeklyCompletedJobs: state.weeklyCompletedJobs + 1,
      netEarnings: state.netEarnings + (amount * 0.9),
    );
  }

  void resetProposal() {
    simulateNewBookingRequest();
  }

  void simulateNewBookingRequest() {
    _countdownTimer?.cancel();
    state = state.copyWith(
      currentProposal: const JobProposalModel(
        id: 'SR-92841',
        title: 'AC Service',
        customerName: 'Amit Kumar',
        customerAddress: 'Flat 302, Green Glen Layout, Bellandur, Bengaluru',
        distanceKm: 2.4,
        travelMinutes: 8,
        estimatedEarning: 399.0,
        countdownSeconds: 25,
      ),
      proposalCountdown: 25,
    );
    _startCountdownTimer();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }
}

final dashboardProvider =
    StateNotifierProvider<DashboardNotifier, DashboardState>((ref) {
  return DashboardNotifier();
});
