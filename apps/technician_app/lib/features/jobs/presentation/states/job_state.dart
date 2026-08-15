import 'dart:async';
import 'dart:math' as math;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
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
    this.jobAlertCountdown = 45,
    this.proposedJob,
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
  }) {
    return JobState(
      activeJob: activeJob ?? this.activeJob,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage ?? this.errorMessage,
      isOtpVerified: isOtpVerified ?? this.isOtpVerified,
      isGpsGranted: isGpsGranted ?? this.isGpsGranted,
      socketStatus: socketStatus ?? this.socketStatus,
      isEndOtpVerified: isEndOtpVerified ?? this.isEndOtpVerified,
      endOtp: endOtp ?? this.endOtp,
      isShiftOnline: isShiftOnline ?? this.isShiftOnline,
      showJobAlert: showJobAlert ?? this.showJobAlert,
      jobAlertCountdown: jobAlertCountdown ?? this.jobAlertCountdown,
      proposedJob: proposedJob ?? this.proposedJob,
    );
  }
}

class JobStateNotifier extends StateNotifier<JobState> {
  io.Socket? _socket;
  StreamSubscription<Position>? _positionSubscription;
  Timer? _countdownTimer;

  JobStateNotifier() : super(JobState());

  @override
  void dispose() {
    _positionSubscription?.cancel();
    _countdownTimer?.cancel();
    _socket?.disconnect();
    _socket?.dispose();
    super.dispose();
  }

  // Toggle Shift online/offline
  void toggleShift(bool online) {
    state = state.copyWith(isShiftOnline: online);
    if (online) {
      _startSocketAndLocationStream();
    } else {
      _stopSocketAndLocationStream();
    }
  }

  void _startSocketAndLocationStream() {
    _stopSocketAndLocationStream();

    try {
      // Connect to Socket server (10.0.2.2 in Android Emulator maps to localhost)
      _socket = io.io('http://10.0.2.2:3000', io.OptionBuilder()
        .setTransports(['websocket'])
        .enableAutoConnect()
        .build());

      _socket!.onConnect((_) {
        debugPrint('Partner App: Socket connected to backend!');
        state = state.copyWith(socketStatus: 'CONNECTED');
        if (state.activeJob != null) {
          _socket!.emit('job:join', {'bookingId': state.activeJob!.id});
        }
      });

      _socket!.onDisconnect((_) {
        debugPrint('Partner App: Socket disconnected!');
        state = state.copyWith(socketStatus: 'DISCONNECTED');
      });

      _socket!.onConnectError((err) {
        debugPrint('Partner App: Socket Connection Error: $err');
        state = state.copyWith(socketStatus: 'RECONNECTING');
      });

      // Geolocator streams
      Geolocator.checkPermission().then((permission) {
        if (permission == LocationPermission.denied) {
          Geolocator.requestPermission();
        }
      });

      _positionSubscription = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 5,
        ),
      ).listen((Position position) {
        state = state.copyWith(isGpsGranted: true);

        // Upload location telemetries to Node.js backend
        if (_socket != null && _socket!.connected) {
          _socket!.emit('partner:location_update', {
            'partnerId': '65daf7d94e21a2001bb974c2', // Mock MongoDB ObjectId
            'bookingId': state.activeJob?.id,
            'latitude': position.latitude,
            'longitude': position.longitude,
          });
        }

        // Update local state coordinates
        if (state.activeJob != null) {
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
    } catch (e) {
      debugPrint('Socket connection initialization failed: $e');
    }
  }

  void _stopSocketAndLocationStream() {
    _positionSubscription?.cancel();
    _positionSubscription = null;
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
    state = state.copyWith(socketStatus: 'DISCONNECTED');
  }

  // Simulate an incoming service dispatch request
  void simulateIncomingJobOffer() {
    _countdownTimer?.cancel();
    final mockJob = TechJob(
      id: 'BT-${DateTime.now().millisecondsSinceEpoch % 100000}',
      title: 'Monsoon AC Service Special',
      price: 699.0,
      customerName: 'Shreya Sharma',
      customerAddress: 'Salt Lake Sector-V, Kolkata',
      status: TechJobStatus.accepted,
      otp: '4821',
    );

    state = state.copyWith(
      showJobAlert: true,
      jobAlertCountdown: 45,
      proposedJob: mockJob,
    );

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (state.jobAlertCountdown > 1) {
        state = state.copyWith(jobAlertCountdown: state.jobAlertCountdown - 1);
      } else {
        timer.cancel();
        rejectProposedJob();
      }
    });
  }

  void acceptProposedJob() {
    _countdownTimer?.cancel();
    if (state.proposedJob == null) return;

    final acceptedJob = state.proposedJob!.copyWith(status: TechJobStatus.accepted);
    state = state.copyWith(
      activeJob: acceptedJob,
      showJobAlert: false,
      proposedJob: null,
    );

    // Sync to backend via Socket
    if (_socket != null && _socket!.connected) {
      _socket!.emit('job:join', {'bookingId': acceptedJob.id});
      _socket!.emit('job:status_change', {
        'bookingId': acceptedJob.id,
        'status': 'ASSIGNED',
      });
    }
  }

  void rejectProposedJob() {
    _countdownTimer?.cancel();
    state = state.copyWith(
      showJobAlert: false,
      proposedJob: null,
    );
  }

  void toggleGpsPermission(bool granted) {
    state = state.copyWith(isGpsGranted: granted);
  }

  void setSocketStatus(String status) {
    state = state.copyWith(socketStatus: status);
  }

  void acceptJob(String id, String title, double price, String name, String address) {
    state = JobState(
      activeJob: TechJob(
        id: id,
        title: title,
        price: price,
        customerName: name,
        customerAddress: address,
        status: TechJobStatus.accepted,
        otp: '4821',
      ),
    );
  }

  void startJourney() {
    if (state.activeJob == null) return;
    state = state.copyWith(
      activeJob: state.activeJob!.copyWith(
        status: TechJobStatus.onTheWay,
        techLatitude: 12.982598,
        techLongitude: 77.585566,
        currentPathIndex: 0,
      ),
    );

    // Sync status change to backend
    if (_socket != null && _socket!.connected) {
      _socket!.emit('job:status_change', {
        'bookingId': state.activeJob!.id,
        'status': 'EN_ROUTE',
      });
    }

    _simulateMovement();
  }

  void markArrived() {
    if (state.activeJob == null) return;
    state = state.copyWith(
      activeJob: state.activeJob!.copyWith(
        status: TechJobStatus.arrived,
        techLatitude: 12.971598,
        techLongitude: 77.594566,
        currentPathIndex: 5,
      ),
    );

    if (_socket != null && _socket!.connected) {
      _socket!.emit('job:status_change', {
        'bookingId': state.activeJob!.id,
        'status': 'ARRIVED',
      });
    }
  }

  void _simulateMovement() async {
    const List<LatLng> routePoints = [
      LatLng(12.982598, 77.585566),
      LatLng(12.980300, 77.587800),
      LatLng(12.978000, 77.590000),
      LatLng(12.975700, 77.592200),
      LatLng(12.973400, 77.593800),
      LatLng(12.971598, 77.594566)
    ];

    while (state.activeJob != null && state.activeJob!.status == TechJobStatus.onTheWay) {
      await Future.delayed(const Duration(seconds: 3));
      if (state.activeJob == null || state.activeJob!.status != TechJobStatus.onTheWay) break;

      // Pause coordinates if socket is disconnected or GPS denied
      if (state.socketStatus == 'DISCONNECTED' || !state.isGpsGranted) {
        continue;
      }

      final currentIndex = state.activeJob!.currentPathIndex ?? 0;
      if (currentIndex < routePoints.length - 1) {
        final nextIndex = currentIndex + 1;
        final nextLoc = routePoints[nextIndex];

        // Stream location updates to socket in background simulation
        if (_socket != null && _socket!.connected) {
          _socket!.emit('partner:location_update', {
            'partnerId': '65daf7d94e21a2001bb974c2',
            'bookingId': state.activeJob!.id,
            'latitude': nextLoc.latitude,
            'longitude': nextLoc.longitude,
          });
        }

        // Calculate distance
        const customerLoc = LatLng(12.971598, 77.594566);
        final distance = _calculateDistance(nextLoc.latitude, nextLoc.longitude, customerLoc.latitude, customerLoc.longitude);

        if (distance <= 100) {
          state = state.copyWith(
            activeJob: state.activeJob!.copyWith(
              status: TechJobStatus.arrived,
              techLatitude: nextLoc.latitude,
              techLongitude: nextLoc.longitude,
              currentPathIndex: nextIndex,
            ),
          );
          if (_socket != null && _socket!.connected) {
            _socket!.emit('job:status_change', {
              'bookingId': state.activeJob!.id,
              'status': 'ARRIVED',
            });
          }
          break;
        } else {
          state = state.copyWith(
            activeJob: state.activeJob!.copyWith(
              techLatitude: nextLoc.latitude,
              techLongitude: nextLoc.longitude,
              currentPathIndex: nextIndex,
            ),
          );
        }
      } else {
        break;
      }
    }
  }

  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    var p = 0.017453292519943295;
    var a = 0.5 - math.cos((lat2 - lat1) * p)/2 + 
          math.cos(lat1 * p) * math.cos(lat2 * p) * 
          (1 - math.cos((lon2 - lon1) * p))/2;
    return 12742 * math.asin(math.sqrt(a)) * 1000;
  }

  Future<bool> verifyOtpOnServer(String enteredOtp) async {
    if (state.activeJob == null) return false;
    
    state = state.copyWith(isLoading: true, errorMessage: null);
    await Future.delayed(const Duration(seconds: 1));
    
    if (enteredOtp == state.activeJob!.otp) {
      state = state.copyWith(
        activeJob: state.activeJob!.copyWith(status: TechJobStatus.otpVerified),
        isOtpVerified: true,
        isLoading: false,
      );

      return true;
    } else {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Invalid OTP code. Validate again.',
      );
      return false;
    }
  }

  Future<bool> verifyEndOtpOnServer(String enteredOtp) async {
    if (state.activeJob == null) return false;

    state = state.copyWith(isLoading: true, errorMessage: null);
    await Future.delayed(const Duration(seconds: 1));

    if (enteredOtp == state.endOtp) {
      state = state.copyWith(
        isEndOtpVerified: true,
        isLoading: false,
      );
      return true;
    } else {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Invalid End OTP code. Try again.',
      );
      return false;
    }
  }

  void startService() {
    if (state.activeJob == null || !state.isOtpVerified) return;
    state = state.copyWith(
      activeJob: state.activeJob!.copyWith(status: TechJobStatus.serviceStarted),
    );

    if (_socket != null && _socket!.connected) {
      _socket!.emit('job:status_change', {
        'bookingId': state.activeJob!.id,
        'status': 'IN_PROGRESS',
      });
    }
  }

  void addAddOnWork(String name, double price, String reason) {
    if (state.activeJob == null) return;
    final newAddon = AddOnWork(
      id: 'ADD-448',
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

  void completeService() {
    if (state.activeJob == null) return;
    
    if (_socket != null && _socket!.connected) {
      _socket!.emit('job:status_change', {
        'bookingId': state.activeJob!.id,
        'status': 'COMPLETED',
      });
    }

    state = state.copyWith(
      activeJob: state.activeJob!.copyWith(status: TechJobStatus.completed),
    );
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
