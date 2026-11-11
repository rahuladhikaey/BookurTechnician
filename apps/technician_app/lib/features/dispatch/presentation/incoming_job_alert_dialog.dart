import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/config/app_config.dart';
import '../../../core/services/audio_alert_service.dart';
import '../../dashboard/presentation/job_execution_screen.dart';

class IncomingJobAlertOverlay extends StatefulWidget {
  final String proposalId;
  final String bookingId;
  final String serviceType;
  final String customerName;
  final String customerAddress;
  final String customerPhone;
  final String distanceKm;
  final String payout;
  final int timeoutSeconds;

  const IncomingJobAlertOverlay({
    super.key,
    required this.proposalId,
    required this.bookingId,
    required this.serviceType,
    required this.customerName,
    required this.customerAddress,
    this.customerPhone = '',
    required this.distanceKm,
    required this.payout,
    this.timeoutSeconds = 45,
  });

  static Future<void> show({
    required BuildContext context,
    required String proposalId,
    required String bookingId,
    required String serviceType,
    required String customerName,
    required String customerAddress,
    String customerPhone = '',
    required String distanceKm,
    required String payout,
    int timeoutSeconds = 45,
  }) {
    return showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierLabel: 'Incoming Job Alert',
      barrierColor: Colors.black.withAlpha(217),
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (ctx, anim1, anim2) {
        return IncomingJobAlertOverlay(
          proposalId: proposalId,
          bookingId: bookingId,
          serviceType: serviceType,
          customerName: customerName,
          customerAddress: customerAddress,
          customerPhone: customerPhone,
          distanceKm: distanceKm,
          payout: payout,
          timeoutSeconds: timeoutSeconds,
        );
      },
      transitionBuilder: (ctx, anim1, anim2, child) {
        return ScaleTransition(
          scale: CurvedAnimation(parent: anim1, curve: Curves.easeOutBack),
          child: FadeTransition(opacity: anim1, child: child),
        );
      },
    );
  }

  @override
  State<IncomingJobAlertOverlay> createState() => _IncomingJobAlertOverlayState();
}

class _IncomingJobAlertOverlayState extends State<IncomingJobAlertOverlay>
    with SingleTickerProviderStateMixin {
  late int _remainingSeconds;
  Timer? _countdownTimer;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _remainingSeconds = widget.timeoutSeconds;

    // Start pulsating animation for the radar/bell ring
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _startCountdown();
  }

  void _startCountdown() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {
        if (_remainingSeconds > 0) {
          _remainingSeconds--;
        } else {
          _handleTimeout();
        }
      });
    });
  }

  Future<void> _handleTimeout() async {
    _countdownTimer?.cancel();
    await AudioAlertService().stopAlert();
    if (mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Job request timed out and was forwarded to another partner.'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  Future<void> _handleDecline() async {
    if (_isProcessing) return;
    _isProcessing = true;
    _countdownTimer?.cancel();

    // Immediately stop ringtone & vibration
    await AudioAlertService().stopAlert();

    try {
      final dio = DioClient().dio;
      final targetId = widget.proposalId.isNotEmpty ? widget.proposalId : widget.bookingId;
      try {
        await dio.post(
          '${AppConfig.apiBaseUrl}/dispatch/offers/$targetId/reject',
          data: {'reason': 'REJECTED_BY_TECHNICIAN'},
        );
      } catch (_) {
        try {
          await dio.post(
            '${AppConfig.apiBaseUrl}/dispatch/proposals/$targetId/decline',
            data: {'reason': 'DECLINED_BY_PARTNER'},
          );
        } catch (_) {
          await dio.post(
            '${AppConfig.apiBaseUrl}/technician/dispatch/$targetId/decline',
            data: {'reason': 'DECLINED_BY_PARTNER'},
          );
        }
      }
    } catch (e) {
      debugPrint('[IncomingJobAlert] Decline error: $e');
    }

    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _handleAccept() async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);
    _countdownTimer?.cancel();

    // Immediately stop ringtone & vibration
    await AudioAlertService().stopAlert();

    try {
      final dio = DioClient().dio;
      final targetId = widget.proposalId.isNotEmpty ? widget.proposalId : widget.bookingId;
      
      Response? response;
      try {
        response = await dio.post('${AppConfig.apiBaseUrl}/dispatch/offers/$targetId/accept');
      } catch (e) {
        try {
          response = await dio.post('${AppConfig.apiBaseUrl}/dispatch/proposals/$targetId/accept');
        } catch (_) {
          try {
            response = await dio.post('${AppConfig.apiBaseUrl}/technician/dispatch/$targetId/accept');
          } catch (_) {
            response = await dio.post('${AppConfig.apiBaseUrl}/bookings/${widget.bookingId}/accept');
          }
        }
      }

      debugPrint('[IncomingJobAlert] Accepted successfully: ${response.data}');

      if (mounted) {
        Navigator.of(context).pop();

        final dynamic rawResp = response.data;
        final dynamic respData = rawResp is Map ? (rawResp['data'] ?? rawResp['booking'] ?? rawResp) : null;
        String custPhone = widget.customerPhone;
        double? custLat;
        double? custLng;

        double? parseCoord(dynamic v) {
          if (v == null) return null;
          if (v is num) return v.toDouble();
          if (v is String) return double.tryParse(v.trim());
          return null;
        }

        if (respData is Map) {
          custPhone = respData['customerPhone']?.toString() ??
              respData['phone']?.toString() ??
              respData['customer']?['phone']?.toString() ??
              custPhone;
          custLat = parseCoord(respData['latitude'] ?? respData['customerLatitude'] ?? respData['customer']?['latitude']);
          custLng = parseCoord(respData['longitude'] ?? respData['customerLongitude'] ?? respData['customer']?['longitude']);
        }

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Expanded(child: Text('Job Accepted! Opening Map and Execution details...')),
              ],
            ),
            backgroundColor: Color(0xFF198754),
            behavior: SnackBarBehavior.floating,
          ),
        );

        // Immediate direct transition to Today Booking / Job Execution Screen
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => JobExecutionScreen(
              job: {
                'id': widget.bookingId,
                'title': widget.serviceType,
                'customerName': widget.customerName,
                'address': widget.customerAddress,
                'customerPhone': custPhone,
                'payout': widget.payout,
                'distance': '${widget.distanceKm} km',
                'customerLatitude': custLat,
                'customerLongitude': custLng,
                'status': 'ACCEPTED',
              },
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('[IncomingJobAlert] Accept error: $e');
      if (mounted) {
        Navigator.of(context).pop();
        String errorMsg = 'Could not accept job. Please try again.';
        if (e.toString().contains('409') || e.toString().contains('already')) {
          errorMsg = 'This booking has already been assigned to another partner.';
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMsg),
            backgroundColor: Colors.orange.shade800,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _pulseController.dispose();
    AudioAlertService().stopAlert();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final progress = _remainingSeconds / widget.timeoutSeconds;

    return PopScope(
      canPop: false, // Prevent accidental back button dismissal
      child: Scaffold(
        backgroundColor: const Color(0xFF222222).withValues(alpha: 0.85),
        body: SafeArea(
          child: Center(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFFFCF9F6), // Warm Background (#FCF9F6)
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: _remainingSeconds <= 10
                      ? const Color(0xFFDC3545)
                      : const Color(0xFFF46B12),
                  width: 2.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF222222).withAlpha(110),
                    blurRadius: 30,
                    spreadRadius: 4,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 1. NEW BOOKING REQUEST Banner (Soft Peach #FBE4D5 + Primary Orange #F46B12)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFBE4D5),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFF46B12).withValues(alpha: 0.35)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ScaleTransition(
                          scale: _pulseAnimation,
                          child: Container(
                            width: 10,
                            height: 10,
                            decoration: const BoxDecoration(
                              color: Color(0xFFF46B12),
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'NEW SERVICE BOOKING REQUEST',
                          style: TextStyle(
                            color: Color(0xFFE85B08),
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // 2. Animated Circular Countdown Timer with Pulsating Bell
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      ScaleTransition(
                        scale: _pulseAnimation,
                        child: Container(
                          width: 132,
                          height: 132,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Color(0xFFFBE4D5),
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 112,
                        height: 112,
                        child: CircularProgressIndicator(
                          value: progress,
                          strokeWidth: 8,
                          backgroundColor: const Color(0xFFEEE8E2),
                          valueColor: AlwaysStoppedAnimation<Color>(
                            progress > 0.3 ? const Color(0xFFF46B12) : const Color(0xFFDC3545),
                          ),
                        ),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.notifications_active, color: Color(0xFFF46B12), size: 28),
                          const SizedBox(height: 4),
                          Text(
                            '${_remainingSeconds}s',
                            style: const TextStyle(
                              color: Color(0xFF222222),
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // 3. Pure White Booking Info Card (#FFFFFF)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: const Color(0xFFEEE8E2)),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    widget.serviceType,
                                    style: const TextStyle(
                                      color: Color(0xFF222222),
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${widget.distanceKm} km away • Est. 60 mins',
                                    style: const TextStyle(
                                      color: Color(0xFFF46B12),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE8F5E9),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '₹${widget.payout}',
                                style: const TextStyle(
                                  color: Color(0xFF198754),
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        const Divider(color: Color(0xFFEEE8E2), height: 1),
                        const SizedBox(height: 12),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.location_on, color: Color(0xFFF46B12), size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                widget.customerAddress,
                                style: const TextStyle(
                                  color: Color(0xFF222222),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),

                  // 4. Primary Orange ACCEPT BOOKING + Secondary REJECT Button
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      onPressed: _isProcessing ? null : _handleAccept,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFF46B12), // Primary Orange (#F46B12)
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 2,
                      ),
                      child: _isProcessing
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                            )
                          : const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.check_circle_rounded, size: 22, color: Colors.white),
                                SizedBox(width: 8),
                                Text(
                                  'ACCEPT BOOKING',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: OutlinedButton(
                      onPressed: _isProcessing ? null : _handleDecline,
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFFEEE8E2), width: 1.5),
                        backgroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: const Text(
                        'REJECT',
                        style: TextStyle(
                          color: Color(0xFF77716C),
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
