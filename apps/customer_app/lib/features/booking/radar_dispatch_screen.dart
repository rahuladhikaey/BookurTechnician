import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../tracking/live_tracking_screen.dart';

class RadarDispatchScreen extends StatefulWidget {
  final String serviceName;
  final String category;

  const RadarDispatchScreen({
    super.key,
    required this.serviceName,
    required this.category,
  });

  @override
  State<RadarDispatchScreen> createState() => _RadarDispatchScreenState();
}

class _RadarDispatchScreenState extends State<RadarDispatchScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  bool _isMatched = false;
  int _searchTimeSec = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (mounted) {
        setState(() => _searchTimeSec++);
        if (_searchTimeSec == 4) {
          setState(() => _isMatched = true);
        }
      }
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.obsidianBlack,
      appBar: AppBar(
        title: const Text('DISPATCH RADAR'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: Column(
            children: [
              const SizedBox(height: 20),

              // Service Banner Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.cardSurface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.borderGlow),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceLight,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.handyman_rounded,
                        color: AppColors.electricGold,
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.serviceName,
                            style: const TextStyle(
                              color: AppColors.pureWhite,
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            widget.category,
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.emeraldGreen.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        _isMatched ? 'MATCHED' : 'SEARCHING',
                        style: TextStyle(
                          color: _isMatched
                              ? AppColors.emeraldGreen
                              : AppColors.electricGold,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const Spacer(),

              // Animated Radar Center
              Center(
                child: SizedBox(
                  width: 280,
                  height: 280,
                  child: AnimatedBuilder(
                    animation: _pulseController,
                    builder: (context, child) {
                      return Stack(
                        alignment: Alignment.center,
                        children: [
                          // Outer Pulse Wave
                          Container(
                            width: 280 * _pulseController.value,
                            height: 280 * _pulseController.value,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: (_isMatched
                                        ? AppColors.emeraldGreen
                                        : AppColors.electricGold)
                                    .withValues(
                                      alpha: 1.0 - _pulseController.value,
                                    ),
                                width: 2,
                              ),
                            ),
                          ),
                          // Middle Wave
                          Container(
                            width: 190 * _pulseController.value,
                            height: 190 * _pulseController.value,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: (_isMatched
                                      ? AppColors.emeraldGreen
                                      : AppColors.electricGold)
                                  .withValues(
                                    alpha: (1.0 - _pulseController.value) * 0.15,
                                  ),
                            ),
                          ),
                          // Radar Ring Grid
                          Container(
                            width: 220,
                            height: 220,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: AppColors.borderGlow,
                                width: 1.5,
                              ),
                            ),
                          ),
                          Container(
                            width: 140,
                            height: 140,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: AppColors.borderGlow,
                                width: 1.5,
                              ),
                            ),
                          ),
                          // Center Core Pulse
                          Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _isMatched
                                  ? AppColors.emeraldGreen
                                  : AppColors.electricGold,
                              boxShadow: [
                                BoxShadow(
                                  color: (_isMatched
                                          ? AppColors.emeraldGreen
                                          : AppColors.electricGold)
                                      .withValues(alpha: 0.5),
                                  blurRadius: 25,
                                  spreadRadius: 4,
                                ),
                              ],
                            ),
                            child: Icon(
                              _isMatched
                                  ? Icons.check_circle_rounded
                                  : Icons.sensors_rounded,
                              color: AppColors.obsidianBlack,
                              size: 42,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),

              const Spacer(),

              // Status Bottom Card
              if (!_isMatched) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 18,
                    horizontal: 24,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.cardSurface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.borderGlow),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.electricGold,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Text(
                        'Scanning nearby master electricians... (${_searchTimeSec}s)',
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                // Matched Technician Card
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: AppColors.cardSurface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: AppColors.emeraldGreen.withValues(alpha: 0.6),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.emeraldGreen.withValues(alpha: 0.15),
                        blurRadius: 20,
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              color: AppColors.surfaceLight,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: AppColors.emeraldGreen,
                                width: 2,
                              ),
                            ),
                            child: const Center(
                              child: Icon(
                                Icons.person_rounded,
                                color: AppColors.pureWhite,
                                size: 30,
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Rajesh Sharma',
                                  style: TextStyle(
                                    color: AppColors.pureWhite,
                                    fontSize: 17,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                SizedBox(height: 3),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.star_rounded,
                                      color: AppColors.electricGold,
                                      size: 16,
                                    ),
                                    SizedBox(width: 4),
                                    Text(
                                      '4.92 (480+ Jobs) • 1.4 km away',
                                      style: TextStyle(
                                        color: AppColors.textSecondary,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.emeraldGreen,
                            foregroundColor: Colors.white,
                          ),
                          onPressed: () {
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const LiveTrackingScreen(
                                  bookingId: 'BK-99824',
                                  technicianName: 'Rajesh Sharma',
                                  serviceName: 'Emergency Electrical Repair',
                                ),
                              ),
                            );
                          },
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.navigation_rounded, size: 20),
                              SizedBox(width: 10),
                              Text(
                                'TRACK TECHNICIAN LIVE',
                                style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
