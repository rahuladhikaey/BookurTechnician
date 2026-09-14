import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import 'job_active_screen.dart';

class LiveTrackingScreen extends StatefulWidget {
  final String bookingId;
  final String technicianName;
  final String serviceName;

  const LiveTrackingScreen({
    super.key,
    required this.bookingId,
    required this.technicianName,
    required this.serviceName,
  });

  @override
  State<LiveTrackingScreen> createState() => _LiveTrackingScreenState();
}

class _LiveTrackingScreenState extends State<LiveTrackingScreen> {
  int _etaMinutes = 6;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 15), (t) {
      if (mounted && _etaMinutes > 1) {
        setState(() => _etaMinutes--);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.obsidianBlack,
      body: Stack(
        children: [
          // Simulated Dark Futuristic Map Canvas
          Container(
            width: double.infinity,
            height: double.infinity,
            color: const Color(0xFF0C1322),
            child: CustomPaint(
              painter: _MapCanvasPainter(),
            ),
          ),

          // Top Navigation Bar Overlay
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.cardSurface.withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.borderGlow),
                      ),
                      child: const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        color: AppColors.pureWhite,
                        size: 18,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.cardSurface.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.borderGlow),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.emeraldGreen,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          widget.bookingId,
                          style: const TextStyle(
                            color: AppColors.pureWhite,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Bottom Technician Tracking Card
          Positioned(
            left: 16,
            right: 16,
            bottom: 24,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.cardSurface,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppColors.borderGlow, width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.6),
                    blurRadius: 30,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ETA Badge
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.electricGold.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.electric_moped_rounded,
                              color: AppColors.electricGold,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'ARRIVING IN $_etaMinutes MINS',
                                style: const TextStyle(
                                  color: AppColors.electricGold,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const Text(
                                'Technician is en-route on TVS King Deluxe',
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      // Start OTP Pill
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceLight,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.borderGlow),
                        ),
                        child: const Column(
                          children: [
                            Text(
                              'START OTP',
                              style: TextStyle(
                                color: AppColors.textMuted,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              '4829',
                              style: TextStyle(
                                color: AppColors.pureWhite,
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const Divider(color: AppColors.borderGlow, height: 28),

                  // Technician Details & Actions
                  Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.surfaceLight,
                        ),
                        child: const Icon(
                          Icons.person_rounded,
                          color: AppColors.pureWhite,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.technicianName,
                              style: const TextStyle(
                                color: AppColors.pureWhite,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const Text(
                              'Electrician Lead • DL 4S 8821',
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Call Button
                      Container(
                        decoration: BoxDecoration(
                          color: AppColors.surfaceLight,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.borderGlow),
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.phone_rounded, color: AppColors.emeraldGreen, size: 20),
                          onPressed: () {},
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Chat Button
                      Container(
                        decoration: BoxDecoration(
                          color: AppColors.surfaceLight,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.borderGlow),
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.chat_bubble_rounded, color: AppColors.neonBlue, size: 20),
                          onPressed: () {},
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 18),

                  // Arrived / Start Service Action
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.electricGold,
                        foregroundColor: AppColors.obsidianBlack,
                      ),
                      onPressed: () {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (_) => JobActiveScreen(
                              bookingId: widget.bookingId,
                              technicianName: widget.technicianName,
                              serviceName: widget.serviceName,
                            ),
                          ),
                        );
                      },
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.play_arrow_rounded, size: 22),
                          SizedBox(width: 8),
                          Text(
                            'TECHNICIAN ARRIVED - START JOB',
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 13,
                              letterSpacing: 0.5,
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
        ],
      ),
    );
  }
}

class _MapCanvasPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = const Color(0xFF1E283D).withValues(alpha: 0.4)
      ..strokeWidth = 1.0;

    // Draw Grid Lines
    for (double x = 0; x < size.width; x += 40) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (double y = 0; y < size.height; y += 40) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // Draw Neon Route
    final routePaint = Paint()
      ..color = AppColors.neonBlue
      ..strokeWidth = 4.0
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final routeGlow = Paint()
      ..color = AppColors.neonBlue.withValues(alpha: 0.3)
      ..strokeWidth = 12.0
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final path = Path();
    path.moveTo(size.width * 0.2, size.height * 0.35);
    path.quadraticBezierTo(
      size.width * 0.5,
      size.height * 0.4,
      size.width * 0.75,
      size.height * 0.55,
    );

    canvas.drawPath(path, routeGlow);
    canvas.drawPath(path, routePaint);

    // Technician Marker Pin
    final techPin = Offset(size.width * 0.35, size.height * 0.38);
    final pinPaint = Paint()..color = AppColors.electricGold;
    canvas.drawCircle(techPin, 10, pinPaint);
    canvas.drawCircle(
      techPin,
      18,
      Paint()
        ..color = AppColors.electricGold.withValues(alpha: 0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );

    // Customer Home Destination Pin
    final homePin = Offset(size.width * 0.75, size.height * 0.55);
    canvas.drawCircle(homePin, 10, Paint()..color = AppColors.emeraldGreen);
    canvas.drawCircle(
      homePin,
      20,
      Paint()
        ..color = AppColors.emeraldGreen.withValues(alpha: 0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
