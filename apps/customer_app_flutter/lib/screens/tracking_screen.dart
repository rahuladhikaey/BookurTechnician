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
    if (begin == null || end == null) return LatLng(0, 0);
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
  final _otpCtrl = TextEditingController();
  String? _otpError;
  static final _customerLoc = LatLng(12.971598, 77.594566);

  LatLng _interpolatedLocation = LatLng(12.982598, 77.585566);
  
  // Interpolation Animation
  late AnimationController _interpolationController;
  Animation<LatLng>? _latLngAnimation;

  // Real-Time Socket Connection & GPS Permissions Status
  io.Socket? _socket;
  String _socketStatus = 'DISCONNECTED'; // 'CONNECTED', 'RECONNECTING', 'DISCONNECTED'
  bool _isGpsGranted = true;
  bool _showSocketSuccessBanner = false;
  Timer? _statusSyncTimer;

  @override
  void initState() {
    super.initState();
    _interpolationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..addListener(() {
        if (_latLngAnimation != null) {
          setState(() {
            _interpolatedLocation = _latLngAnimation!.value;
          });
        }
      });

    _initSocket();

    // Fallback periodic sync with PostgreSQL
    _statusSyncTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      ref.read(bookingProvider.notifier).loadBookingHistory();
    });
  }

  @override
  void dispose() {
    _statusSyncTimer?.cancel();
    _interpolationController.dispose();
    _otpCtrl.dispose();
    _socket?.disconnect();
    _socket?.dispose();
    super.dispose();
  }

  void _initSocket() {
    try {
      // Connect to the real-time telemetry socket server
      _socket = io.io(AppConfig.socketUrl, io.OptionBuilder()
        .setTransports(['websocket'])
        .enableAutoConnect()
        .build());

      _socket!.onConnect((_) {
        debugPrint('Socket connected to backend!');
        _socket!.emit('job:join', {'bookingId': widget.bookingId});
        setState(() {
          _socketStatus = 'CONNECTED';
          _showSocketSuccessBanner = true;
        });

        // Hide success banner after 2s
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            setState(() {
              _showSocketSuccessBanner = false;
            });
          }
        });
      });

      _socket!.onDisconnect((_) {
        debugPrint('Socket disconnected!');
        setState(() {
          _socketStatus = 'DISCONNECTED';
          _showSocketSuccessBanner = false;
        });
      });

      _socket!.onConnectError((err) {
        debugPrint('Socket Connection Error: $err');
        setState(() {
          _socketStatus = 'RECONNECTING';
        });
      });

      // Listen to live partner coordinates updates
      _socket!.on('job:partner_location', (data) {
        final double lat = data['latitude'];
        final double lng = data['longitude'];
        _onPartnerLocationUpdate(LatLng(lat, lng));
      });

      // Listen to live status updates
      _socket!.on('job:status_update', (data) {
        final String newStatus = data['status'];
        debugPrint('Live Status Sync from Server: $newStatus');
        
        BookingStatus status = BookingStatus.techAssigned;
        if (newStatus == 'ASSIGNED') {
          status = BookingStatus.techAssigned;
        } else if (newStatus == 'EN_ROUTE') {
          status = BookingStatus.techOnTheWay;
        } else if (newStatus == 'ARRIVED') {
          status = BookingStatus.techArrived;
        } else if (newStatus == 'IN_PROGRESS') {
          status = BookingStatus.serviceStarted;
        } else if (newStatus == 'COMPLETED') {
          status = BookingStatus.completed;
        }

        ref.read(bookingProvider.notifier).setBookingStatus(status);
      });
    } catch (e) {
      debugPrint('Socket Initialization Failed: $e');
    }
  }

  void _onPartnerLocationUpdate(LatLng newLocation) {
    final startLoc = _interpolatedLocation;
    final endLoc = newLocation;

    _latLngAnimation = LatLngTween(begin: startLoc, end: endLoc).animate(
      CurvedAnimation(parent: _interpolationController, curve: Curves.easeInOut),
    );
    _interpolationController.reset();
    _interpolationController.forward();

    _mapController.move(newLocation, 14.5);
  }

  void _resetSimulation() {
    _interpolationController.stop();
  }

  double _haversineDistance(double lat1, double lon1, double lat2, double lon2) {
    const r = 6371000.0;
    final dLat = _toRad(lat2 - lat1);
    final dLon = _toRad(lon2 - lon1);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRad(lat1)) * cos(_toRad(lat2)) * sin(dLon / 2) * sin(dLon / 2);
    return r * 2 * atan2(sqrt(a), sqrt(1 - a));
  }

  double _toRad(double deg) => deg * pi / 180;

  String _calculateEta() {
    final dist = _haversineDistance(
      _interpolatedLocation.latitude, _interpolatedLocation.longitude,
      _customerLoc.latitude, _customerLoc.longitude,
    );
    final seconds = dist / 10.0;
    if (seconds < 10) {
      return "Arrived";
    }
    final minutes = (seconds / 60).floor();
    final remainingSecs = (seconds % 60).floor();
    return "$minutes m $remainingSecs s";
  }

  void _simulateMaskedCall(String phone) {
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
                child: const Text(
                  "Calling +91 ••••• ••210",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: kTextNavy),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Disconnect Call", style: TextStyle(color: Colors.red)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }

  void _updateSocketStatus(String status) {
    setState(() {
      _socketStatus = status;
      if (status == 'CONNECTED') {
        _showSocketSuccessBanner = true;
      } else {
        _showSocketSuccessBanner = false;
      }
    });

    if (status == 'CONNECTED') {
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted && _socketStatus == 'CONNECTED') {
          setState(() {
            _showSocketSuccessBanner = false;
          });
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(bookingProvider);
    final booking = state.activeBooking;

    if (booking == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Booking Tracking')),
        body: const Center(child: Text('No active booking')),
      );
    }

    final remainingRoute = <LatLng>[
      if (booking.status == BookingStatus.techOnTheWay) ...[
        _interpolatedLocation,
        _customerLoc,
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
                initialCenter: _interpolatedLocation,
                initialZoom: 14.5,
                maxZoom: 18,
                minZoom: 10,
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.bookurtechnician.customer',
                ),
                
                // Polyline layers for OSM
                PolylineLayer(
                  polylines: [
                    if (booking.status == BookingStatus.techOnTheWay && remainingRoute.isNotEmpty)
                      Polyline(
                        points: remainingRoute,
                        color: kBrandPrimary,
                        strokeWidth: 4.0,
                      ),
                  ],
                ),

                // Markers layer for OSM
                MarkerLayer(
                  markers: [
                    if (booking.status == BookingStatus.techOnTheWay || booking.status == BookingStatus.techArrived || booking.status == BookingStatus.serviceStarted)
                      Marker(
                        point: _interpolatedLocation,
                        width: 40,
                        height: 40,
                        child: Icon(Icons.directions_car, color: Theme.of(context).primaryColor, size: 30),
                      ),
                    Marker(
                      point: _customerLoc,
                      width: 40,
                      height: 40,
                      child: const Icon(Icons.home, color: Colors.blue, size: 30),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // 2. Safe Area Headers & Socket Alerts
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
                              'Live Telemetry Tracking',
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
                              'Reconnecting to dispatch socket...',
                              style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      )
                    else if (_socketStatus == 'DISCONNECTED')
                      Container(
                        color: kRedError,
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.wifi_off, size: 14, color: Colors.white),
                            SizedBox(width: 8),
                            Text(
                              'Socket offline mode. Simulating updates locally.',
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
                              'Live Socket Connected. Streaming partner telemetry.',
                              style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),

                    // GPS Permission Banner
                    if (!_isGpsGranted)
                      Container(
                        color: kTextNavy,
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.gps_off, size: 14, color: Colors.white),
                            const SizedBox(width: 8),
                            const Expanded(
                              child: Text(
                                'GPS permission denied. Location mapping approximate.',
                                style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w500),
                              ),
                            ),
                            TextButton(
                              onPressed: () => setState(() => _isGpsGranted = true),
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: const Text('GRANT', style: TextStyle(color: kBrandSecondary, fontWeight: FontWeight.bold, fontSize: 12)),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),

          // 3. Collapsible Simulator Control Overlay
          Positioned(
            top: 140,
            right: 16,
            child: Container(
              width: 180,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.95),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 8, offset: const Offset(0, 4))
                ],
              ),
              child: ExpansionTile(
                dense: true,
                visualDensity: VisualDensity.compact,
                leading: const Icon(Icons.tune, color: kBrandPrimary, size: 18),
                title: const Text('Simulate UI', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: kTextNavy)),
                childrenPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('GPS Access:', style: TextStyle(fontSize: 10)),
                      Transform.scale(
                        scale: 0.7,
                        child: Switch(
                          value: _isGpsGranted,
                          onChanged: (val) => setState(() => _isGpsGranted = val),
                        ),
                      )
                    ],
                  ),
                  const Divider(height: 8),
                  const Text('Live Connection:', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildStateChip('CONNECTED', kGreenSuccess),
                      _buildStateChip('DISCONNECTED', kRedError),
                    ],
                  ),
                  const SizedBox(height: 4),
                  _buildStateChip('RECONNECTING', kYellowWarning),
                  const Divider(height: 12),
                  const Text('Status Timeline:', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  _buildStatusButton('En Route', BookingStatus.techOnTheWay),
                  _buildStatusButton('Arrived', BookingStatus.techArrived),
                  _buildStatusButton('In Progress', BookingStatus.serviceStarted),
                  _buildStatusButton('Completed', BookingStatus.completed),
                  const Divider(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: _resetSimulation,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        minimumSize: Size.zero,
                        side: const BorderSide(color: kBrandPrimary),
                      ),
                      child: const Text('Reset Movement', style: TextStyle(fontSize: 9, color: kBrandPrimary)),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 4. Floating Info Bottom Card
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
                                          : 'Service complete',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: kTextNavy),
                            ),
                            if (booking.status == BookingStatus.techOnTheWay) ...[
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  const Icon(Icons.timer_outlined, size: 14, color: kTextGray),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Dynamic ETA: ${_calculateEta()}',
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
                                Text('LIVE', style: TextStyle(color: kGreenSuccess, fontSize: 9, fontWeight: FontWeight.bold)),
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
                                booking.technicianName,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: kTextNavy),
                              ),
                              const Row(
                                children: [
                                  Icon(Icons.star, color: Colors.amber, size: 14),
                                  SizedBox(width: 2),
                                  Text(
                                    '4.9 (124 Jobs done)',
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
                            onPressed: () => _simulateMaskedCall(booking.technicianPhone),
                          ),
                        ),
                      ],
                    ),

                    // OTP Panel (depending on status)
                    if (booking.status == BookingStatus.techArrived && state.trackingOtpStatus == 'PENDING') ...[
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
                              'Job Initiation Start OTP',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: kBrandPrimary),
                            ),
                            const SizedBox(height: 2),
                            const Text(
                              'Share this 4-digit code with the technician to authorize starting the service:',
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
                                booking.otpCode,
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
                        child: Column(
                          children: [
                            const Text(
                              'Job Completion End OTP',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: kGreenSuccess),
                            ),
                            const SizedBox(height: 2),
                            const Text(
                              'Share this 4-digit code with the technician when they finish to confirm completion:',
                              style: TextStyle(fontSize: 11, color: kTextGray),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 10),
                            Container(
                              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 24),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: kGreenSuccess.withValues(alpha: 0.1)),
                              ),
                              child: const Text(
                                "8839", // Simulated End OTP
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 26,
                                  color: kGreenSuccess,
                                  letterSpacing: 8,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    // Manual Start Verification Form (For overrides/tests)
                    if (booking.status == BookingStatus.techArrived && state.trackingOtpStatus == 'PENDING') ...[
                      const SizedBox(height: 12),
                      TextField(
                        controller: _otpCtrl,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                        decoration: InputDecoration(
                          hintText: 'Enter OTP manually (Test override)',
                          errorText: _otpError,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () {
                            if (_otpCtrl.text == booking.otpCode) {
                              setState(() => _otpError = null);
                              ref.read(bookingProvider.notifier).verifyOtp(_otpCtrl.text);
                            } else {
                              setState(() => _otpError = 'Incorrect OTP. Try again.');
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                          ),
                          child: const Text('Verify & Start Service', style: TextStyle(fontSize: 13)),
                        ),
                      ),
                    ],

                    if (booking.status == BookingStatus.serviceStarted) ...[
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: kGreenSuccess,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                          ),
                          onPressed: () {
                            ref.read(bookingProvider.notifier).completeService();
                            Navigator.pushReplacementNamed(context, '/history');
                          },
                          child: const Text('Mark Complete (Test override)', style: TextStyle(fontSize: 13)),
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

  Widget _buildStateChip(String stateName, Color color) {
    final isSelected = _socketStatus == stateName;
    return GestureDetector(
      onTap: () => _updateSocketStatus(stateName),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.15) : Colors.grey.shade100,
          border: Border.all(color: isSelected ? color : Colors.transparent, width: 1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          stateName.substring(0, min(stateName.length, 7)),
          style: TextStyle(
            fontSize: 8,
            fontWeight: FontWeight.bold,
            color: isSelected ? color : Colors.grey.shade600,
          ),
        ),
      ),
    );
  }

  Widget _buildStatusButton(String label, BookingStatus status) {
    final isSelected = ref.read(bookingProvider).activeBooking?.status == status;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4.0),
      child: SizedBox(
        width: double.infinity,
        height: 22,
        child: ElevatedButton(
          onPressed: () {
            ref.read(bookingProvider.notifier).setBookingStatus(status);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: isSelected ? kBrandPrimary : Colors.grey.shade100,
            foregroundColor: isSelected ? Colors.white : Colors.black,
            elevation: 0,
            padding: EdgeInsets.zero,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          ),
          child: Text(label, style: const TextStyle(fontSize: 9)),
        ),
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
