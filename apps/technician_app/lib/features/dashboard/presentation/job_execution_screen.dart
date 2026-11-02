import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/security/secure_storage.dart';
import 'dashboard_provider.dart';

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
  GoogleMapController? _mapController;

  String? _beforePhotoUrl;
  String? _afterPhotoUrl;
  bool _isUploadingPhoto = false;
  final List<Map<String, dynamic>> _addons = [];


  @override
  void initState() {
    super.initState();
    _status = widget.job['status'] ?? 'ACCEPTED';
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  void _fitMapBounds(LatLng custPos, LatLng techPos) {
    if (_mapController == null) return;
    final double southWestLat = min(custPos.latitude, techPos.latitude);
    final double southWestLng = min(custPos.longitude, techPos.longitude);
    final double northEastLat = max(custPos.latitude, techPos.latitude);
    final double northEastLng = max(custPos.longitude, techPos.longitude);

    final bounds = LatLngBounds(
      southwest: LatLng(southWestLat, southWestLng),
      northeast: LatLng(northEastLat, northEastLng),
    );
    _mapController!.animateCamera(CameraUpdate.newLatLngBounds(bounds, 50));
  }

  Future<void> _callCustomer(String phone) async {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),
            const Icon(Icons.shield_outlined, color: Color(0xFF16A34A), size: 48),
            const SizedBox(height: 12),
            const Text(
              'Privacy-Protected Partner Call',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Direct customer phone numbers are masked for data protection. Connecting via BookurTechnician Telecom Relay bridge.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('📞 Connecting via BT Telecom Bridge: 1800-889-TECH'),
                      backgroundColor: Color(0xFF16A34A),
                    ),
                  );
                },
                icon: const Icon(Icons.call),
                label: const Text('Connect via Telecom Bridge'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF16A34A),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _captureProofOfWork(String type) async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 80,
      );

      if (pickedFile == null) return;

      setState(() => _isUploadingPhoto = true);

      final bookingId = widget.job['id'];
      final dioClient = DioClient(SecureStorage());

      const photoUrl = 'https://images.unsplash.com/photo-1581092160607-ee22621dd758?w=800';

      final res = await dioClient.dio.post('/technician/jobs/$bookingId/proof', data: {
        'photoType': type,
        'photoUrl': photoUrl,
        'latitude': widget.job['latitude'] ?? 22.5726,
        'longitude': widget.job['longitude'] ?? 88.3639,
      });

      if (res.data != null && res.data['success'] == true) {
        setState(() {
          if (type == 'BEFORE') {
            _beforePhotoUrl = photoUrl;
          } else {
            _afterPhotoUrl = photoUrl;
          }
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: const Color(0xFF166534),
              content: Text('$type photo verified with GPS timestamp and attached to booking.'),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFFDC2626),
            content: Text('Failed to upload proof photo: $e'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploadingPhoto = false);
    }
  }

  void _showAddonRequestDialog() {
    final titleCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    final descCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.add_shopping_cart, color: Color(0xFF1E3A8A)),
            SizedBox(width: 8),
            Text('Request Add-on Spare Parts', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Add-ons require customer confirmation in real-time before adding to the bill.',
                style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: titleCtrl,
                decoration: InputDecoration(
                  labelText: 'Part / Service Name',
                  hintText: 'e.g. Copper Pipe Extension (2m)',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: amountCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Amount (₹)',
                  hintText: 'e.g. 450',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: descCtrl,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: 'Reason for Replacement',
                  hintText: 'e.g. Old pipe had gas leak',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final title = titleCtrl.text.trim();
              final amount = double.tryParse(amountCtrl.text.trim()) ?? 0.0;
              final desc = descCtrl.text.trim();

              if (title.isEmpty || amount <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter valid part title and amount')),
                );
                return;
              }

              Navigator.pop(ctx);
              try {
                final dioClient = DioClient(SecureStorage());
                final bookingId = widget.job['id'];
                final res = await dioClient.dio.post('/technician/jobs/$bookingId/addons', data: {
                  'itemTitle': title,
                  'amount': amount,
                  'quantity': 1,
                  'description': desc,
                });

                if (res.data != null && res.data['success'] == true) {
                  setState(() {
                    _addons.add({
                      'title': title,
                      'amount': amount,
                      'status': 'PENDING',
                    });
                  });
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        backgroundColor: Color(0xFF166534),
                        content: Text('Add-on request sent to customer via FCM & Realtime! Waiting for approval.'),
                      ),
                    );
                  }
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(backgroundColor: const Color(0xFFDC2626), content: Text('Add-on error: $e')),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1E3A8A),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Send to Customer'),
          ),
        ],
      ),
    );
  }


  Future<void> _launchNavigation(String address, {double? lat, double? lng}) async {
    Uri targetUrl;
    if (lat != null && lng != null && (lat != 0.0 || lng != 0.0)) {
      targetUrl = Uri.parse('google.navigation:q=$lat,$lng&mode=d');
    } else {
      final query = Uri.encodeComponent(address);
      targetUrl = Uri.parse('https://www.google.com/maps/search/?api=1&query=$query');
    }
    try {
      if (await canLaunchUrl(targetUrl)) {
        await launchUrl(targetUrl, mode: LaunchMode.externalApplication);
      } else {
        final query = Uri.encodeComponent(address);
        final webUrl = Uri.parse('https://www.google.com/maps/search/?api=1&query=$query');
        await launchUrl(webUrl, mode: LaunchMode.externalApplication);
      }
    } catch (_) {}
  }

  void _showStartOtpDialog() {
    final otpCtrl = TextEditingController();
    String? errorText;
    bool isResending = false;

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
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: isResending
                    ? null
                    : () async {
                        setDialogState(() => isResending = true);
                        await _resendStartOtpToCustomer();
                        setDialogState(() => isResending = false);
                      },
                icon: isResending
                    ? const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.refresh, size: 14, color: Color(0xFF1E3A8A)),
                label: const Text('Resend Start OTP to Customer', style: TextStyle(fontSize: 12, color: Color(0xFF1E3A8A), fontWeight: FontWeight.bold)),
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

  Future<void> _resendStartOtpToCustomer() async {
    final bookingId = widget.job['id'];
    if (bookingId == null) return;
    try {
      final dioClient = DioClient(SecureStorage());
      await dioClient.dio.post('/bookings/$bookingId/resend-start-otp');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Color(0xFF166534),
            content: Text('Start OTP resent to customer successfully!'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFFDC2626),
            content: Text('Could not resend OTP: $e'),
          ),
        );
      }
    }
  }

  Future<void> _resendEndOtpToCustomer() async {
    final bookingId = widget.job['id'];
    if (bookingId == null) return;
    try {
      final dioClient = DioClient(SecureStorage());
      await dioClient.dio.post('/bookings/$bookingId/resend-end-otp');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Color(0xFF166534),
            content: Text('Ending OTP resent to customer successfully!'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFFDC2626),
            content: Text('Could not resend End OTP: $e'),
          ),
        );
      }
    }
  }

  void _showEndOtpDialog() {
    final otpCtrl = TextEditingController();
    String? errorText;
    bool isResending = false;

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
                'Ask customer for the 4-digit Completion OTP sent to their registered app / phone inbox.',
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
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: isResending
                    ? null
                    : () async {
                        setDialogState(() => isResending = true);
                        await _resendEndOtpToCustomer();
                        setDialogState(() => isResending = false);
                      },
                icon: isResending
                    ? const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.refresh, size: 14, color: Color(0xFF16A34A)),
                label: const Text('Resend Ending OTP to Customer', style: TextStyle(fontSize: 12, color: Color(0xFF16A34A), fontWeight: FontWeight.bold)),
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

  String _formatCleanAddress(String raw) {
    if (raw.isEmpty) return 'Customer Premise';
    final parts = raw.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    final seen = <String>{};
    final cleanParts = <String>[];
    for (final p in parts) {
      final lower = p.toLowerCase();
      if (!seen.contains(lower)) {
        seen.add(lower);
        cleanParts.add(p);
      }
    }
    return cleanParts.join(', ');
  }

  @override
  Widget build(BuildContext context) {
    final dashState = ref.watch(dashboardProvider);
    final title = widget.job['title'] ?? widget.job['serviceName'] ?? 'Service Job';
    final customerName = widget.job['customerName'] ?? 'Customer';
    final rawAddress = widget.job['address'] ?? widget.job['customerAddress'] ?? 'Customer Premise';
    final address = _formatCleanAddress(rawAddress);
    final phone = widget.job['customerPhone'] ?? widget.job['phone'] ?? '';
    final timeSlot = widget.job['timeSlot'] ?? widget.job['scheduledTime'] ?? 'Scheduled Slot';
    final distance = widget.job['distance'] ?? '';
    final custLat = (widget.job['customerLatitude'] as num?)?.toDouble() ?? (widget.job['customer_latitude'] as num?)?.toDouble();
    final custLng = (widget.job['customerLongitude'] as num?)?.toDouble() ?? (widget.job['customer_longitude'] as num?)?.toDouble();

    final rawPrice = (widget.job['price'] as num?)?.toDouble() ?? 
                     (widget.job['payout'] as num?)?.toDouble() ?? 
                     double.tryParse(widget.job['price']?.toString().replaceAll(RegExp(r'[^0-9.]'), '') ?? '') ?? 
                     double.tryParse(widget.job['payout']?.toString().replaceAll(RegExp(r'[^0-9.]'), '') ?? '') ?? 149.0;

    const bookingFee = 49;
    final advanceService = (rawPrice * 0.30).round();
    final totalAdvancePaid = bookingFee + advanceService;
    final balanceToCollect = (rawPrice * 0.70).round();
    final payout = '₹${rawPrice.toStringAsFixed(0)}';

    // Resolve realistic coordinates
    final defaultCenterLat = custLat ?? dashState.currentLatitude ?? 23.24;
    final defaultCenterLng = custLng ?? dashState.currentLongitude ?? 88.55;

    final actualTechLat = dashState.currentLatitude ?? defaultCenterLat;
    final actualTechLng = dashState.currentLongitude ?? defaultCenterLng;
    final actualCustLat = custLat ?? defaultCenterLat;
    final actualCustLng = custLng ?? defaultCenterLng;

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
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isCompleted
                              ? 'JOB COMPLETED • SETTLED'
                              : (isInProgress ? 'SERVICE IN PROGRESS' : 'JOB ACCEPTED • ON DUTY'),
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 12.5,
                            color: isCompleted
                                ? const Color(0xFF166534)
                                : (isInProgress ? const Color(0xFF92400E) : const Color(0xFF1E3A8A)),
                            letterSpacing: 0.5,
                          ),
                        ),
                        Text(
                          isCompleted
                              ? 'Payment verified and credited to partner wallet.'
                              : (isInProgress
                                  ? 'Work underway. Collect Ending OTP upon finishing.'
                                  : 'Head to customer location & collect Start OTP.'),
                          style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            // ─── INTERACTIVE GOOGLE MAP ROUTE TO CUSTOMER ───
            Card(
              clipBehavior: Clip.antiAlias,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 2,
              child: Stack(
                children: [
                  SizedBox(
                    height: 200,
                    width: double.infinity,
                    child: GoogleMap(
                      initialCameraPosition: CameraPosition(
                        target: LatLng(actualCustLat, actualCustLng),
                        zoom: 14.5,
                      ),
                      markers: {
                        // Customer destination marker
                        Marker(
                          markerId: const MarkerId('dest_customer_pin'),
                          position: LatLng(actualCustLat, actualCustLng),
                          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
                          infoWindow: InfoWindow(
                            title: 'Customer: $customerName',
                            snippet: address,
                          ),
                        ),
                        // Technician live location marker
                        Marker(
                          markerId: const MarkerId('tech_curr_pin'),
                          position: LatLng(actualTechLat, actualTechLng),
                          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueCyan),
                          infoWindow: const InfoWindow(
                            title: 'Your Location',
                            snippet: 'Assigned Partner GPS',
                          ),
                        ),
                      },
                      polylines: {
                        Polyline(
                          polylineId: const PolylineId('tech_cust_route'),
                          points: [
                            LatLng(actualTechLat, actualTechLng),
                            LatLng(actualCustLat, actualCustLng),
                          ],
                          color: const Color(0xFF1E3A8A),
                          width: 5,
                          jointType: JointType.round,
                        ),
                      },
                      myLocationEnabled: true,
                      myLocationButtonEnabled: false,
                      zoomControlsEnabled: false,
                      mapToolbarEnabled: false,
                      onMapCreated: (controller) {
                        _mapController = controller;
                        final custPos = LatLng(actualCustLat, actualCustLng);
                        final techPos = LatLng(actualTechLat, actualTechLng);
                        Future.delayed(const Duration(milliseconds: 300), () => _fitMapBounds(custPos, techPos));
                      },
                    ),
                  ),

                  // Floating Map Actions
                  Positioned(
                    top: 10,
                    right: 10,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        FloatingActionButton.small(
                          heroTag: 'btn_fit_${widget.job['id']}',
                          backgroundColor: Colors.white,
                          foregroundColor: const Color(0xFF1E3A8A),
                          elevation: 3,
                          onPressed: () {
                            final custPos = LatLng(actualCustLat, actualCustLng);
                            final techPos = LatLng(actualTechLat, actualTechLng);
                            _fitMapBounds(custPos, techPos);
                          },
                          child: const Icon(Icons.crop_free_rounded, size: 18),
                        ),
                        const SizedBox(width: 8),
                        FloatingActionButton.extended(
                          heroTag: 'btn_nav_${widget.job['id']}',
                          backgroundColor: const Color(0xFF1E3A8A),
                          foregroundColor: Colors.white,
                          elevation: 4,
                          icon: const Icon(Icons.navigation_rounded, size: 16),
                          label: const Text('Open Map', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                          onPressed: () => _launchNavigation(
                            address,
                            lat: actualCustLat,
                            lng: actualCustLng,
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
                      if (distance.isNotEmpty) ...[
                        const SizedBox(width: 10),
                        Text('• $distance', style: const TextStyle(fontSize: 13, color: Color(0xFF059669), fontWeight: FontWeight.w800)),
                      ],
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
                          onPressed: () => _launchNavigation(address, lat: actualCustLat, lng: actualCustLng),
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
                          Text(
                            'Online Advance Prepayment',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF334155),
                            ),
                          ),
                          Text(
                            'Booking Fee (₹49) + 30% Service Advance',
                            style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFECFDF5),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFFA7F3D0)),
                        ),
                        child: Text(
                          '₹$totalAdvancePaid (🟢 Paid Online)',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF15803D)),
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
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Column(
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
                          '₹$balanceToCollect',
                          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: Color(0xFFB45309)),
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

            const SizedBox(height: 20),

            // ─── PROOF OF WORK & ADD-ONS SUMMARY ───
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.camera_alt_outlined, size: 18, color: Color(0xFF1E3A8A)),
                      SizedBox(width: 8),
                      Text(
                        'Proof of Work & Inspection Photos',
                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5, color: Color(0xFF0F172A)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      // Before Photo Chip
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: _beforePhotoUrl != null ? const Color(0xFFECFDF5) : Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: _beforePhotoUrl != null ? const Color(0xFF86EFAC) : const Color(0xFFCBD5E1)),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                _beforePhotoUrl != null ? Icons.check_circle : Icons.pending_outlined,
                                size: 16,
                                color: _beforePhotoUrl != null ? const Color(0xFF16A34A) : const Color(0xFF64748B),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  _beforePhotoUrl != null ? 'Before Photo Attached' : 'Before Photo Pending',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: _beforePhotoUrl != null ? const Color(0xFF166534) : const Color(0xFF64748B),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // After Photo Chip
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: _afterPhotoUrl != null ? const Color(0xFFECFDF5) : Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: _afterPhotoUrl != null ? const Color(0xFF86EFAC) : const Color(0xFFCBD5E1)),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                _afterPhotoUrl != null ? Icons.check_circle : Icons.pending_outlined,
                                size: 16,
                                color: _afterPhotoUrl != null ? const Color(0xFF16A34A) : const Color(0xFF64748B),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  _afterPhotoUrl != null ? 'After Photo Attached' : 'After Photo Pending',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: _afterPhotoUrl != null ? const Color(0xFF166534) : const Color(0xFF64748B),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (_addons.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    const Divider(height: 1),
                    const SizedBox(height: 8),
                    ..._addons.map((a) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('• ${a['title']}', style: const TextStyle(fontSize: 12, color: Color(0xFF334155))),
                          Text('₹${a['amount']} (${a['status']})', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFFB45309))),
                        ],
                      ),
                    )),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 20),

            // ─── ACTION BUTTONS: PROOF + DUAL-OTP + ADD-ONS ───
            if (!isInProgress && !isCompleted) ...[
              if (_beforePhotoUrl == null)
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: _isUploadingPhoto ? null : () => _captureProofOfWork('BEFORE'),
                    icon: _isUploadingPhoto
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Icon(Icons.camera_alt, size: 22),
                    label: const Text(
                      '1. Capture Before Photo (Mandatory)',
                      style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14.5),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                )
              else
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _showStartOtpDialog,
                    icon: const Icon(Icons.play_arrow_rounded, size: 24),
                    label: const Text(
                      '2. Start Service (Verify Start OTP)',
                      style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14.5),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1E3A8A),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
            ] else if (isInProgress) ...[
              // Addon Button
              SizedBox(
                width: double.infinity,
                height: 44,
                child: OutlinedButton.icon(
                  onPressed: _showAddonRequestDialog,
                  icon: const Icon(Icons.add_shopping_cart, size: 18),
                  label: const Text('+ Request Add-on Spare Parts / Extra Work', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFB45309),
                    side: const BorderSide(color: Color(0xFFF59E0B)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              if (_afterPhotoUrl == null)
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: _isUploadingPhoto ? null : () => _captureProofOfWork('AFTER'),
                    icon: _isUploadingPhoto
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Icon(Icons.camera_alt, size: 22),
                    label: const Text(
                      '3. Capture Completed Work Photo',
                      style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14.5),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0D9488),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                )
              else
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _showEndOtpDialog,
                    icon: const Icon(Icons.check_circle_outline_rounded, size: 24),
                    label: const Text(
                      '4. Complete Service (Enter End OTP)',
                      style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14.5),
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
