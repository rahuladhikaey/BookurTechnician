import 'dart:async';
import 'package:flutter/material.dart';
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

  @override
  void initState() {
    super.initState();
    _setupIncomingJobListener();
  }

  void _setupIncomingJobListener() {
    TechnicianSocketService().connect(
      technicianId: widget.technicianProfileId,
    );
  }

  void _toggleDuty() {
    final newStatus = !_isOnline;
    setState(() => _isOnline = newStatus);

    if (newStatus) {
      // Start streaming GPS coordinates
      _gpsStreamTimer = Timer.periodic(const Duration(seconds: 5), (_) {
        // Location stream pulse
      });
    } else {
      _gpsStreamTimer?.cancel();
    }
  }

  @override
  void dispose() {
    _gpsStreamTimer?.cancel();
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
                            _isOnline ? 'Online (Accepting Jobs)' : 'Offline',
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
                    width: 200,
                    height: 200,
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
                          size: 64,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _isOnline ? 'GO OFFLINE' : 'GO ONLINE',
                          style: TextStyle(
                            color: _isOnline
                                ? TechColors.onlineGreen
                                : TechColors.platinumSilver,
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                            letterSpacing: 1.5,
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
                          ? 'Searching for nearby emergency & repair requests in 10km radius...'
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
