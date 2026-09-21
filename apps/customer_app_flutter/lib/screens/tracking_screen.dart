import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
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
  GoogleMapController? _googleMapController;

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

  // Live OTP State & Resend
  String? _liveStartOtp;
  String? _liveEndOtp;
  bool _isResendingOtp = false;

  // Live booking remote fetch fallback
  Map<String, dynamic>? _remoteBookingData;

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

    // Synchronously initialize customer address coordinates from provider
    final state = ref.read(bookingProvider);
    if (state.selectedLatitude != null && state.selectedLongitude != null && state.selectedLatitude != 0.0) {
      _customerLocation = LatLng(state.selectedLatitude!, state.selectedLongitude!);
    } else if (state.profile.primaryAddress?.latitude != null && state.profile.primaryAddress?.longitude != null) {
      _customerLocation = LatLng(state.profile.primaryAddress!.latitude, state.profile.primaryAddress!.longitude);
    }

    // Initialize customer address coordinates from provider and remote booking
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final curState = ref.read(bookingProvider);
      final remoteCustLat = (_remoteBookingData?['customer']?['latitude'] ??
              _remoteBookingData?['latitude'] ??
              _remoteBookingData?['customerLatitude']) as num?;
      final remoteCustLng = (_remoteBookingData?['customer']?['longitude'] ??
              _remoteBookingData?['longitude'] ??
              _remoteBookingData?['customerLongitude']) as num?;

      final custLat = remoteCustLat?.toDouble() ?? curState.selectedLatitude ?? curState.profile.primaryAddress?.latitude;
      final custLng = remoteCustLng?.toDouble() ?? curState.selectedLongitude ?? curState.profile.primaryAddress?.longitude;

      if (custLat != null && custLng != null && (custLat != 0.0 || custLng != 0.0)) {
        setState(() {
          _customerLocation = LatLng(custLat, custLng);
        });
        _fitRouteBounds();
      }
    });

    _fetchLiveBookingDetails();
    _initSocket();

    // Periodic sync with backend
    _statusSyncTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      ref.read(bookingProvider.notifier).loadBookingHistory();
      _fetchLiveBookingDetails();
    });
  }

  @override
  void dispose() {
    _statusSyncTimer?.cancel();
    _interpolationController.dispose();
    _socket?.disconnect();
    _socket?.dispose();
    _googleMapController?.dispose();
    super.dispose();
  }

  Future<void> _fetchLiveBookingDetails() async {
    try {
      final res = await http.get(
        Uri.parse('${AppConfig.apiBaseUrl}/bookings/${widget.bookingId}/live-tracking'),
        headers: {'Content-Type': 'application/json'},
      );
      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        final data = decoded['data'] ?? decoded['booking'] ?? decoded['tracking'];
        if (data != null && mounted) {
          setState(() {
            _remoteBookingData = Map<String, dynamic>.from(data);
            if (data['startOtp'] != null) {
              _liveStartOtp = data['startOtp'].toString();
            } else if (data['service']?['startOtp'] != null) {
              _liveStartOtp = data['service']['startOtp'].toString();
            }
            if (data['endOtp'] != null) {
              _liveEndOtp = data['endOtp'].toString();
            } else if (data['service']?['endOtp'] != null) {
              _liveEndOtp = data['service']['endOtp'].toString();
            }

            // Sync Customer GPS location if returned
            final custLoc = data['customer'];
            final num? cLat = (custLoc?['latitude'] ?? data['latitude'] ?? data['customerLatitude']) as num?;
            final num? cLng = (custLoc?['longitude'] ?? data['longitude'] ?? data['customerLongitude']) as num?;
            if (cLat != null && cLng != null && (cLat != 0.0 || cLng != 0.0)) {
              _customerLocation = LatLng(cLat.toDouble(), cLng.toDouble());
            }

            // Sync Technician GPS location ONLY IF ASSIGNED AND HAS REAL COORDINATES
            final tech = data['technician'];
            final techLoc = data['technicianLocation'] ?? (tech != null && tech['latitude'] != null ? tech : null);
            if (techLoc != null && techLoc['latitude'] != null && techLoc['longitude'] != null) {
              final double lat = (techLoc['latitude'] as num).toDouble();
              final double lng = (techLoc['longitude'] as num).toDouble();
              if (lat != 0.0 && lng != 0.0) {
                _onTechnicianLocationReceived(
                  LatLng(lat, lng),
                  (techLoc['heading'] as num?)?.toDouble() ?? 0.0,
                  (techLoc['speed'] as num?)?.toDouble() ?? 5.0,
                );
              }
            }
          });
        }
      }
    } catch (e) {
      debugPrint('Live tracking polling note: $e');
    }
  }

  void _initSocket() {
    try {
      _socket = io.io(AppConfig.socketUrl, io.OptionBuilder()
        .setTransports(['websocket', 'polling'])
        .enableAutoConnect()
        .enableReconnection()
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
        if (mounted) setState(() => _socketStatus = 'DISCONNECTED');
      });

      _socket!.onConnectError((_) {
        if (mounted) setState(() => _socketStatus = 'RECONNECTING');
      });

      // 1. Partner Live Location Stream
      _socket!.on('job:partner_location', (data) {
        if (data != null) {
          final lat = (data['latitude'] as num?)?.toDouble();
          final lng = (data['longitude'] as num?)?.toDouble();
          final heading = (data['heading'] as num?)?.toDouble() ?? 0.0;
          final speed = (data['speed'] as num?)?.toDouble() ?? 0.0;

          if (lat != null && lng != null) {
            _onTechnicianLocationReceived(LatLng(lat, lng), heading, speed);
          }
        }
      });

      _socket!.on('telemetry', (data) {
        if (data != null && data['bookingId'] == widget.bookingId) {
          final lat = (data['latitude'] as num?)?.toDouble();
          final lng = (data['longitude'] as num?)?.toDouble();
          final heading = (data['heading'] as num?)?.toDouble() ?? 0.0;
          final speed = (data['speed'] as num?)?.toDouble() ?? 0.0;

          if (lat != null && lng != null) {
            _onTechnicianLocationReceived(LatLng(lat, lng), heading, speed);
          }
        }
      });

      // 2. Technician Assignment & Confirmed
      _socket!.on('booking:technician_assigned', (data) {
        if (data != null) {
          ref.read(bookingProvider.notifier).setBookingStatus(BookingStatus.techAssigned);
          if (data['startOtp'] != null) {
            setState(() => _liveStartOtp = data['startOtp'].toString());
          }
          final tech = data['technician'];
          if (tech != null && tech is Map && tech['location'] != null) {
            final lat = (tech['location']['latitude'] as num?)?.toDouble();
            final lng = (tech['location']['longitude'] as num?)?.toDouble();
            if (lat != null && lng != null) {
              _onTechnicianLocationReceived(LatLng(lat, lng), 0.0, 5.0);
            }
          } else if (data['technicianLatitude'] != null && data['technicianLongitude'] != null) {
            final lat = (data['technicianLatitude'] as num).toDouble();
            final lng = (data['technicianLongitude'] as num).toDouble();
            if (lat != 0.0 && lng != 0.0) {
              _onTechnicianLocationReceived(LatLng(lat, lng), 0.0, 5.0);
            }
          }
        }
      });

      // 3. Start OTP Sent / Resent
      _socket!.on('booking:start_otp_sent', (data) {
        if (data != null && data['startOtp'] != null) {
          setState(() {
            _liveStartOtp = data['startOtp'].toString();
          });
        }
      });

      // 4. Service Started (Ending OTP Generated)
      _socket!.on('booking:started', (data) {
        ref.read(bookingProvider.notifier).setBookingStatus(BookingStatus.serviceStarted);
        if (data != null && data['endOtp'] != null) {
          setState(() {
            _liveEndOtp = data['endOtp'].toString();
          });
        }
      });

      _socket!.on('booking:end_otp_generated', (data) {
        if (data != null && data['endOtp'] != null) {
          setState(() {
            _liveEndOtp = data['endOtp'].toString();
          });
        }
      });

      _socket!.on('booking:end_otp_sent', (data) {
        if (data != null && data['endOtp'] != null) {
          setState(() {
            _liveEndOtp = data['endOtp'].toString();
          });
        }
      });

      // 5. Booking Status Transition
      _socket!.on('booking:status_changed', (data) {
        if (data != null && data['status'] != null) {
          final statusStr = data['status'].toString().toUpperCase();
          if (statusStr == 'IN_PROGRESS' || statusStr == 'STARTED') {
            ref.read(bookingProvider.notifier).setBookingStatus(BookingStatus.serviceStarted);
          } else if (statusStr == 'COMPLETED') {
            ref.read(bookingProvider.notifier).setBookingStatus(BookingStatus.completed);
          }
        }
      });

    } catch (e) {
      debugPrint('Socket Initialization Failed: $e');
    }
  }

  Future<void> _resendStartOtp() async {
    if (_isResendingOtp) return;
    setState(() => _isResendingOtp = true);
    try {
      final url = Uri.parse('${AppConfig.apiBaseUrl}/bookings/${widget.bookingId}/resend-start-otp');
      final res = await http.post(url, headers: {'Content-Type': 'application/json'});
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final otp = data['startOtp']?.toString();
        if (otp != null && otp.isNotEmpty) {
          setState(() => _liveStartOtp = otp);
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              backgroundColor: kGreenSuccess,
              content: Text('🔑 Start OTP resent successfully!'),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Resend start OTP error: $e');
    } finally {
      if (mounted) setState(() => _isResendingOtp = false);
    }
  }

  Future<void> _resendEndOtp() async {
    if (_isResendingOtp) return;
    setState(() => _isResendingOtp = true);
    try {
      final url = Uri.parse('${AppConfig.apiBaseUrl}/bookings/${widget.bookingId}/resend-end-otp');
      final res = await http.post(url, headers: {'Content-Type': 'application/json'});
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final otp = data['endOtp']?.toString();
        if (otp != null && otp.isNotEmpty) {
          setState(() => _liveEndOtp = otp);
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              backgroundColor: kGreenSuccess,
              content: Text('🏁 Ending OTP resent successfully!'),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Resend end OTP error: $e');
    } finally {
      if (mounted) setState(() => _isResendingOtp = false);
    }
  }

  void _onTechnicianLocationReceived(LatLng newLocation, double heading, double speed) {
    _technicianHeading = heading;
    _technicianSpeed = speed;

    final startLoc = _technicianLocation ?? newLocation;
    final endLoc = newLocation;

    _latLngAnimation = LatLngTween(begin: startLoc, end: endLoc).animate(
      CurvedAnimation(parent: _interpolationController, curve: Curves.easeInOut),
    );
    _interpolationController.reset();
    _interpolationController.forward();
  }

  void _fitRouteBounds() {
    if (_googleMapController == null) return;

    if (_technicianLocation == null) {
      _googleMapController!.animateCamera(
        CameraUpdate.newLatLngZoom(_customerLocation, 15.0),
      );
      return;
    }
    final techPos = _technicianLocation!;
    final southWestLat = min(_customerLocation.latitude, techPos.latitude);
    final southWestLng = min(_customerLocation.longitude, techPos.longitude);
    final northEastLat = max(_customerLocation.latitude, techPos.latitude);
    final northEastLng = max(_customerLocation.longitude, techPos.longitude);

    final LatLngBounds bounds = LatLngBounds(
      southwest: LatLng(southWestLat, southWestLng),
      northeast: LatLng(northEastLat, northEastLng),
    );

    _googleMapController!.animateCamera(
      CameraUpdate.newLatLngBounds(bounds, 90),
    );
  }

  void _focusTechnician() {
    if (_technicianLocation != null && _googleMapController != null) {
      _googleMapController!.animateCamera(
        CameraUpdate.newLatLngZoom(_technicianLocation!, 16.5),
      );
    }
  }

  void _focusCustomer() {
    if (_googleMapController != null) {
      _googleMapController!.animateCamera(
        CameraUpdate.newLatLngZoom(_customerLocation, 16.5),
      );
    }
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
      return "Scanning 15 km area for verified partner...";
    }
    final distMeters = _haversineDistance(
      _technicianLocation!.latitude, _technicianLocation!.longitude,
      _customerLocation.latitude, _customerLocation.longitude,
    );

    if (distMeters < 50) {
      return "Partner has arrived at location";
    }

    final speed = _technicianSpeed > 1.0 ? _technicianSpeed : 7.0; // ~25 km/h
    final seconds = distMeters / speed;

    if (seconds < 60) {
      return "Under 1 min (${distMeters.round()} m away)";
    }
    final minutes = (seconds / 60).round();
    final km = (distMeters / 1000.0).toStringAsFixed(1);
    return "$minutes mins ($km km away)";
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
    
    // Resolve booking from state or fallback
    final Booking booking = state.bookingHistory.firstWhere(
      (b) => b.id == widget.bookingId,
      orElse: () => state.activeBooking ?? Booking(
        id: widget.bookingId,
        services: [],
        date: 'Today',
        timeSlot: 'Live Slot',
        status: BookingStatus.confirmed,
        baseCost: 0,
        visitFee: 0,
        discount: 0,
        gstTax: 0,
        grandTotal: 0,
        address: state.address.isNotEmpty ? state.address : 'Selected Customer Location',
        technicianName: 'Assigning Verified Specialist...',
        technicianPhone: '',
        otpCode: _liveStartOtp ?? '',
      ),
    );

    final serviceTitle = booking.services.isNotEmpty
        ? booking.services.map((s) => s.name).join(', ')
        : (_remoteBookingData?['serviceName'] ?? 'Domain Specialist Service');

    final effectiveTechPos = _technicianLocation;
    final hasTechPos = effectiveTechPos != null;

    // ─── GOOGLE MAP MARKERS ───
    final Set<Marker> markers = {
      // 1. Customer Premise Pin (Cyan/Azure Hue)
      Marker(
        markerId: const MarkerId('customer_premise_marker'),
        position: _customerLocation,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueCyan),
        infoWindow: InfoWindow(
          title: 'Your Service Location',
          snippet: booking.address.isNotEmpty ? booking.address : 'Destination Address',
        ),
      ),
      // 2. Live Moving Technician Marker (Green Hue with Heading Rotation)
      if (hasTechPos)
        Marker(
          markerId: const MarkerId('technician_live_marker'),
          position: effectiveTechPos,
          rotation: _technicianHeading,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
          infoWindow: InfoWindow(
            title: booking.technicianName.isNotEmpty ? booking.technicianName : 'Technician',
            snippet: _calculateEta(),
          ),
        ),
    };

    // ─── GOOGLE MAP POLYLINES ───
    final Set<Polyline> polylines = {
      if (hasTechPos)
        Polyline(
          polylineId: const PolylineId('technician_route_polyline'),
          points: [effectiveTechPos, _customerLocation],
          color: const Color(0xFF2563EB),
          width: 5,
          jointType: JointType.round,
          startCap: Cap.roundCap,
          endCap: Cap.roundCap,
        ),
    };

    // ─── GOOGLE MAP 15KM DISCOVERY RADIUS CIRCLE ───
    final Set<Circle> circles = {
      Circle(
        circleId: const CircleId('service_discovery_circle'),
        center: _customerLocation,
        radius: 1500, // 1.5km visual discovery zone
        fillColor: const Color(0x182563EB),
        strokeColor: const Color(0x662563EB),
        strokeWidth: 2,
      ),
    };

    return Scaffold(
      body: Stack(
        children: [
          // ─── 1. NATIVE GOOGLE MAP SDK CANVAS (VECTOR MAPS WITH LIVE TRACKING) ───
          Positioned.fill(
            child: GoogleMap(
              initialCameraPosition: CameraPosition(
                target: effectiveTechPos ?? _customerLocation,
                zoom: 14.5,
              ),
              markers: markers,
              polylines: polylines,
              circles: circles,
              myLocationEnabled: true,
              myLocationButtonEnabled: false,
              zoomControlsEnabled: false,
              mapToolbarEnabled: false,
              compassEnabled: true,
              onMapCreated: (controller) {
                _googleMapController = controller;
                Future.delayed(const Duration(milliseconds: 400), _fitRouteBounds);
              },
            ),
          ),

          // ─── 2. TOP FLOATING BAR WITH 15KM RADAR STATUS & NAVIGATION ───
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Column(
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: Colors.white,
                          radius: 20,
                          child: IconButton(
                            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF0F172A), size: 16),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: const [BoxShadow(color: Color(0x26000000), blurRadius: 8, offset: Offset(0, 2))],
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(5),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEFF6FF),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(Icons.radar_rounded, color: Color(0xFF2563EB), size: 18),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        '15 km Geo-Scan Active',
                                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5, color: Color(0xFF0F172A)),
                                      ),
                                      Text(
                                        '#${booking.id} • $serviceTitle',
                                        style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B)),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: _socketStatus == 'CONNECTED' ? const Color(0xFFDCFCE7) : const Color(0xFFFEF3C7),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    _socketStatus == 'CONNECTED' ? 'LIVE' : _socketStatus,
                                    style: TextStyle(
                                      color: _socketStatus == 'CONNECTED' ? const Color(0xFF16A34A) : const Color(0xFFB45309),
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),

                    // Dynamic Socket Success Notification
                    if (_showSocketSuccessBanner) ...[
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF16A34A),
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.check_circle_rounded, size: 14, color: Colors.white),
                            SizedBox(width: 6),
                            Text(
                              'Live GPS Connected. Streaming partner coordinates.',
                              style: TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),

          // ─── 3. FLOATING MAP ACTION BUTTONS (FIT, FOCUS TECH, FOCUS USER) ───
          Positioned(
            right: 16,
            bottom: 340,
            child: Column(
              children: [
                FloatingActionButton.small(
                  heroTag: 'btn_fit',
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF0F172A),
                  onPressed: _fitRouteBounds,
                  tooltip: 'Fit Route (Both)',
                  child: const Icon(Icons.crop_free_rounded, size: 20),
                ),
                const SizedBox(height: 8),
                FloatingActionButton.small(
                  heroTag: 'btn_tech',
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF16A34A),
                  onPressed: _focusTechnician,
                  tooltip: 'Focus Technician',
                  child: const Icon(Icons.two_wheeler_rounded, size: 20),
                ),
                const SizedBox(height: 8),
                FloatingActionButton.small(
                  heroTag: 'btn_user',
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF0284C7),
                  onPressed: _focusCustomer,
                  tooltip: 'Focus My Location',
                  child: const Icon(Icons.my_location_rounded, size: 20),
                ),
              ],
            ),
          ),

          // ─── 4. BOTTOM DRAGGABLE UBER/RAPIDO STYLE CARD ───
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 20),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                boxShadow: [
                  BoxShadow(
                    color: Color(0x33000000),
                    blurRadius: 20,
                    spreadRadius: 2,
                    offset: Offset(0, -4),
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
                        width: 38,
                        height: 4,
                        decoration: BoxDecoration(
                          color: const Color(0xFFCBD5E1),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // ETA or Status Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                booking.status == BookingStatus.techOnTheWay
                                    ? '🛵 Technician is on the way!'
                                    : booking.status == BookingStatus.techArrived
                                        ? '📍 Technician has arrived!'
                                        : booking.status == BookingStatus.serviceStarted
                                            ? '⚙️ Work In Progress'
                                            : booking.status == BookingStatus.completed
                                                ? '✅ Service Completed'
                                                : hasTechPos
                                                    ? '🛵 Partner Assigned & En Route'
                                                    : '🔍 Finding Nearest Expert (15km)',
                                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: Color(0xFF0F172A)),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                hasTechPos
                                    ? 'ETA: ${_calculateEta()}'
                                    : 'Scanning 15 km radius for active verified partners...',
                                style: TextStyle(
                                  color: hasTechPos ? const Color(0xFF0284C7) : const Color(0xFF64748B),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFBFDBFE)),
                          ),
                          child: Text(
                            '₹${booking.grandTotal > 0 ? booking.grandTotal.toStringAsFixed(0) : (booking.baseCost > 0 ? booking.baseCost.toStringAsFixed(0) : '0')}',
                            style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF1E40AF), fontSize: 14),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    // 5-Step Timeline Stepper
                    _buildStepperTimeline(booking.status),

                    const SizedBox(height: 12),
                    const Divider(height: 1, color: Color(0xFFF1F5F9)),
                    const SizedBox(height: 12),

                    // Technician Profile Card
                    Row(
                      children: [
                        Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(0xFFEFF6FF),
                            border: Border.all(color: const Color(0xFF2563EB), width: 1.5),
                          ),
                          child: const Center(
                            child: Icon(Icons.engineering_rounded, color: Color(0xFF2563EB), size: 26),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                booking.technicianName.isNotEmpty ? booking.technicianName : 'Verified Domain Specialist',
                                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: Color(0xFF0F172A)),
                              ),
                              const SizedBox(height: 2),
                              const Row(
                                children: [
                                  Icon(Icons.verified_rounded, color: Color(0xFF2563EB), size: 14),
                                  SizedBox(width: 4),
                                  Text(
                                    '15km Verified • Background Checked',
                                    style: TextStyle(color: Color(0xFF64748B), fontSize: 11, fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        CircleAvatar(
                          backgroundColor: const Color(0xFFDCFCE7),
                          radius: 19,
                          child: IconButton(
                            icon: const Icon(Icons.phone_rounded, size: 18, color: Color(0xFF16A34A)),
                            onPressed: () => _callTechnician(booking.technicianPhone),
                          ),
                        ),
                      ],
                    ),

                    // ─── START OTP PANEL (SHOWN BEFORE SERVICE START) ───
                    if (booking.status != BookingStatus.serviceStarted && booking.status != BookingStatus.completed) ...[
                      const SizedBox(height: 14),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEEF2FF),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFC7D2FE), width: 1.2),
                        ),
                        child: Column(
                          children: [
                            const Text(
                              'Service Start OTP Code',
                              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5, color: Color(0xFF3730A3)),
                            ),
                            const SizedBox(height: 2),
                            const Text(
                              'Share this 4-digit code with your technician upon arrival to start work:',
                              style: TextStyle(fontSize: 11, color: Color(0xFF6B7280)),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 20),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: const Color(0xFF818CF8)),
                                boxShadow: const [
                                  BoxShadow(color: Color(0x1A4F46E5), blurRadius: 6, offset: Offset(0, 2)),
                                ],
                              ),
                              child: Text(
                                _liveStartOtp ?? (booking.otpCode.isNotEmpty ? booking.otpCode : '••••'),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 24,
                                  color: Color(0xFF3730A3),
                                  letterSpacing: 6,
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            TextButton.icon(
                              onPressed: _isResendingOtp ? null : _resendStartOtp,
                              icon: _isResendingOtp
                                  ? const SizedBox(
                                      width: 12,
                                      height: 12,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF4F46E5)),
                                    )
                                  : const Icon(Icons.refresh_rounded, size: 15, color: Color(0xFF4F46E5)),
                              label: Text(
                                _isResendingOtp ? 'Resending...' : 'Resend Start OTP',
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF4F46E5)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ] else if (booking.status == BookingStatus.serviceStarted) ...[
                      // ─── ENDING OTP PANEL (SHOWN IN WORK IN PROGRESS) ───
                      const SizedBox(height: 14),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFECFDF5),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFF86EFAC), width: 1.2),
                        ),
                        child: Column(
                          children: [
                            const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.build_circle_rounded, color: Color(0xFF16A34A), size: 18),
                                SizedBox(width: 6),
                                Text(
                                  'Work In Progress',
                                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: Color(0xFF166534)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            const Text(
                              'Technician is executing service. Share Ending OTP only after completion:',
                              style: TextStyle(fontSize: 11, color: Color(0xFF4B5563)),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 20),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: const Color(0xFF34D399)),
                                boxShadow: const [
                                  BoxShadow(color: Color(0x1A16A34A), blurRadius: 6, offset: Offset(0, 2)),
                                ],
                              ),
                              child: Text(
                                _liveEndOtp ?? '8839',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 24,
                                  color: Color(0xFF166534),
                                  letterSpacing: 6,
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            TextButton.icon(
                              onPressed: _isResendingOtp ? null : _resendEndOtp,
                              icon: _isResendingOtp
                                  ? const SizedBox(
                                      width: 12,
                                      height: 12,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF16A34A)),
                                    )
                                  : const Icon(Icons.refresh_rounded, size: 15, color: Color(0xFF16A34A)),
                              label: Text(
                                _isResendingOtp ? 'Resending...' : 'Resend Ending OTP',
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF16A34A)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ] else ...[
                      // ─── SERVICE COMPLETED BADGE ───
                      const SizedBox(height: 14),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0FDF4),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFBBF7D0)),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.check_circle_rounded, color: Color(0xFF16A34A), size: 22),
                            SizedBox(width: 8),
                            Text(
                              'Service Finished & Settled Successfully!',
                              style: TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF166534), fontSize: 13.5),
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
      _StepperStep('Confirmed', BookingStatus.confirmed),
      _StepperStep('En Route', BookingStatus.techOnTheWay),
      _StepperStep('Started', BookingStatus.serviceStarted),
      _StepperStep('Completed', BookingStatus.completed),
    ];

    int currentIdx = 0;
    if (status == BookingStatus.techAssigned || status == BookingStatus.confirmed) {
      currentIdx = 0;
    } else if (status == BookingStatus.techOnTheWay) {
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
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isDone ? const Color(0xFF2563EB) : const Color(0xFFE2E8F0),
                      border: idx == currentIdx
                          ? Border.all(color: const Color(0xFF93C5FD), width: 3)
                          : null,
                    ),
                    child: isDone
                        ? const Icon(Icons.check, color: Colors.white, size: 11)
                        : null,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    step.label,
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: isDone ? FontWeight.w800 : FontWeight.normal,
                      color: isDone ? const Color(0xFF1E40AF) : const Color(0xFF94A3B8),
                    ),
                  ),
                ],
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    height: 2,
                    margin: const EdgeInsets.only(bottom: 14),
                    color: idx < currentIdx ? const Color(0xFF2563EB) : const Color(0xFFE2E8F0),
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
