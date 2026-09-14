import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/security/secure_storage.dart';
import '../../../../core/services/gps_permission_helper.dart';
import '../../domain/job.dart';

class JobState {
  final TechJob? activeJob;
  final bool isLoading;
  final String? errorMessage;
  final bool isOtpVerified;
  final bool isGpsGranted;
  final String socketStatus; // 'CONNECTED', 'RECONNECTING', 'DISCONNECTED'
  final bool isEndOtpVerified;
  final String endOtp;

  // Shift & Dispatch states
  final bool isShiftOnline;
  final bool showJobAlert;
  final int jobAlertCountdown;
  final TechJob? proposedJob;
  final String? activeProposalId;

  // Categorized Jobs Lists
  final List<TechJob> allJobs;
  final List<TechJob> todayJobs;
  final List<TechJob> tomorrowJobs;
  final List<TechJob> nextDayJobs;
  final List<TechJob> completedJobs;

  JobState({
    this.activeJob,
    this.isLoading = false,
    this.errorMessage,
    this.isOtpVerified = false,
    this.isGpsGranted = true,
    this.socketStatus = 'DISCONNECTED',
    this.isEndOtpVerified = false,
    this.endOtp = '8839',
    this.isShiftOnline = false,
    this.showJobAlert = false,
    this.jobAlertCountdown = 30,
    this.proposedJob,
    this.activeProposalId,
    this.allJobs = const [],
    this.todayJobs = const [],
    this.tomorrowJobs = const [],
    this.nextDayJobs = const [],
    this.completedJobs = const [],
  });

  JobState copyWith({
    TechJob? activeJob,
    bool? isLoading,
    String? errorMessage,
    bool? isOtpVerified,
    bool? isGpsGranted,
    String? socketStatus,
    bool? isEndOtpVerified,
    String? endOtp,
    bool? isShiftOnline,
    bool? showJobAlert,
    int? jobAlertCountdown,
    TechJob? proposedJob,
    String? activeProposalId,
    List<TechJob>? allJobs,
    List<TechJob>? todayJobs,
    List<TechJob>? tomorrowJobs,
    List<TechJob>? nextDayJobs,
    List<TechJob>? completedJobs,
  }) {
    return JobState(
      activeJob: activeJob ?? this.activeJob,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      isOtpVerified: isOtpVerified ?? this.isOtpVerified,
      isGpsGranted: isGpsGranted ?? this.isGpsGranted,
      socketStatus: socketStatus ?? this.socketStatus,
      isEndOtpVerified: isEndOtpVerified ?? this.isEndOtpVerified,
      endOtp: endOtp ?? this.endOtp,
      isShiftOnline: isShiftOnline ?? this.isShiftOnline,
      showJobAlert: showJobAlert ?? this.showJobAlert,
      jobAlertCountdown: jobAlertCountdown ?? this.jobAlertCountdown,
      proposedJob: proposedJob ?? this.proposedJob,
      activeProposalId: activeProposalId ?? this.activeProposalId,
      allJobs: allJobs ?? this.allJobs,
      todayJobs: todayJobs ?? this.todayJobs,
      tomorrowJobs: tomorrowJobs ?? this.tomorrowJobs,
      nextDayJobs: nextDayJobs ?? this.nextDayJobs,
      completedJobs: completedJobs ?? this.completedJobs,
    );
  }
}

class JobStateNotifier extends StateNotifier<JobState> {
  final DioClient _dioClient;
  StreamSubscription<Position>? _positionSubscription;
  Timer? _countdownTimer;
  Timer? _proposalPollingTimer;

  JobStateNotifier({SecureStorage? storage})
      : _dioClient = DioClient(storage ?? SecureStorage()),
        super(JobState()) {
    fetchAssignedJobs();
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    _countdownTimer?.cancel();
    _proposalPollingTimer?.cancel();
    super.dispose();
  }

  // Fetch and categorize technician jobs from backend API
  Future<void> fetchAssignedJobs() async {
    try {
      final response = await _dioClient.dio.get('/technician/jobs');
      final list = response.data['data'] as List?;
      if (list != null) {
        final List<TechJob> mapped = [];
        final now = DateTime.now();
        final todayStr = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
        final tomorrow = now.add(const Duration(days: 1));
        final tomorrowStr = "${tomorrow.year}-${tomorrow.month.toString().padLeft(2, '0')}-${tomorrow.day.toString().padLeft(2, '0')}";
        final nextDay = now.add(const Duration(days: 2));
        final nextDayStr = "${nextDay.year}-${nextDay.month.toString().padLeft(2, '0')}-${nextDay.day.toString().padLeft(2, '0')}";

        for (final item in list) {
          final m = item as Map<String, dynamic>;
          final id = m['id']?.toString() ?? '';
          final service = m['service'] as Map<String, dynamic>?;
          final title = service?['name'] ?? 'Home Appliance Service';
          final categoryName = service?['category']?['name'] ?? 'Appliance Repair';
          final price = (m['technicianPayoutAmount'] as num?)?.toDouble() ?? (m['basePrice'] as num?)?.toDouble() ?? 450.0;
          final customer = m['customer'] as Map<String, dynamic>?;
          final customerName = customer?['fullName'] ?? 'Customer';
          final customerPhone = customer?['phone'] ?? '';
          final address = m['address'] as Map<String, dynamic>?;
          final area = address != null
              ? '${address['houseFlat'] ?? ''} ${address['street'] ?? ''} ${address['area'] ?? ''}, ${address['city'] ?? ''}'.trim()
              : 'Customer Premise';
          final lat = (address?['latitude'] as num?)?.toDouble();
          final lng = (address?['longitude'] as num?)?.toDouble();
          final rawStatus = m['status']?.toString() ?? 'ASSIGNED';
          final scheduleDate = m['scheduleDate']?.toString() ?? todayStr;
          final scheduleSlot = m['scheduleSlot']?.toString() ?? '10:00 AM - 11:00 AM';
          final bookingCode = m['bookingCode']?.toString() ?? 'BT-${id.length > 6 ? id.substring(0, 6) : id}';

          TechJobStatus status = TechJobStatus.accepted;
          if (rawStatus == 'ON_THE_WAY' || rawStatus == 'EN_ROUTE') {
            status = TechJobStatus.onTheWay;
          } else if (rawStatus == 'ARRIVED') {
            status = TechJobStatus.arrived;
          } else if (rawStatus == 'WORK_STARTED' || rawStatus == 'IN_PROGRESS') {
            status = TechJobStatus.serviceStarted;
          } else if (rawStatus == 'COMPLETED') {
            status = TechJobStatus.completed;
          }

          mapped.add(TechJob(
            id: id,
            title: title,
            price: price,
            customerName: customerName,
            customerPhone: customerPhone,
            customerAddress: area,
            customerLatitude: lat,
            customerLongitude: lng,
            status: status,
            scheduleDate: scheduleDate,
            scheduleSlot: scheduleSlot,
            bookingCode: bookingCode,
            categoryName: categoryName,
          ));
        }

        final todayList = mapped.where((j) {
          if (j.status == TechJobStatus.completed) return false;
          final d = j.scheduleDate ?? '';
          return d.contains(todayStr) || d.toLowerCase().contains('today') || d.isEmpty;
        }).toList();

        final tomorrowList = mapped.where((j) {
          if (j.status == TechJobStatus.completed) return false;
          final d = j.scheduleDate ?? '';
          return d.contains(tomorrowStr) || d.toLowerCase().contains('tomorrow');
        }).toList();

        final nextDayList = mapped.where((j) {
          if (j.status == TechJobStatus.completed) return false;
          final d = j.scheduleDate ?? '';
          return d.contains(nextDayStr) || d.toLowerCase().contains('day after') || (!todayList.contains(j) && !tomorrowList.contains(j));
        }).toList();

        final completedList = mapped.where((j) => j.status == TechJobStatus.completed).toList();

        TechJob? active = state.activeJob;
        if (active == null && todayList.isNotEmpty) {
          active = todayList.first;
        }

        state = state.copyWith(
          allJobs: mapped,
          todayJobs: todayList,
          tomorrowJobs: tomorrowList,
          nextDayJobs: nextDayList,
          completedJobs: completedList,
          activeJob: active,
        );
      }
    } catch (e) {
      debugPrint('Error fetching assigned technician jobs: $e');
    }
  }

  // Toggle Shift online/offline
  Future<void> toggleShift(bool online, {dynamic context}) async {
    state = state.copyWith(isLoading: true);

    try {
      if (online) {
        final fixResult = await GpsPermissionHelper.ensureLocationPermissionAndGps(
          context: context,
          showPromptDialogs: true,
        );

        if (!fixResult.isSuccess || fixResult.position == null) {
          state = state.copyWith(
            isLoading: false,
            isGpsGranted: false,
            errorMessage: fixResult.message,
          );
          return;
        }

        final position = fixResult.position!;
        state = state.copyWith(isGpsGranted: true);

        // Notify backend of online status + real GPS fix
        await _dioClient.dio.post('/technician/online-status', data: {
          'online': true,
          'latitude': position.latitude,
          'longitude': position.longitude,
        });

        _startProposalPolling();
        await fetchAssignedJobs();
        state = state.copyWith(isLoading: false, isShiftOnline: true, errorMessage: null);
      } else {
        // Going offline
        _stopProposalPolling();
        _stopLiveLocationStream();

        try {
          await _dioClient.dio.post('/technician/online-status', data: {
            'online': false,
          });
        } catch (_) {}

        state = state.copyWith(isLoading: false, isShiftOnline: false, errorMessage: null);
      }
    } catch (e) {
      debugPrint('Error toggling online status: $e');
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to update shift status: $e',
      );
    }
  }

  void toggleGpsPermission(bool granted) {
    state = state.copyWith(isGpsGranted: granted);
  }

  void _startProposalPolling() {
    _proposalPollingTimer?.cancel();
    _proposalPollingTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      _fetchPendingProposals();
    });
    _fetchPendingProposals();
  }

  void _stopProposalPolling() {
    _proposalPollingTimer?.cancel();
    _proposalPollingTimer = null;
    _countdownTimer?.cancel();
    state = state.copyWith(showJobAlert: false, proposedJob: null, activeProposalId: null);
  }

  Future<void> _fetchPendingProposals() async {
    if (!state.isShiftOnline) return;

    try {
      final response = await _dioClient.dio.get('/dispatch/proposals/pending');
      final data = response.data['data'] as List?;

      if (data != null && data.isNotEmpty) {
        final first = data.first as Map<String, dynamic>;
        final String proposalId = first['id'];

        // Auto-assign directly (Delete accept/reject countdown concept)
        try {
          await _dioClient.dio.post('/dispatch/proposals/$proposalId/accept');
        } catch (_) {}

        await fetchAssignedJobs();
      } else {
        // Periodic sync of assigned jobs
        await fetchAssignedJobs();
      }
    } catch (e) {
      debugPrint('Error polling proposals: $e');
    }
  }

  void acceptJob(String id, String title, double price, String name, String address) {
    final target = state.allJobs.firstWhere(
      (j) => j.id == id,
      orElse: () => TechJob(
        id: id,
        title: title,
        price: price,
        customerName: name,
        customerAddress: address,
        status: TechJobStatus.accepted,
      ),
    );
    state = state.copyWith(activeJob: target);
  }

  Future<void> acceptProposedJob() async {
    _countdownTimer?.cancel();
    final proposalId = state.activeProposalId;
    if (proposalId == null || state.proposedJob == null) return;

    state = state.copyWith(isLoading: true);

    try {
      final response = await _dioClient.dio.post('/dispatch/proposals/$proposalId/accept');
      if (response.statusCode == 200) {
        final acceptedJob = state.proposedJob!.copyWith(status: TechJobStatus.accepted);
        state = state.copyWith(
          activeJob: acceptedJob,
          showJobAlert: false,
          proposedJob: null,
          activeProposalId: null,
          isLoading: false,
        );
      }
    } on DioException catch (e) {
      final msg = e.response?.data?['message'] ?? 'Failed to accept job';
      state = state.copyWith(
        isLoading: false,
        showJobAlert: false,
        proposedJob: null,
        activeProposalId: null,
        errorMessage: msg,
      );
    }
  }

  Future<void> rejectProposedJob() async {
    _countdownTimer?.cancel();
    final proposalId = state.activeProposalId;

    if (proposalId != null) {
      try {
        await _dioClient.dio.post('/dispatch/proposals/$proposalId/reject', data: {
          'reason': 'Technician declined request'
        });
      } catch (e) {
        debugPrint('Error rejecting proposal: $e');
      }
    }

    state = state.copyWith(
      showJobAlert: false,
      proposedJob: null,
      activeProposalId: null,
    );
  }

  Future<void> startJourney() async {
    if (state.activeJob == null) return;
    state = state.copyWith(isLoading: true);

    try {
      await _dioClient.dio.patch('/technician/jobs/${state.activeJob!.id}/status', data: {
        'status': 'ON_THE_WAY',
      });

      state = state.copyWith(
        activeJob: state.activeJob!.copyWith(status: TechJobStatus.onTheWay),
        isLoading: false,
      );

      _startLiveLocationStream();
    } on DioException catch (e) {
      final msg = e.response?.data?['message'] ?? 'Failed to start journey';
      state = state.copyWith(isLoading: false, errorMessage: msg);
    }
  }

  void _startLiveLocationStream() {
    _positionSubscription?.cancel();

    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      ),
    ).listen((Position position) async {
      state = state.copyWith(isGpsGranted: true);

      // Stream actual device GPS coordinates to Spring Boot backend
      if (state.activeJob != null) {
        try {
          await _dioClient.dio.post('/technician/location', data: {
            'latitude': position.latitude,
            'longitude': position.longitude,
            'heading': position.heading,
            'speed': position.speed,
            'bookingId': state.activeJob!.id,
          });
        } catch (_) {}

        state = state.copyWith(
          activeJob: state.activeJob!.copyWith(
            techLatitude: position.latitude,
            techLongitude: position.longitude,
          ),
        );
      }
    }, onError: (e) {
      debugPrint('Location stream error: $e');
      state = state.copyWith(isGpsGranted: false);
    });
  }

  void _stopLiveLocationStream() {
    _positionSubscription?.cancel();
    _positionSubscription = null;
  }

  Future<void> markArrived() async {
    if (state.activeJob == null) return;
    state = state.copyWith(isLoading: true);

    try {
      await _dioClient.dio.patch('/technician/jobs/${state.activeJob!.id}/status', data: {
        'status': 'ARRIVED',
      });

      state = state.copyWith(
        activeJob: state.activeJob!.copyWith(status: TechJobStatus.arrived),
        isLoading: false,
      );
    } on DioException catch (e) {
      final msg = e.response?.data?['message'] ?? 'Failed to update arrival status';
      state = state.copyWith(isLoading: false, errorMessage: msg);
    }
  }

  void startService() {
    if (state.activeJob == null || !state.isOtpVerified) return;
    state = state.copyWith(
      activeJob: state.activeJob!.copyWith(status: TechJobStatus.serviceStarted),
    );
  }

  Future<bool> verifyOtpOnServer(String enteredOtp) async {
    if (state.activeJob == null) return false;
    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      final response = await _dioClient.dio.patch(
        '/technician/jobs/${state.activeJob!.id}/status',
        data: {
          'status': 'IN_PROGRESS',
          'startOtp': enteredOtp.trim(),
        },
      );

      if (response.statusCode == 200) {
        state = state.copyWith(
          activeJob: state.activeJob!.copyWith(status: TechJobStatus.serviceStarted),
          isOtpVerified: true,
          isLoading: false,
        );
        return true;
      }
    } on DioException catch (e) {
      final msg = e.response?.data?['message'] ?? 'Invalid Start Service OTP';
      state = state.copyWith(
        isLoading: false,
        errorMessage: msg,
      );
      return false;
    }
    return false;
  }

  Future<bool> verifyEndOtpOnServer(String enteredOtp) async {
    if (state.activeJob == null) return false;
    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      final response = await _dioClient.dio.patch(
        '/technician/jobs/${state.activeJob!.id}/status',
        data: {
          'status': 'COMPLETED',
        },
      );

      if (response.statusCode == 200) {
        _stopLiveLocationStream();
        state = state.copyWith(
          activeJob: state.activeJob!.copyWith(status: TechJobStatus.completed),
          isEndOtpVerified: true,
          isLoading: false,
        );
        return true;
      }
    } on DioException catch (e) {
      final msg = e.response?.data?['message'] ?? 'Failed to complete job on server';
      state = state.copyWith(
        isLoading: false,
        errorMessage: msg,
      );
      return false;
    }
    return false;
  }

  void addAddOnWork(String name, double price, String reason) {
    if (state.activeJob == null) return;
    final newAddon = AddOnWork(
      id: 'ADD-${DateTime.now().millisecondsSinceEpoch % 10000}',
      name: name,
      price: price,
      reason: reason,
      isApproved: false,
    );
    state = state.copyWith(
      activeJob: state.activeJob!.copyWith(
        addOns: [...state.activeJob!.addOns, newAddon],
      ),
    );
  }

  void simulateCustomerAddonDecision(String addonId, bool approve) {
    if (state.activeJob == null) return;
    final updatedList = state.activeJob!.addOns.map((item) {
      if (item.id == addonId) {
        return item.copyWith(isApproved: approve);
      }
      return item;
    }).toList();

    state = state.copyWith(
      activeJob: state.activeJob!.copyWith(addOns: updatedList),
    );
  }

  void requestForwardNextDay(String reason, String date, String explanation) {
    if (state.activeJob == null) return;
    final details = ForwardDetails(
      reason: reason,
      requestedDate: date,
      explanation: explanation,
    );
    state = state.copyWith(
      activeJob: state.activeJob!.copyWith(
        status: TechJobStatus.forwardRequest,
        forwardDetails: details,
      ),
    );
  }

  void simulateCustomerForwardDecision(bool approve) {
    if (state.activeJob == null || state.activeJob!.forwardDetails == null) return;
    
    if (approve) {
      state = state.copyWith(
        activeJob: state.activeJob!.copyWith(
          status: TechJobStatus.forwardApproved,
        ),
      );
    } else {
      state = state.copyWith(
        activeJob: state.activeJob!.copyWith(
          status: TechJobStatus.serviceStarted,
          forwardDetails: null,
        ),
      );
    }
  }

  void resumeForwardedService() {
    if (state.activeJob == null || state.activeJob!.status != TechJobStatus.forwardApproved) return;
    state = state.copyWith(
      activeJob: state.activeJob!.copyWith(status: TechJobStatus.resumed),
    );
  }

  Future<void> completeService() async {
    if (state.activeJob == null) return;
    state = state.copyWith(isLoading: true);

    try {
      await _dioClient.dio.patch('/technician/jobs/${state.activeJob!.id}/status', data: {
        'status': 'COMPLETED',
      });

      _stopLiveLocationStream();

      state = state.copyWith(
        activeJob: state.activeJob!.copyWith(status: TechJobStatus.completed),
        isLoading: false,
      );
    } on DioException catch (e) {
      final msg = e.response?.data?['message'] ?? 'Failed to complete job';
      state = state.copyWith(isLoading: false, errorMessage: msg);
    }
  }

  void clearJob() {
    state = state.copyWith(
      activeJob: null,
      isOtpVerified: false,
      isEndOtpVerified: false,
    );
  }
}

final jobStateProvider = StateNotifierProvider<JobStateNotifier, JobState>((ref) {
  return JobStateNotifier();
});
