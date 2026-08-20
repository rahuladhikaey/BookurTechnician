import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/config/app_config.dart';
import '../../../core/services/audio_alert_service.dart';

class IncomingJobAlertOverlay extends StatefulWidget {
  final String proposalId;
  final String bookingId;
  final String serviceType;
  final String customerName;
  final String customerAddress;
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
      if (widget.proposalId.isNotEmpty) {
        final dio = DioClient().dio;
        await dio.post(
          '${AppConfig.apiBaseUrl}/dispatch/proposals/${widget.proposalId}/decline',
          data: {'reason': 'DECLINED_BY_PARTNER'},
        );
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
      final endpoint = widget.proposalId.isNotEmpty
          ? '${AppConfig.apiBaseUrl}/dispatch/proposals/${widget.proposalId}/accept'
          : '${AppConfig.apiBaseUrl}/bookings/${widget.bookingId}/accept';

      final response = await dio.post(endpoint);
      debugPrint('[IncomingJobAlert] Accepted successfully: ${response.data}');

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Job Accepted! Navigating to customer location...'),
            backgroundColor: Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      debugPrint('[IncomingJobAlert] Accept error: $e');
      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not accept job: $e'),
            backgroundColor: Colors.red,
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
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Center(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: const Color(0xFF3B82F6).withAlpha(102), width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF3B82F6).withAlpha(64),
                    blurRadius: 30,
                    spreadRadius: 4,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 1. Blinking NEW JOB REQUEST Banner
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ScaleTransition(
                        scale: _pulseAnimation,
                        child: Container(
                          width: 12,
                          height: 12,
                          decoration: const BoxDecoration(
                            color: Color(0xFFEF4444),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'NEW SERVICE REQUEST',
                        style: TextStyle(
                          color: Color(0xFF60A5FA),
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // 2. Animated Circular Countdown Timer with Pulsating Bell
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      ScaleTransition(
                        scale: _pulseAnimation,
                        child: Container(
                          width: 140,
                          height: 140,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(0xFF3B82F6).withAlpha(31),
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 120,
                        height: 120,
                        child: CircularProgressIndicator(
                          value: progress,
                          strokeWidth: 8,
                          backgroundColor: const Color(0xFF1E293B),
                          valueColor: AlwaysStoppedAnimation<Color>(
                            progress > 0.3 ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                          ),
                        ),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.notifications_active, color: Color(0xFFFBBF24), size: 30),
                          const SizedBox(height: 4),
                          Text(
                            '${_remainingSeconds}s',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // 3. Expected Payout Badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF059669), Color(0xFF10B981)],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF10B981).withAlpha(77),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Estimated Payout: ',
                          style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                        Text(
                          '₹${widget.payout}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // 4. Job Details Card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: const Color(0xFF334155)),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: const Color(0xFF3B82F6).withAlpha(38),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.handyman_rounded, color: Color(0xFF60A5FA), size: 24),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    widget.serviceType,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${widget.distanceKm} km away from your location',
                                    style: const TextStyle(
                                      color: Color(0xFF34D399),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        const Divider(color: Color(0xFF334155), height: 1),
                        const SizedBox(height: 12),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.location_on, color: Color(0xFFEF4444), size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                widget.customerAddress,
                                style: const TextStyle(
                                  color: Color(0xFF94A3B8),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
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
                  const SizedBox(height: 28),

                  // 5. Action Buttons (Decline & Accept)
                  Row(
                    children: [
                      // Decline Button
                      Expanded(
                        flex: 1,
                        child: OutlinedButton(
                          onPressed: _isProcessing ? null : _handleDecline,
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xFFEF4444), width: 1.5),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          child: const Text(
                            'Decline',
                            style: TextStyle(
                              color: Color(0xFFEF4444),
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),

                      // Accept Button
                      Expanded(
                        flex: 2,
                        child: ElevatedButton(
                          onPressed: _isProcessing ? null : _handleAccept,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF10B981),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            elevation: 8,
                            shadowColor: const Color(0xFF10B981).withAlpha(128),
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
                                    Icon(Icons.check_circle_outline, size: 22),
                                    SizedBox(width: 8),
                                    Text(
                                      'ACCEPT JOB',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                    ],
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
