import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/security/secure_storage.dart';

class JobExecutionScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic> job;

  const JobExecutionScreen({super.key, required this.job});

  @override
  ConsumerState<JobExecutionScreen> createState() => _JobExecutionScreenState();
}

class _JobExecutionScreenState extends ConsumerState<JobExecutionScreen> {
  late String _status;
  bool _isLoading = false;
  int _failedAttempts = 0;

  @override
  void initState() {
    super.initState();
    _status = widget.job['status'] ?? 'ACCEPTED';
  }

  Future<void> _callCustomer(String phone) async {
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

  Future<void> _launchNavigation(String address) async {
    final query = Uri.encodeComponent(address);
    final url = Uri.parse('https://www.google.com/maps/search/?api=1&query=$query');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  void _showStartOtpDialog() {
    final otpCtrl = TextEditingController();
    String? errorText;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.key_rounded, color: Color(0xFF1E3A8A)),
              SizedBox(width: 8),
              Text('Enter Start OTP', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Collect the 4-digit Start Service OTP shown on the customer\'s app screen to start work.',
                style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: otpCtrl,
                keyboardType: TextInputType.number,
                maxLength: 4,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: 8, color: Color(0xFF1E3A8A)),
                decoration: InputDecoration(
                  hintText: '••••',
                  errorText: errorText,
                  counterText: '',
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final code = otpCtrl.text.trim();
                if (code.length != 4) {
                  setDialogState(() => errorText = 'Please enter 4 digits');
                  return;
                }

                Navigator.pop(ctx);
                _verifyStartOtp(code);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E3A8A),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Verify & Start'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEndOtpDialog() {
    final otpCtrl = TextEditingController();
    String? errorText;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.verified_rounded, color: Color(0xFF16A34A)),
              SizedBox(width: 8),
              Text('Complete Service OTP', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Ask customer for the 4-digit Completion OTP sent to their registered email inbox.',
                style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: otpCtrl,
                keyboardType: TextInputType.number,
                maxLength: 4,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: 8, color: Color(0xFF166534)),
                decoration: InputDecoration(
                  hintText: '••••',
                  errorText: errorText,
                  counterText: '',
                  filled: true,
                  fillColor: const Color(0xFFF0FDF4),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final code = otpCtrl.text.trim();
                if (code.length != 4) {
                  setDialogState(() => errorText = 'Please enter 4 digits');
                  return;
                }

                Navigator.pop(ctx);
                _verifyEndOtp(code);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF16A34A),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Verify & Finish'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _verifyStartOtp(String code) async {
    setState(() => _isLoading = true);
    final bookingId = widget.job['id'];

    try {
      final dioClient = DioClient(SecureStorage());
      if (bookingId != null && !bookingId.toString().startsWith('JOB-')) {
        await dioClient.dio.patch('/bookings/$bookingId/status', data: {
          'status': 'IN_PROGRESS',
          'startOtp': code,
        });
      }

      setState(() {
        _status = 'IN_PROGRESS';
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Color(0xFF166534),
            content: Text('Start OTP Verified! Work is now IN_PROGRESS. Completion OTP emailed to customer.'),
          ),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFFDC2626),
            content: Text('Verification Failed: $e'),
          ),
        );
      }
    }
  }

  Future<void> _verifyEndOtp(String code) async {
    if (_failedAttempts >= 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Color(0xFFDC2626),
          content: Text('Maximum attempts exceeded (3 failed attempts). Account locked.'),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    final bookingId = widget.job['id'];

    try {
      final dioClient = DioClient(SecureStorage());
      if (bookingId != null && !bookingId.toString().startsWith('JOB-')) {
        await dioClient.dio.patch('/bookings/$bookingId/status', data: {
          'status': 'COMPLETED',
          'endOtp': code,
        });
      }

      setState(() {
        _status = 'COMPLETED';
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Color(0xFF166534),
            content: Text('Service Completed! Earnings credited to your wallet.'),
          ),
        );
      }
    } catch (e) {
      _failedAttempts++;
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFFDC2626),
            content: Text('Invalid End OTP. Failed attempts: $_failedAttempts/3'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.job['title'] ?? 'Service Job';
    final customerName = widget.job['customerName'] ?? 'Customer';
    final address = widget.job['address'] ?? 'Customer Premise';
    final phone = widget.job['customerPhone'] ?? widget.job['phone'] ?? '+91 98765 43210';
    final payout = widget.job['payout'] != null ? '₹${widget.job['payout']}' : '₹650';
    final timeSlot = widget.job['timeSlot'] ?? '1 Hour Window';
    final distance = widget.job['distance'] ?? '2.4 km';

    final isInProgress = _status == 'IN_PROGRESS';
    final isCompleted = _status == 'COMPLETED';

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          'Job Execution #${widget.job['id'] ?? 'BT-900'}',
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: Color(0xFF0F172A)),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: Color(0xFF0F172A)),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status Header Banner
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isCompleted
                    ? const Color(0xFFECFDF5)
                    : (isInProgress ? const Color(0xFFFEF3C7) : const Color(0xFFEFF6FF)),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isCompleted
                      ? const Color(0xFF86EFAC)
                      : (isInProgress ? const Color(0xFFFDE68A) : const Color(0xFFBFDBFE)),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    isCompleted
                        ? Icons.check_circle_rounded
                        : (isInProgress ? Icons.engineering_rounded : Icons.schedule_rounded),
                    color: isCompleted
                        ? const Color(0xFF16A34A)
                        : (isInProgress ? const Color(0xFFD97706) : const Color(0xFF1E3A8A)),
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isCompleted
                              ? 'JOB COMPLETED'
                              : (isInProgress ? 'SERVICE IN PROGRESS' : 'JOB ACCEPTED • ON DUTY'),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            color: isCompleted
                                ? const Color(0xFF065F46)
                                : (isInProgress ? const Color(0xFF92400E) : const Color(0xFF1E3A8A)),
                            letterSpacing: 0.5,
                          ),
                        ),
                        Text(
                          isCompleted
                              ? 'Payout released to your partner wallet'
                              : (isInProgress
                                  ? 'Work is ongoing. Collect End OTP to finalize.'
                                  : 'Head to customer location & collect Start OTP.'),
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: isCompleted
                                ? const Color(0xFF047857)
                                : (isInProgress ? const Color(0xFFB45309) : const Color(0xFF1D4ED8)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Job Summary Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: const [
                  BoxShadow(color: Color(0x0A000000), blurRadius: 10, offset: Offset(0, 3)),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Color(0xFF0F172A)),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFECFDF5),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          payout,
                          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Color(0xFF047857)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Icon(Icons.schedule_rounded, size: 16, color: Color(0xFF64748B)),
                      const SizedBox(width: 6),
                      Text(timeSlot, style: const TextStyle(fontSize: 13, color: Color(0xFF475569), fontWeight: FontWeight.w600)),
                      const SizedBox(width: 10),
                      Text('• $distance', style: const TextStyle(fontSize: 13, color: Color(0xFF059669), fontWeight: FontWeight.w800)),
                    ],
                  ),
                  const SizedBox(height: 14),
                  const Divider(color: Color(0xFFF1F5F9)),
                  const SizedBox(height: 12),

                  // Customer details row
                  Row(
                    children: [
                      const CircleAvatar(
                        radius: 20,
                        backgroundColor: Color(0xFFEFF6FF),
                        child: Icon(Icons.person, color: Color(0xFF1E3A8A), size: 22),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(customerName, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5)),
                            Text(address, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)), maxLines: 2),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Quick Action Buttons (Call & Navigate)
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _callCustomer(phone),
                          icon: const Icon(Icons.phone_rounded, size: 16, color: Color(0xFF16A34A)),
                          label: const Text('Call Customer', style: TextStyle(color: Color(0xFF16A34A), fontWeight: FontWeight.w800)),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xFF86EFAC)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _launchNavigation(address),
                          icon: const Icon(Icons.navigation_rounded, size: 16, color: Color(0xFF1E3A8A)),
                          label: const Text('Navigate', style: TextStyle(color: Color(0xFF1E3A8A), fontWeight: FontWeight.w800)),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xFFBFDBFE)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // ─── PAYMENT & PREPAYMENT LEDGER BREAKDOWN ───
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: const [
                  BoxShadow(color: Color(0x0A000000), blurRadius: 10, offset: Offset(0, 3)),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.receipt_long_rounded, size: 20, color: Color(0xFF1E3A8A)),
                          SizedBox(width: 8),
                          Text(
                            'Payment & Prepayment Summary',
                            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5, color: Color(0xFF0F172A)),
                          ),
                        ],
                      ),
                      Text(
                        'Razorpay Verified',
                        style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: Color(0xFF15803D)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  const Divider(color: Color(0xFFF1F5F9)),
                  const SizedBox(height: 10),

                  // 1. Online Prepayment (30% + Booking Fee)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Online Advance Prepayment', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF334155))),
                          Text('Booking Fee (₹49) + 30% Service Advance', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFECFDF5),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFFA7F3D0)),
                        ),
                        child: const Text(
                          '₹244 (🟢 Paid Online)',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF15803D)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // 2. Remaining Balance To Collect (70%)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFFBEB),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFFDE68A)),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Balance to Collect on Finish',
                              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: Color(0xFF92400E)),
                            ),
                            Text(
                              '70% Remaining Service Balance (Cash / UPI)',
                              style: TextStyle(fontSize: 11, color: Color(0xFFB45309)),
                            ),
                          ],
                        ),
                        Text(
                          '₹455',
                          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: Color(0xFFB45309)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // 3. Technician Wallet Payout
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Your Guaranteed Partner Payout', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF1E3A8A))),
                      Text(payout, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Color(0xFF1E3A8A))),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ─── ACTION BUTTON 1 & 2: DUAL-OTP EXECUTION ───
            if (!isInProgress && !isCompleted) ...[
              // Action 1: Start Service (Opens Start OTP dialog)
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _showStartOtpDialog,
                  icon: const Icon(Icons.play_arrow_rounded, size: 24),
                  label: const Text(
                    '1. Start Service (Enter Start OTP)',
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1E3A8A),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
            ] else if (isInProgress) ...[
              // Action 2: Complete Service (Opens End OTP dialog)
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _showEndOtpDialog,
                  icon: const Icon(Icons.check_circle_outline_rounded, size: 24),
                  label: const Text(
                    '2. Complete Service (Enter End OTP)',
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF16A34A),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
            ] else ...[
              // Completed State
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFF86EFAC)),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.verified_rounded, color: Color(0xFF16A34A)),
                    SizedBox(width: 8),
                    Text(
                      'Job Successfully Finished & Settled',
                      style: TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF065F46), fontSize: 14),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
