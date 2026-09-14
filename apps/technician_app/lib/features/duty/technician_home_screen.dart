import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../core/theme/app_theme.dart';
import '../../core/services/socket_service.dart';
import '../dispatch/presentation/incoming_job_alert_dialog.dart';
import '../wallet/wallet_screen.dart';

class TechnicianHomeScreen extends StatefulWidget {
  final String userId;
  final String technicianProfileId;
  final String electricianName;

  const TechnicianHomeScreen({
    super.key,
    required this.userId,
    required this.technicianProfileId,
    required this.electricianName,
  });

  @override
  State<TechnicianHomeScreen> createState() => _TechnicianHomeScreenState();
}

class _TechnicianHomeScreenState extends State<TechnicianHomeScreen> {
  bool _isOnline = false;
  final double _todayEarnings = 1850.0;
  final int _completedJobs = 4;
  final double _rating = 4.9;
  Timer? _gpsStreamTimer;
  GoogleMapController? _radarMapController;
  LatLng _currentLocation = const LatLng(12.971598, 77.594566);
  double _currentSpeedKmh = 0.0;

  @override
  void initState() {
    super.initState();
    _setupIncomingJobListener();
    _fetchCurrentLocation();
  }

  void _setupIncomingJobListener() {
    TechnicianSocketService().connect(
      technicianId: widget.technicianProfileId,
    );
  }

  Future<void> _fetchCurrentLocation() async {
    try {
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 5),
      );
      if (mounted) {
        setState(() {
          _currentLocation = LatLng(pos.latitude, pos.longitude);
          _currentSpeedKmh = (pos.speed * 3.6).clamp(0, 140);
        });
        _radarMapController?.animateCamera(
          CameraUpdate.newLatLng(_currentLocation),
        );
      }
    } catch (_) {}
  }

  void _toggleDuty() {
    final newStatus = !_isOnline;
    setState(() => _isOnline = newStatus);

    if (newStatus) {
      _fetchCurrentLocation();
      // Start streaming GPS coordinates
      _gpsStreamTimer = Timer.periodic(const Duration(seconds: 5), (_) {
        _fetchCurrentLocation();
      });
    } else {
      _gpsStreamTimer?.cancel();
    }
  }

  @override
  void dispose() {
    _gpsStreamTimer?.cancel();
    _radarMapController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TechColors.obsidianBlack,
      body: SafeArea(
        child: Column(
          children: [
            // Top Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Welcome, ${widget.electricianName}',
                        style: const TextStyle(
                          color: TechColors.pureWhite,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _isOnline
                                  ? TechColors.onlineGreen
                                  : TechColors.offlineGray,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _isOnline ? 'Online (Streaming GPS Radar)' : 'Offline',
                            style: TextStyle(
                              color: _isOnline
                                  ? TechColors.onlineGreen
                                  : TechColors.textMuted,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  IconButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => WalletScreen(userId: widget.userId),
                        ),
                      );
                    },
                    icon: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: TechColors.cardSurface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: TechColors.electricGold),
                      ),
                      child: const Icon(
                        Icons.account_balance_wallet_rounded,
                        color: TechColors.electricGold,
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Performance Cards Row
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Expanded(
                    child: _statCard(
                      'TODAY EARNINGS',
                      '₹${_todayEarnings.toInt()}',
                      Icons.currency_rupee_rounded,
                      TechColors.electricGold,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _statCard(
                      'JOBS DONE',
                      '$_completedJobs',
                      Icons.task_alt_rounded,
                      TechColors.electricCyan,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _statCard(
                      'RATING',
                      '$_rating ★',
                      Icons.star_rounded,
                      TechColors.warningAmber,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // ─── GOOGLE MAP RADAR (SHOWN WHEN ONLINE) ───
            if (_isOnline)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  height: 180,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: TechColors.electricCyan.withValues(alpha: 0.4), width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: TechColors.electricCyan.withValues(alpha: 0.15),
                        blurRadius: 15,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Stack(
                    children: [
                      GoogleMap(
                        initialCameraPosition: CameraPosition(
                          target: _currentLocation,
                          zoom: 14.5,
                        ),
                        markers: {
                          Marker(
                            markerId: const MarkerId('my_tech_radar_pos'),
                            position: _currentLocation,
                            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueCyan),
                            infoWindow: InfoWindow(
                              title: widget.electricianName,
                              snippet: 'Speed: ${_currentSpeedKmh.toStringAsFixed(1)} km/h',
                            ),
                          ),
                        },
                        circles: {
                          Circle(
                            circleId: const CircleId('radar_coverage_circle'),
                            center: _currentLocation,
                            radius: 1500,
                            fillColor: const Color(0x2200E5FF),
                            strokeColor: const Color(0x8800E5FF),
                            strokeWidth: 2,
                          ),
                        },
                        myLocationEnabled: true,
                        myLocationButtonEnabled: false,
                        zoomControlsEnabled: false,
                        mapToolbarEnabled: false,
                        onMapCreated: (ctrl) {
                          _radarMapController = ctrl;
                        },
                      ),
                      Positioned(
                        top: 10,
                        left: 10,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xDD0C1322),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: TechColors.electricCyan, width: 0.8),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.radar_rounded, color: TechColors.electricCyan, size: 14),
                              SizedBox(width: 6),
                              Text(
                                '15km Hyperlocal Radar Active',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            const Spacer(),

            // Big Power / Go Online Button
            Center(
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(100),
                  onTap: _toggleDuty,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: _isOnline ? 130 : 180,
                    height: _isOnline ? 130 : 180,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _isOnline
                          ? TechColors.cardSurface
                          : const Color(0xFF161A22),
                      border: Border.all(
                        color: _isOnline
                            ? TechColors.onlineGreen
                            : TechColors.offlineGray,
                        width: 4,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: (_isOnline
                                  ? TechColors.onlineGreen
                                  : Colors.black)
                              .withValues(alpha: 0.35),
                          blurRadius: 35,
                          spreadRadius: 8,
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.power_settings_new_rounded,
                          color: _isOnline
                              ? TechColors.onlineGreen
                              : TechColors.offlineGray,
                          size: _isOnline ? 44 : 58,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _isOnline ? 'GO OFFLINE' : 'GO ONLINE',
                          style: TextStyle(
                            color: _isOnline
                                ? TechColors.onlineGreen
                                : TechColors.platinumSilver,
                            fontWeight: FontWeight.w900,
                            fontSize: _isOnline ? 12 : 15,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            const Spacer(),

            // Test Incoming Job Overlay Trigger Button
            if (_isOnline)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: TextButton.icon(
                  onPressed: () {
                    IncomingJobAlertOverlay.show(
                      context: context,
                      proposalId: 'prop_991',
                      bookingId: 'BK-99824',
                      serviceType: 'Emergency Switchboard Repair',
                      customerName: 'Aarav Gupta',
                      customerAddress: 'B-402, Green Glen Heights, Sector 4',
                      distanceKm: '1.4',
                      payout: '450',
                    );
                  },
                  icon: const Icon(Icons.ring_volume_rounded, color: TechColors.electricGold, size: 18),
                  label: const Text(
                    'Simulate Incoming Job Alert',
                    style: TextStyle(color: TechColors.electricGold, fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                ),
              ),

            // Bottom Status Message
            Container(
              margin: const EdgeInsets.all(20),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: TechColors.cardSurface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: TechColors.cardBorder),
              ),
              child: Row(
                children: [
                  Icon(
                    _isOnline
                        ? Icons.radar_rounded
                        : Icons.pause_circle_outline_rounded,
                    color: _isOnline
                        ? TechColors.onlineGreen
                        : TechColors.textMuted,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _isOnline
                          ? 'Streaming live GPS to customer & admin dispatch radar in 15km radius...'
                          : 'You are currently offline. Tap the power button to receive job dispatches.',
                      style: const TextStyle(
                        color: TechColors.platinumSilver,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: TechColors.cardSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: TechColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              color: TechColors.pureWhite,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              color: TechColors.textMuted,
              fontSize: 9,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }
}
