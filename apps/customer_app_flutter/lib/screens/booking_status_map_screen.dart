import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/api_client.dart';

class BookingStatusMapScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic>? initialBookingData;

  const BookingStatusMapScreen({
    super.key,
    this.initialBookingData,
  });

  @override
  ConsumerState<BookingStatusMapScreen> createState() => _BookingStatusMapScreenState();
}

class _BookingStatusMapScreenState extends ConsumerState<BookingStatusMapScreen> {
  GoogleMapController? _mapController;
  Map<String, dynamic> _booking = {};
  bool _isResendingEmail = false;
  bool _isLoading = false;

  // Default coordinate center
  LatLng _userPos = const LatLng(12.9716, 77.5946);
  LatLng _techPos = const LatLng(12.9780, 77.6050);

  @override
  void initState() {
    super.initState();
    _initBookingData();
    _fetchLiveBooking();
  }

  void _initBookingData() {
    if (widget.initialBookingData != null) {
      _booking = Map<String, dynamic>.from(widget.initialBookingData!);
      _syncCoordinates();
    }
  }

  void _syncCoordinates() {
    final double? uLat = (_booking['customerLatitude'] ?? _booking['userLat']) != null
        ? ((_booking['customerLatitude'] ?? _booking['userLat']) as num).toDouble()
        : null;
    final double? uLng = (_booking['customerLongitude'] ?? _booking['userLng']) != null
        ? ((_booking['customerLongitude'] ?? _booking['userLng']) as num).toDouble()
        : null;
    final double? tLat = (_booking['technicianLatitude'] ?? _booking['techLat']) != null
        ? ((_booking['technicianLatitude'] ?? _booking['techLat']) as num).toDouble()
        : null;
    final double? tLng = (_booking['technicianLongitude'] ?? _booking['techLng']) != null
        ? ((_booking['technicianLongitude'] ?? _booking['techLng']) as num).toDouble()
        : null;

    if (uLat != null && uLng != null) {
      _userPos = LatLng(uLat, uLng);
    }
    if (tLat != null && tLng != null) {
      _techPos = LatLng(tLat, tLng);
    } else if (uLat != null && uLng != null) {
      _techPos = LatLng(uLat + 0.008, uLng + 0.008);
    }
  }

  Future<void> _fetchLiveBooking() async {
    final bookingId = _booking['id'] ?? _booking['bookingId'];
    if (bookingId == null || bookingId.toString().isEmpty) return;

    setState(() => _isLoading = true);
    try {
      final res = await ApiClient.get('/bookings/$bookingId');
      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        if (decoded['data'] != null && mounted) {
          setState(() {
            _booking = Map<String, dynamic>.from(decoded['data']);
            _syncCoordinates();
          });
          _fitBounds();
        }
      }
    } catch (e) {
      debugPrint('Error fetching live booking status: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  double _calculateDistanceKm(LatLng p1, LatLng p2) {
    const double r = 6371; // km
    final double dLat = (p2.latitude - p1.latitude) * (pi / 180.0);
    final double dLon = (p2.longitude - p1.longitude) * (pi / 180.0);
    final double a = sin(dLat / 2) * sin(dLat / 2) +
        cos(p1.latitude * (pi / 180.0)) * cos(p2.latitude * (pi / 180.0)) * sin(dLon / 2) * sin(dLon / 2);
    final double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return (r * c * 10).round() / 10.0;
  }

  void _fitBounds() {
    if (_mapController == null) return;

    final double southWestLat = min(_userPos.latitude, _techPos.latitude);
    final double southWestLng = min(_userPos.longitude, _techPos.longitude);
    final double northEastLat = max(_userPos.latitude, _techPos.latitude);
    final double northEastLng = max(_userPos.longitude, _techPos.longitude);

    final LatLngBounds bounds = LatLngBounds(
      southwest: LatLng(southWestLat, southWestLng),
      northeast: LatLng(northEastLat, northEastLng),
    );

    _mapController!.animateCamera(
      CameraUpdate.newLatLngBounds(bounds, 80),
    );
  }

  Future<void> _callTechnician(String phone) async {
    final cleanPhone = phone.replaceAll(RegExp(r'\s+'), '');
    final uri = Uri.parse('tel:$cleanPhone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Calling $phone')),
        );
      }
    }
  }

  Future<void> _resendCompletionEmail() async {
    final bookingId = _booking['id'];
    if (bookingId == null) return;

    setState(() => _isResendingEmail = true);
    try {
      final res = await ApiClient.post('/bookings/$bookingId/resend-end-email', {});
      setState(() => _isResendingEmail = false);

      if (mounted) {
        if (res.statusCode == 200) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              backgroundColor: Color(0xFF166534),
              content: Text('Completion OTP email has been resent to your inbox!'),
            ),
          );
        } else {
          final decoded = jsonDecode(res.body);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(decoded['message'] ?? 'Failed to resend email.')),
          );
        }
      }
    } catch (e) {
      setState(() => _isResendingEmail = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = (_booking['status'] ?? 'ACCEPTED').toString().toUpperCase();
    final isInProgress = status == 'IN_PROGRESS';
    final isCompleted = status == 'COMPLETED';
    final distanceKm = _calculateDistanceKm(_userPos, _techPos);

    // ─── 2 STATIC CUSTOM MARKERS ONLY (NO POLYLINES / NO DIRECTIONS API) ───
    final Set<Marker> markers = {
      Marker(
        markerId: const MarkerId('user_pin'),
        position: _userPos,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
        infoWindow: const InfoWindow(title: 'Your Location', snippet: 'Service Delivery Address'),
      ),
      Marker(
        markerId: const MarkerId('technician_pin'),
        position: _techPos,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        infoWindow: InfoWindow(
          title: _booking['technicianName'] ?? 'Technician Partner',
          snippet: '★ ${_booking['technicianRating'] ?? 4.8} ($distanceKm km away)',
        ),
      ),
    };

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          'Booking #${_booking['bookingCode'] ?? 'BT-900'}',
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17, color: Color(0xFF111827)),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF111827), size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (_isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF2146A8)),
                ),
              ),
            )
          else
            IconButton(
              tooltip: 'Refresh Booking',
              icon: const Icon(Icons.refresh_rounded, color: Color(0xFF2146A8)),
              onPressed: _fetchLiveBooking,
            ),
          IconButton(
            tooltip: 'Fit Map View',
            icon: const Icon(Icons.center_focus_strong_rounded, color: Color(0xFF2146A8)),
            onPressed: _fitBounds,
          ),
        ],
      ),
      body: Stack(
        children: [
          // ─── 1. LIGHTWEIGHT STATIC TWO-POINT GOOGLE MAP ───
          Positioned.fill(
            bottom: 310,
            child: GoogleMap(
              initialCameraPosition: CameraPosition(target: _userPos, zoom: 14),
              markers: markers,
              polylines: const {}, // STRICTLY EMPTY - NO POLYLINES OR TURN-BY-TURN ROUTING OVERHEAD
              myLocationEnabled: true,
              myLocationButtonEnabled: false,
              zoomControlsEnabled: false,
              mapToolbarEnabled: false,
              onMapCreated: (controller) {
                _mapController = controller;
                Future.delayed(const Duration(milliseconds: 300), _fitBounds);
              },
            ),
          ),

          // ─── 2. 15KM DISCOVERY & DISTANCE BADGE OVERLAY ───
          Positioned(
            top: 14,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: const [
                  BoxShadow(color: Color(0x26000000), blurRadius: 10, offset: Offset(0, 3)),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.radar_rounded, color: Color(0xFF2146A8), size: 20),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _booking['serviceName']?.toString().isNotEmpty == true
                              ? _booking['serviceName']
                              : 'Home Service',
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: Color(0xFF0F172A)),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          '15 km Discovery • 1-Hour Service Slot',
                          style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFECFDF5),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFF86EFAC)),
                    ),
                    child: Text(
                      '$distanceKm km away',
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 11.5, color: Color(0xFF065F46)),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ─── 3. BOTTOM DETAILS & DUAL-OTP LIFECYCLE CARD ───
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                boxShadow: [
                  BoxShadow(color: Color(0x33000000), blurRadius: 20, offset: Offset(0, -4)),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Drag Handle
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFFCBD5E1),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Technician Info Row
                  Row(
                    children: [
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFFEFF6FF),
                          border: Border.all(color: const Color(0xFF2146A8), width: 1.5),
                        ),
                        child: const Center(
                          child: Icon(Icons.engineering_rounded, color: Color(0xFF2146A8), size: 28),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _booking['technicianName']?.toString().isNotEmpty == true
                                  ? _booking['technicianName']
                                  : 'Assigning nearest partner...',
                              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Color(0xFF0F172A)),
                            ),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                const Icon(Icons.star_rounded, size: 16, color: Color(0xFFF59E0B)),
                                const SizedBox(width: 3),
                                Text(
                                  (_booking['technicianRating'] is num && (_booking['technicianRating'] as num) > 0)
                                      ? (_booking['technicianRating'] as num).toStringAsFixed(1)
                                      : '5.0',
                                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  '• ${_booking['technicianCategory'] ?? _booking['serviceName'] ?? 'Service Partner'}',
                                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      if (_booking['technicianPhone'] != null && _booking['technicianPhone'].toString().isNotEmpty)
                        IconButton.filled(
                          style: IconButton.styleFrom(
                            backgroundColor: const Color(0xFF16A34A),
                            foregroundColor: Colors.white,
                          ),
                          icon: const Icon(Icons.phone_rounded, size: 20),
                          onPressed: () => _callTechnician(_booking['technicianPhone']),
                        ),
                    ],
                  ),

                  const SizedBox(height: 16),
                  const Divider(color: Color(0xFFF1F5F9), height: 1),
                  const SizedBox(height: 14),

                  // ─── DUAL-OTP LIFECYCLE BANNER ───
                  if (!isInProgress && !isCompleted) ...[
                    // STAGE 1: 3-HOUR START SERVICE OTP
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEEF2FF),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFC7D2FE), width: 1.2),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF2146A8),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.key_rounded, color: Colors.white, size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'SHARE WITH PARTNER UPON ARRIVAL',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF3730A3),
                                    letterSpacing: 0.4,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Start Service OTP: ${_booking['startServiceOtp'] ?? '••••'}',
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w900,
                                    color: Color(0xFF1E1B4B),
                                    letterSpacing: 1,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                const Text(
                                  'Valid for 3 Hours from booking',
                                  style: TextStyle(fontSize: 11, color: Color(0xFF4F46E5), fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ] else if (isInProgress) ...[
                    // STAGE 2: 24-HOUR EMAIL COMPLETION OTP BANNER
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFECFDF5),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFF86EFAC), width: 1.2),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF16A34A),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(Icons.mark_email_read_rounded, color: Colors.white, size: 20),
                              ),
                              const SizedBox(width: 12),
                              const Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'SERVICE IN PROGRESS',
                                      style: TextStyle(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w800,
                                        color: Color(0xFF166534),
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                    SizedBox(height: 2),
                                    Text(
                                      'Completion OTP sent to your registered email',
                                      style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF064E3B)),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                '• Valid for 24 Hours • Check inbox/spam',
                                style: TextStyle(fontSize: 11, color: Color(0xFF047857), fontWeight: FontWeight.w600),
                              ),
                              TextButton(
                                onPressed: _isResendingEmail ? null : _resendCompletionEmail,
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  minimumSize: Size.zero,
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                                child: _isResendingEmail
                                    ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                                    : const Text(
                                        'Resend Email',
                                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF16A34A)),
                                      ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ] else ...[
                    // STAGE 3: COMPLETED
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0FDF4),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFBBF7D0)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.check_circle_rounded, color: Color(0xFF16A34A), size: 24),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Service Completed & Inspected! Thank you.',
                              style: TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF166534), fontSize: 13.5),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
