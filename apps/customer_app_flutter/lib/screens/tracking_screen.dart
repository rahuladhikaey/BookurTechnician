import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import '../booking_provider.dart';
import '../config/app_config.dart';
import '../models.dart';
import '../theme.dart';

class LatLngTween extends Tween<LatLng> {
  LatLngTween({super.begin, super.end});

  @override
  LatLng lerp(double t) {
    if (begin == null || end == null) return const LatLng(0, 0);
    final lat = begin!.latitude + (end!.latitude - begin!.latitude) * t;
    final lng = begin!.longitude + (end!.longitude - begin!.longitude) * t;
    return LatLng(lat, lng);
  }
}

class BookingTrackingScreen extends ConsumerStatefulWidget {
  final String bookingId;
  const BookingTrackingScreen({super.key, required this.bookingId});

  @override
  ConsumerState<BookingTrackingScreen> createState() => _BookingTrackingScreenState();
}

class _BookingTrackingScreenState extends ConsumerState<BookingTrackingScreen> with SingleTickerProviderStateMixin {
  final MapController _mapController = MapController();

  // Dynamic real GPS locations
  LatLng _customerLocation = const LatLng(12.971598, 77.594566);
  LatLng? _technicianLocation;
  double _technicianHeading = 0.0;
  double _technicianSpeed = 0.0;
  
  // Interpolation Animation for smooth movement
  late AnimationController _interpolationController;
  Animation<LatLng>? _latLngAnimation;

  // Real-Time Socket Connection
  io.Socket? _socket;
  String _socketStatus = 'CONNECTING'; // 'CONNECTED', 'RECONNECTING', 'DISCONNECTED'
  bool _showSocketSuccessBanner = false;
  Timer? _statusSyncTimer;

  @override
  void initState() {
    super.initState();
    _interpolationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    )..addListener(() {
        if (_latLngAnimation != null) {
          setState(() {
            _technicianLocation = _latLngAnimation!.value;
          });
        }
      });

    // Initialize customer address coordinates from provider
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final state = ref.read(bookingProvider);
      if (state.selectedLatitude != null && state.selectedLongitude != null) {
        setState(() {
          _customerLocation = LatLng(state.selectedLatitude!, state.selectedLongitude!);
        });
        _mapController.move(_customerLocation, 15.0);
      }
    });

    _initSocket();

    // Periodic sync with backend PostgreSQL database
    _statusSyncTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      ref.read(bookingProvider.notifier).loadBookingHistory();
    });
  }

  @override
  void dispose() {
    _statusSyncTimer?.cancel();
    _interpolationController.dispose();
    _socket?.disconnect();
    _socket?.dispose();
    super.dispose();
  }

  void _initSocket() {
    try {
      _socket = io.io(AppConfig.socketUrl, io.OptionBuilder()
        .setTransports(['websocket'])
        .enableAutoConnect()
        .build());

      _socket!.onConnect((_) {
        debugPrint('Socket connected to backend tracking server!');
        _socket!.emit('job:join', {'bookingId': widget.bookingId});
        if (mounted) {
          setState(() {
            _socketStatus = 'CONNECTED';
            _showSocketSuccessBanner = true;
          });
        }

        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) {
            setState(() {
              _showSocketSuccessBanner = false;
            });
          }
        });
      });

      _socket!.onDisconnect((_) {
        debugPrint('Socket disconnected!');
        if (mounted) {
          setState(() {
            _socketStatus = 'DISCONNECTED';
            _showSocketSuccessBanner = false;
          });
        }
      });

      _socket!.onConnectError((err) {
        debugPrint('Socket Connection Error: $err');
        if (mounted) {
          setState(() {
            _socketStatus = 'RECONNECTING';
          });
        }
      });

      // Listen to live technician coordinates streamed from real GPS device
      _socket!.on('job:partner_location', (data) {
        if (data != null && data['latitude'] != null && data['longitude'] != null) {
          final double lat = (data['latitude'] as num).toDouble();
          final double lng = (data['longitude'] as num).toDouble();
          final double heading = (data['heading'] as num?)?.toDouble() ?? 0.0;
          final double speed = (data['speed'] as num?)?.toDouble() ?? 0.0;
          _onTechnicianLocationReceived(LatLng(lat, lng), heading, speed);
        }
      });

      // Listen to live telemetry updates
      _socket!.on('telemetry', (data) {
        if (data != null && data['latitude'] != null && data['longitude'] != null) {
          final double lat = (data['latitude'] as num).toDouble();
          final double lng = (data['longitude'] as num).toDouble();
          final double heading = (data['heading'] as num?)?.toDouble() ?? 0.0;
          final double speed = (data['speed'] as num?)?.toDouble() ?? 0.0;
          _onTechnicianLocationReceived(LatLng(lat, lng), heading, speed);
        }
      });

      // Listen to live status updates
      _socket!.on('job:status_update', (data) {
        final String? newStatus = data?['status']?.toString();
        debugPrint('Live Status Update received: $newStatus');
        
        if (newStatus != null) {
          BookingStatus status = BookingStatus.techAssigned;
          if (newStatus == 'ASSIGNED') {
            status = BookingStatus.techAssigned;
          } else if (newStatus == 'ON_THE_WAY' || newStatus == 'EN_ROUTE') {
            status = BookingStatus.techOnTheWay;
          } else if (newStatus == 'ARRIVED') {
            status = BookingStatus.techArrived;
          } else if (newStatus == 'IN_PROGRESS') {
            status = BookingStatus.serviceStarted;
          } else if (newStatus == 'COMPLETED') {
            status = BookingStatus.completed;
          }

          ref.read(bookingProvider.notifier).setBookingStatus(status);
        }
      });
    } catch (e) {
      debugPrint('Socket Initialization Failed: $e');
    }
  }

  void _onTechnicianLocationReceived(LatLng newLocation, double heading, double speed) {
    if (!mounted) return;

    setState(() {
      _technicianHeading = heading;
      _technicianSpeed = speed;
    });

    final startLoc = _technicianLocation ?? newLocation;
    final endLoc = newLocation;

    _latLngAnimation = LatLngTween(begin: startLoc, end: endLoc).animate(
      CurvedAnimation(parent: _interpolationController, curve: Curves.easeInOut),
    );
    _interpolationController.reset();
    _interpolationController.forward();

    // Center map around midpoint between customer and technician
    final midLat = (_customerLocation.latitude + newLocation.latitude) / 2;
    final midLng = (_customerLocation.longitude + newLocation.longitude) / 2;
    _mapController.move(LatLng(midLat, midLng), 14.5);
  }

  double _haversineDistance(double lat1, double lon1, double lat2, double lon2) {
    const r = 6371000.0; // Earth radius in meters
    final dLat = _toRad(lat2 - lat1);
    final dLon = _toRad(lon2 - lon1);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRad(lat1)) * cos(_toRad(lat2)) * sin(dLon / 2) * sin(dLon / 2);
    return r * 2 * atan2(sqrt(a), sqrt(1 - a));
  }

  double _toRad(double deg) => deg * pi / 180;

  String _calculateEta() {
    if (_technicianLocation == null) {
      return "Calculating...";
    }
    final distMeters = _haversineDistance(
      _technicianLocation!.latitude, _technicianLocation!.longitude,
      _customerLocation.latitude, _customerLocation.longitude,
    );

    if (distMeters < 50) {
      return "Arrived at location";
    }

    final speed = _technicianSpeed > 1.0 ? _technicianSpeed : 7.0;
    final seconds = distMeters / speed;

    if (seconds < 60) {
      return "Under 1 min (${distMeters.round()} m)";
    }
    final minutes = (seconds / 60).round();
    final km = (distMeters / 1000.0).toStringAsFixed(1);
    return "$minutes mins ($km km)";
  }

  void _callTechnician(String phone) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Row(
          children: [
            Icon(Icons.phone_locked, color: kBrandPrimary),
            SizedBox(width: 8),
            Text("Privacy Masked Call"),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "BookUrTechnician masks telephone numbers to protect the privacy of both clients and service partners.",
              style: TextStyle(fontSize: 13, color: kTextGray),
            ),
            const SizedBox(height: 16),
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  phone.isNotEmpty ? "Calling $phone" : "Calling Service Partner",
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: kTextNavy),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Call Now"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(bookingProvider);
    final booking = state.activeBooking;

    if (booking == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Booking Tracking')),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.check_circle_outline, size: 64, color: kGreenSuccess),
              SizedBox(height: 16),
              Text('No active in-flight booking', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              SizedBox(height: 8),
              Text('Your completed and past service orders are in History.', style: TextStyle(color: kTextGray, fontSize: 13)),
            ],
          ),
        ),
      );
    }

    final routePoints = <LatLng>[
      if (_technicianLocation != null && booking.status == BookingStatus.techOnTheWay) ...[
        _technicianLocation!,
        _customerLocation,
      ]
    ];

    return Scaffold(
      body: Stack(
        children: [
          // 1. OpenStreetMap Map View
          Positioned.fill(
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: _technicianLocation ?? _customerLocation,
                initialZoom: 15.0,
                maxZoom: 18,
                minZoom: 10,
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.bookurtechnician.customer',
                ),
                
                // Real-time dynamic route line
                if (routePoints.isNotEmpty)
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: routePoints,
                        color: kBrandPrimary,
                        strokeWidth: 4.0,
                      ),
                    ],
                  ),

                // Markers layer for OSM
                MarkerLayer(
                  markers: [
                    // Customer Pin
                    Marker(
                      point: _customerLocation,
                      width: 44,
                      height: 44,
                      child: const Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.home, color: Colors.blueAccent, size: 32),
                        ],
                      ),
                    ),

                    // Live Moving Technician Marker
                    if (_technicianLocation != null &&
                        (booking.status == BookingStatus.techOnTheWay ||
                         booking.status == BookingStatus.techArrived ||
                         booking.status == BookingStatus.serviceStarted))
                      Marker(
                        point: _technicianLocation!,
                        width: 46,
                        height: 46,
                        child: Transform.rotate(
                          angle: (_technicianHeading * pi / 180),
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 6)],
                              border: Border.all(color: kBrandPrimary, width: 2),
                            ),
                            padding: const EdgeInsets.all(4),
                            child: const Icon(Icons.navigation, color: kBrandPrimary, size: 24),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),

          // 2. Safe Area Headers & Socket Live Alerts
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.black.withValues(alpha: 0.5), Colors.transparent],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              child: SafeArea(
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: Colors.white,
                            radius: 20,
                            child: IconButton(
                              icon: const Icon(Icons.arrow_back, color: kTextNavy),
                              onPressed: () => Navigator.pop(context),
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text(
                              'Live Service Tracking',
                              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Socket Alert banners
                    if (_socketStatus == 'RECONNECTING')
                      Container(
                        color: kYellowWarning,
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Connecting to real-time dispatch network...',
                              style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      )
                    else if (_showSocketSuccessBanner)
                      Container(
                        color: kGreenSuccess,
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.check_circle, size: 14, color: Colors.white),
                            SizedBox(width: 8),
                            Text(
                              'Live GPS Connected. Streaming partner coordinates.',
                              style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),

          // 3. Floating Bottom Info Card
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 15,
                    spreadRadius: 2,
                    offset: const Offset(0, -5),
                  )
                ],
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 36,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // ETA or Status Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              booking.status == BookingStatus.techOnTheWay
                                  ? 'Technician is en route'
                                  : booking.status == BookingStatus.techArrived
                                      ? 'Technician has arrived!'
                                      : booking.status == BookingStatus.serviceStarted
                                          ? 'Service work started'
                                          : booking.status == BookingStatus.completed
                                              ? 'Service completed'
                                              : 'Technician Assigned',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: kTextNavy),
                            ),
                            if (booking.status == BookingStatus.techOnTheWay) ...[
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  const Icon(Icons.timer_outlined, size: 14, color: kTextGray),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Estimated Arrival: ${_calculateEta()}',
                                    style: const TextStyle(color: kBrandPrimary, fontWeight: FontWeight.w600, fontSize: 13),
                                  ),
                                ],
                              ),
                            ]
                          ],
                        ),
                        if (booking.status == BookingStatus.techOnTheWay && _socketStatus == 'CONNECTED')
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: kGreenSuccess.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Row(
                              children: [
                                SizedBox(
                                  width: 6,
                                  height: 6,
                                  child: CircularProgressIndicator(strokeWidth: 1.5, color: kGreenSuccess),
                                ),
                                SizedBox(width: 6),
                                Text('LIVE GPS', style: TextStyle(color: kGreenSuccess, fontSize: 9, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Stepper timeline
                    _buildStepperTimeline(booking.status),

                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 16),

                    // Technician details Card
                    Row(
                      children: [
                        Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            image: const DecorationImage(
                              image: NetworkImage('https://images.unsplash.com/photo-1540569014015-19a7be504e3a?w=100'),
                              fit: BoxFit.cover,
                            ),
                            border: Border.all(color: Colors.grey.shade200, width: 1.5),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                booking.technicianName.isNotEmpty ? booking.technicianName : 'Verified Partner',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: kTextNavy),
                              ),
                              const Row(
                                children: [
                                  Icon(Icons.verified, color: kBrandPrimary, size: 14),
                                  SizedBox(width: 4),
                                  Text(
                                    'KYC Verified • Background Checked',
                                    style: TextStyle(color: kTextGray, fontSize: 11, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        CircleAvatar(
                          backgroundColor: kBrandPrimary.withValues(alpha: 0.1),
                          radius: 20,
                          child: IconButton(
                            icon: const Icon(Icons.phone, size: 16, color: kBrandPrimary),
                            onPressed: () => _callTechnician(booking.technicianPhone),
                          ),
                        ),
                      ],
                    ),

                    // Start Job OTP Panel
                    if (booking.status == BookingStatus.techArrived || booking.status == BookingStatus.techOnTheWay) ...[
                      const SizedBox(height: 16),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: kBrandPrimary.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: kBrandPrimary.withValues(alpha: 0.15)),
                        ),
                        child: Column(
                          children: [
                            const Text(
                              'Service Start OTP Code',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: kBrandPrimary),
                            ),
                            const SizedBox(height: 2),
                            const Text(
                              'Share this code with your technician upon arrival to authorize work:',
                              style: TextStyle(fontSize: 11, color: kTextGray),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 10),
                            Container(
                              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 24),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: kBrandPrimary.withValues(alpha: 0.1)),
                              ),
                              child: Text(
                                booking.otpCode.isNotEmpty ? booking.otpCode : '4821',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 26,
                                  color: kBrandPrimary,
                                  letterSpacing: 8,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ] else if (booking.status == BookingStatus.serviceStarted) ...[
                      const SizedBox(height: 16),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: kGreenSuccess.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: kGreenSuccess.withValues(alpha: 0.15)),
                        ),
                        child: const Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.build_circle, color: kGreenSuccess, size: 18),
                                SizedBox(width: 6),
                                Text(
                                  'Work In Progress',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: kGreenSuccess),
                                ),
                              ],
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Your technician is executing the required service. You will receive an invoice upon completion.',
                              style: TextStyle(fontSize: 11, color: kTextGray),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildStepperTimeline(BookingStatus status) {
    final steps = [
      _StepperStep('Assigned', BookingStatus.techAssigned),
      _StepperStep('En Route', BookingStatus.techOnTheWay),
      _StepperStep('In Progress', BookingStatus.serviceStarted),
      _StepperStep('Completed', BookingStatus.completed),
    ];

    int currentIdx = 0;
    if (status == BookingStatus.techOnTheWay) {
      currentIdx = 1;
    } else if (status == BookingStatus.techArrived || status == BookingStatus.serviceStarted) {
      currentIdx = 2;
    } else if (status == BookingStatus.completed) {
      currentIdx = 3;
    }

    return Row(
      children: steps.asMap().entries.map((entry) {
        final idx = entry.key;
        final step = entry.value;
        final isDone = idx <= currentIdx;
        final isLast = idx == steps.length - 1;

        return Expanded(
          child: Row(
            children: [
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isDone ? kBrandPrimary : Colors.grey.shade200,
                      border: idx == currentIdx
                          ? Border.all(color: kBrandPrimary.withValues(alpha: 0.3), width: 4)
                          : null,
                    ),
                    child: isDone
                        ? const Icon(Icons.check, color: Colors.white, size: 12)
                        : null,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    step.label,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: isDone ? FontWeight.bold : FontWeight.normal,
                      color: isDone ? kBrandPrimary : kTextGray,
                    ),
                  ),
                ],
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    height: 2,
                    margin: const EdgeInsets.only(bottom: 16),
                    color: idx < currentIdx ? kBrandPrimary : Colors.grey.shade200,
                  ),
                ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _StepperStep {
  final String label;
  final BookingStatus status;
  const _StepperStep(this.label, this.status);
}
