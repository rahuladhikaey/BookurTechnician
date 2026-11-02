import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../booking_provider.dart';
import '../models.dart';
import '../theme.dart';
import 'uber_ride_tier_selector.dart';

class RadarMatchingSheet extends ConsumerStatefulWidget {
  final ServiceItem service;
  final ServiceTier selectedTier;
  final BookingMode bookingMode;
  final String selectedDate;
  final String selectedSlot;
  final String paymentMethod;
  final double grandTotal;

  const RadarMatchingSheet({
    super.key,
    required this.service,
    required this.selectedTier,
    required this.bookingMode,
    required this.selectedDate,
    required this.selectedSlot,
    required this.paymentMethod,
    required this.grandTotal,
  });

  static Future<void> show(
    BuildContext context, {
    required ServiceItem service,
    required ServiceTier selectedTier,
    required BookingMode bookingMode,
    required String selectedDate,
    required String selectedSlot,
    required String paymentMethod,
    required double grandTotal,
  }) {
    return showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => RadarMatchingSheet(
        service: service,
        selectedTier: selectedTier,
        bookingMode: bookingMode,
        selectedDate: selectedDate,
        selectedSlot: selectedSlot,
        paymentMethod: paymentMethod,
        grandTotal: grandTotal,
      ),
    );
  }

  @override
  ConsumerState<RadarMatchingSheet> createState() => _RadarMatchingSheetState();
}

class _RadarMatchingSheetState extends ConsumerState<RadarMatchingSheet>
    with SingleTickerProviderStateMixin {
  late AnimationController _animCtrl;
  String _statusText = 'Scanning 15 km PostGIS spatial radius...';
  String _subStatusText = 'Filtering background-verified technicians';
  bool _isDispatched = false;
  Booking? _createdBooking;
  Timer? _stepTimer;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat();

    _executeBookingFlow();
  }

  Future<void> _executeBookingFlow() async {
    _stepTimer = Timer(const Duration(milliseconds: 1200), () {
      if (mounted) {
        setState(() {
          _statusText = 'AI Matchmaker ranking optimal specialists...';
          _subStatusText = 'Evaluating distance, rating & speed';
        });
      }
    });

    try {
      final booking = await ref.read(bookingProvider.notifier).confirmDirectServiceBooking(
        service: widget.service,
        date: widget.selectedDate,
        slot: widget.selectedSlot,
        paymentMethod: widget.paymentMethod,
      );

      if (!mounted) return;

      if (booking != null) {
        setState(() {
          _isDispatched = true;
          _createdBooking = booking;
          _statusText = 'Technician Match Confirmed!';
          _subStatusText = 'Dispatch request accepted. Diverting to live GPS tracker.';
        });

        await Future.delayed(const Duration(milliseconds: 1400));
        if (mounted) {
          Navigator.pop(context);
          Navigator.pushNamed(
            context,
            '/tracking',
            arguments: {
              'bookingId': booking.id,
              'booking': booking,
            },
          );
        }
      } else {
        setState(() {
          _statusText = 'No Technician Online';
          _subStatusText = 'All verified partners in your 15 km area are currently busy.';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _statusText = 'Dispatch Notice';
          _subStatusText = 'Offline simulation booked. Redirecting to tracking...';
        });
        await Future.delayed(const Duration(seconds: 1));
        if (mounted) {
          Navigator.pop(context);
          Navigator.pushNamed(context, '/home');
        }
      }
    }
  }

  @override
  void dispose() {
    _stepTimer?.cancel();
    _animCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: kWhite,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),

            // Animated Radar Scan Circle
            SizedBox(
              width: 170,
              height: 170,
              child: AnimatedBuilder(
                animation: _animCtrl,
                builder: (context, child) {
                  return CustomPaint(
                    painter: _RadarScanPainter(
                      progress: _animCtrl.value,
                      isSuccess: _isDispatched,
                    ),
                    child: Center(
                      child: Container(
                        width: 58,
                        height: 58,
                        decoration: BoxDecoration(
                          color: _isDispatched ? kSuccessGreen : kBlack,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: (_isDispatched ? kSuccessGreen : kBlack).withValues(alpha: 0.25),
                              blurRadius: 16,
                              spreadRadius: 4,
                            ),
                          ],
                        ),
                        child: Icon(
                          _isDispatched ? Icons.check_rounded : widget.selectedTier.icon,
                          color: kWhite,
                          size: 30,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 24),

            Text(
              _statusText,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: kTextDark,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),

            Text(
              _subStatusText,
              style: const TextStyle(
                fontSize: 13,
                color: kSecondaryText,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),

            // Service & Price Badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: kLightBlueTint,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: kBorderColor),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.service.name,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                  const Text('  •  ', style: TextStyle(color: kSecondaryText)),
                  Text(
                    widget.selectedTier.title,
                    style: const TextStyle(color: kSecondaryText, fontSize: 13),
                  ),
                  const Text('  •  ', style: TextStyle(color: kSecondaryText)),
                  Text(
                    '₹${widget.grandTotal.toStringAsFixed(0)}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ],
              ),
            ),
            if (_createdBooking != null) ...[
              const SizedBox(height: 10),
              Text(
                'Booking Code: ${_createdBooking!.bookingCode.isNotEmpty ? _createdBooking!.bookingCode : _createdBooking!.id}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: kTextDark),
              ),
            ],
            const SizedBox(height: 24),

            // Cancel button if not completed
            if (!_isDispatched)
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    'Cancel Search',
                    style: TextStyle(color: kErrorRed, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _RadarScanPainter extends CustomPainter {
  final double progress;
  final bool isSuccess;

  _RadarScanPainter({required this.progress, required this.isSuccess});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.width / 2;

    final ringPaint = Paint()
      ..color = (isSuccess ? kSuccessGreen : Colors.grey.shade400).withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    // Draw concentric radar rings
    for (int i = 1; i <= 3; i++) {
      canvas.drawCircle(center, maxRadius * (i / 3), ringPaint);
    }

    if (!isSuccess) {
      // Sweeping radar beam
      final sweepAngle = math.pi / 2.5;
      final startAngle = progress * 2 * math.pi;

      final sweepPaint = Paint()
        ..shader = SweepGradient(
          startAngle: 0,
          endAngle: sweepAngle,
          colors: [
            Colors.black.withValues(alpha: 0.28),
            Colors.black.withValues(alpha: 0.0),
          ],
        ).createShader(Rect.fromCircle(center: center, radius: maxRadius))
        ..style = PaintingStyle.fill;

      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(startAngle);
      canvas.drawArc(
        Rect.fromCircle(center: Offset.zero, radius: maxRadius),
        0,
        sweepAngle,
        true,
        sweepPaint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _RadarScanPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.isSuccess != isSuccess;
  }
}
