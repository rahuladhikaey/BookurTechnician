import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/security/secure_storage.dart';
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
        super(JobState());

  @override
  void dispose() {
    _positionSubscription?.cancel();
    _countdownTimer?.cancel();
    _proposalPollingTimer?.cancel();
    super.dispose();
  }

  // Toggle Shift online/offline
  Future<void> toggleShift(bool online) async {
    state = state.copyWith(isShiftOnline: online, isLoading: true);

    try {
      Position? currentPosition;
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.always || permission == LocationPermission.whileInUse) {
        state = state.copyWith(isGpsGranted: true);
        try {
          currentPosition = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.high,
            timeLimit: const Duration(seconds: 10),
          );
        } catch (_) {}
      } else {
        state = state.copyWith(isGpsGranted: false);
      }

      // Notify backend of online/offline status + real GPS fix
      await _dioClient.dio.post('/technician/online-status', data: {
        'online': online,
        'latitude': currentPosition?.latitude,
        'longitude': currentPosition?.longitude,
      });

      if (online) {
        _startProposalPolling();
      } else {
        _stopProposalPolling();
        _stopLiveLocationStream();
      }

      state = state.copyWith(isLoading: false, isShiftOnline: online);
    } catch (e) {
      debugPrint('Error toggling online status: $e');
      state = state.copyWith(isLoading: false, errorMessage: 'Failed to update shift status.');
    }
  }

  void toggleGpsPermission(bool granted) {
    state = state.copyWith(isGpsGranted: granted);
  }

  void _startProposalPolling() {
    _proposalPollingTimer?.cancel();
    _proposalPollingTimer = Timer.periodic(const Duration(seconds: 3), (_) {
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
    if (!state.isShiftOnline || state.activeJob != null) return;

    try {
      final response = await _dioClient.dio.get('/dispatch/proposals/pending');
      final data = response.data['data'] as List?;

      if (data != null && data.isNotEmpty) {
        final first = data.first as Map<String, dynamic>;
        final String proposalId = first['id'];
        final booking = first['booking'] as Map<String, dynamic>?;

        if (booking != null && state.activeProposalId != proposalId) {
          final String bookingId = booking['id'];
          final String bookingCode = booking['bookingCode'] ?? 'BT-REQ';
          final service = booking['service'] as Map<String, dynamic>?;
          final address = booking['address'] as Map<String, dynamic>?;
          final String title = service?['name'] ?? 'Home Appliance Repair';
          final double price = (first['estimatedEarnings'] != null)
              ? (first['estimatedEarnings'] as num).toDouble()
              : (booking['technicianPayoutAmount'] as num?)?.toDouble() ?? 450.0;
          final String area = address != null ? '${address['area'] ?? ''}, ${address['city'] ?? ''}' : 'Customer Location';

          final proposedJob = TechJob(
            id: bookingId,
            title: '$title ($bookingCode)',
            price: price,
            customerName: 'Customer',
            customerAddress: area,
            status: TechJobStatus.accepted,
          );

          state = state.copyWith(
            showJobAlert: true,
            proposedJob: proposedJob,
            activeProposalId: proposalId,
            jobAlertCountdown: 30,
          );

          _startCountdownTimer();
        }
      }
    } catch (e) {
      debugPrint('Error polling proposals: $e');
    }
  }

  void _startCountdownTimer() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (state.jobAlertCountdown <= 1) {
        timer.cancel();
        state = state.copyWith(showJobAlert: false, proposedJob: null, activeProposalId: null);
      } else {
        state = state.copyWith(jobAlertCountdown: state.jobAlertCountdown - 1);
      }
    });
  }

  void acceptJob(String id, String title, double price, String name, String address) {
    state = state.copyWith(
      activeJob: TechJob(
        id: id,
        title: title,
        price: price,
        customerName: name,
        customerAddress: address,
        status: TechJobStatus.accepted,
      ),
    );
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
