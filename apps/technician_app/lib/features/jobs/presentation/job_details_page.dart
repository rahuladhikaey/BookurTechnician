import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/semantic_colors.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../../shared/widgets/swipe_to_confirm_button.dart';
import '../domain/job.dart';
import 'states/job_state.dart';
import 'service_execution_page.dart';

class JobDetailsPage extends ConsumerStatefulWidget {
  final String bookingId;
  const JobDetailsPage({super.key, required this.bookingId});

  @override
  ConsumerState<JobDetailsPage> createState() => _JobDetailsPageState();
}

class _JobDetailsPageState extends ConsumerState<JobDetailsPage> {
  final _otpController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  String? _otpError;
  bool _resetSwipeButton = false;

  @override
  void dispose() {
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _openMapDirections(double? destLat, double? destLng, String address) async {
    Uri targetUrl;
    if (destLat != null && destLng != null) {
      targetUrl = Uri.parse("google.navigation:q=$destLat,$destLng&mode=d");
    } else {
      targetUrl = Uri.parse("https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(address)}");
    }

    try {
      if (await canLaunchUrl(targetUrl)) {
        await launchUrl(targetUrl, mode: LaunchMode.externalApplication);
      } else {
        final webUrl = Uri.parse("https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(address)}");
        await launchUrl(webUrl, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not open map navigation: $e'),
          backgroundColor: SemanticColors.error,
        ),
      );
    }
  }

  void _showStartOtpModal(BuildContext context, JobState jobState, JobStateNotifier notifier) {
    setState(() {
      _otpController.clear();
      _otpError = null;
    });

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: const EdgeInsets.all(AppSpacing.l),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.m),
                  const Text(
                    'Verification OTP Required',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: AppSpacing.s),
                  const Text(
                    'Please request the 4-digit start job OTP shown on the customer\'s tracking screen.',
                    style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.l),
                  TextFormField(
                    controller: _otpController,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    maxLength: 4,
                    style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, letterSpacing: 10),
                    decoration: InputDecoration(
                      hintText: '0000',
                      counterText: '',
                      filled: true,
                      fillColor: Colors.grey.shade50,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(color: Colors.grey.shade200),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(color: AppColors.primary, width: 2),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().length != 4) {
                        return 'Enter 4-digit code';
                      }
                      return null;
                    },
                  ),
                  if (_otpError != null) ...[
                    const SizedBox(height: AppSpacing.s),
                    Text(
                      _otpError!,
                      style: const TextStyle(color: SemanticColors.error, fontSize: 13, fontWeight: FontWeight.w500),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.l),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            Navigator.pop(context);
                            setState(() {
                              _resetSwipeButton = !_resetSwipeButton;
                            });
                          },
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.s),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () async {
                            if (_formKey.currentState!.validate()) {
                              final otp = _otpController.text.trim();
                              final verified = await notifier.verifyOtpOnServer(otp);
                              if (verified) {
                                if (context.mounted) {
                                  Navigator.pop(context);
                                  notifier.startService();
                                  Navigator.pushReplacement(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => ServiceExecutionPage(bookingId: widget.bookingId),
                                    ),
                                  );
                                }
                              } else {
                                setModalState(() {
                                  _otpError = ref.read(jobStateProvider).errorMessage ?? 'Incorrect OTP code. Try again.';
                                });
                              }
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.black,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          child: const Text('Verify & Start'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.s),
                  Text(
                    'Hint: Customer\'s OTP is ${jobState.activeJob?.otp ?? "4821"}',
                    style: TextStyle(color: Colors.grey.shade400, fontSize: 11),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ).then((_) {
      if (!ref.read(jobStateProvider).isOtpVerified) {
        setState(() {
          _resetSwipeButton = !_resetSwipeButton;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final jobState = ref.watch(jobStateProvider);
    final activeJob = jobState.activeJob;
    final notifier = ref.read(jobStateProvider.notifier);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Partner Execution Console'),
        elevation: 0,
        actions: [
          // Shift Online/Offline Switch
          Row(
            children: [
              Text(
                jobState.isShiftOnline ? 'ONLINE' : 'OFFLINE',
                style: TextStyle(
                  fontSize: 10, 
                  fontWeight: FontWeight.bold, 
                  color: jobState.isShiftOnline ? SemanticColors.success : Colors.white70
                ),
              ),
              const SizedBox(width: 4),
              Switch(
                value: jobState.isShiftOnline,
                activeThumbColor: SemanticColors.success,
                activeTrackColor: SemanticColors.success.withValues(alpha: 0.3),
                inactiveThumbColor: Colors.grey,
                onChanged: (val) {
                  notifier.toggleShift(val);
                },
              ),
            ],
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Stack(
        children: [
          if (activeJob == null)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.l),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.work_outline, size: 64, color: AppColors.textSecondary),
                    const SizedBox(height: AppSpacing.m),
                    const Text(
                      'No active booking loaded.',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: AppSpacing.s),
                    Text(
                      jobState.isShiftOnline 
                        ? 'Shift online active. Awaiting hyperlocal dispatch queries...'
                        : 'Go ONLINE in the top bar to start streaming GPS telemetry and receive dispatch requests.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
            )
          else
            Column(
              children: [
                // Socket Connection Alert Banners
                if (jobState.socketStatus == 'RECONNECTING')
                  Container(
                    color: SemanticColors.warning,
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Reconnecting to dispatch socket...',
                          style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  )
                else if (jobState.socketStatus == 'DISCONNECTED')
                  Container(
                    color: SemanticColors.error,
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.wifi_off, size: 14, color: Colors.white),
                        SizedBox(width: 8),
                        Text(
                          'Telemetry offline. Direct cellular mode.',
                          style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),

                // GPS Warning Banner
                if (!jobState.isGpsGranted)
                  Container(
                    color: AppColors.textPrimary,
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Expanded(
                          child: Text(
                            '⚠️ Location access denied. Enable GPS services.',
                            style: TextStyle(color: Colors.white, fontSize: 11),
                          ),
                        ),
                        TextButton(
                          onPressed: () => notifier.toggleGpsPermission(true),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: const Text('ENABLE', style: TextStyle(color: AppColors.secondary, fontWeight: FontWeight.bold, fontSize: 11)),
                        ),
                      ],
                    ),
                  ),

                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(AppSpacing.m, AppSpacing.m, AppSpacing.m, 120),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(AppSpacing.m),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  activeJob.title,
                                  style: AppTypography.h2.copyWith(fontSize: 18),
                                ),
                                const SizedBox(height: AppSpacing.xs),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text('Customer: ${activeJob.customerName}', style: AppTypography.titleMedium),
                                    Text(
                                      '₹${activeJob.price.toStringAsFixed(0)}',
                                      style: AppTypography.titleMedium.copyWith(color: AppColors.primary, fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: AppSpacing.s),
                                Text(
                                  'Address:\n${activeJob.customerAddress}',
                                  style: AppTypography.bodyLarge.copyWith(color: AppColors.textSecondary),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.m),

                        // OpenStreetMap Map View for Job Details
                        Card(
                          clipBehavior: Clip.antiAlias,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.m)),
                          child: Stack(
                            children: [
                              SizedBox(
                                height: 260,
                                width: double.infinity,
                                child: FlutterMap(
                                  options: MapOptions(
                                    initialCenter: LatLng(
                                      activeJob.customerLatitude ?? 12.971598,
                                      activeJob.customerLongitude ?? 77.594566,
                                    ),
                                    initialZoom: 14.5,
                                  ),
                                  children: [
                                    TileLayer(
                                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                      userAgentPackageName: 'com.bookurtechnician.technician',
                                    ),
                                    PolylineLayer(
                                      polylines: [
                                        if (activeJob.techLatitude != null && activeJob.customerLatitude != null)
                                          Polyline(
                                            points: [
                                              LatLng(activeJob.techLatitude!, activeJob.techLongitude!),
                                              LatLng(activeJob.customerLatitude!, activeJob.customerLongitude!),
                                            ],
                                            color: AppColors.primary,
                                            strokeWidth: 4,
                                          ),
                                      ],
                                    ),
                                    MarkerLayer(
                                      markers: [
                                        Marker(
                                          point: LatLng(
                                            activeJob.customerLatitude ?? 12.971598,
                                            activeJob.customerLongitude ?? 77.594566,
                                          ),
                                          width: 40,
                                          height: 40,
                                          child: const Icon(Icons.location_pin, color: Colors.red, size: 32),
                                        ),
                                        if (activeJob.techLatitude != null && activeJob.techLongitude != null)
                                          Marker(
                                            point: LatLng(
                                              activeJob.techLatitude!,
                                              activeJob.techLongitude!,
                                            ),
                                            width: 40,
                                            height: 40,
                                            child: const Icon(Icons.navigation, color: AppColors.primary, size: 28),
                                          ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              // Directions Floating action button
                              Positioned(
                                top: 12,
                                right: 12,
                                child: FloatingActionButton.extended(
                                  key: const Key('btn_navigate'),
                                  onPressed: () => _openMapDirections(
                                    activeJob.customerLatitude,
                                    activeJob.customerLongitude,
                                    activeJob.customerAddress,
                                  ),
                                  backgroundColor: Colors.white,
                                  foregroundColor: AppColors.primary,
                                  elevation: 4,
                                  icon: const Icon(Icons.navigation, size: 18),
                                  label: const Text('Directions', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),

          // Collapsible dispatch request alert dialog (Countdown Modal)
          if (jobState.showJobAlert && jobState.proposedJob != null)
            Positioned.fill(
              child: Container(
                color: Colors.black54,
                alignment: Alignment.center,
                padding: const EdgeInsets.all(AppSpacing.l),
                child: Card(
                  elevation: 8,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.l),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(height: AppSpacing.s),
                        // Pulsing radar animation simulation icon
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.radar, size: 48, color: AppColors.primary),
                        ),
                        const SizedBox(height: AppSpacing.m),
                        const Text(
                          'New Dispatch Request!',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: AppColors.textPrimary),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        const Text(
                          'Hyperlocal partner match found in your radius.',
                          style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                        ),
                        const SizedBox(height: AppSpacing.l),
                        
                        // Job request details card
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(jobState.proposedJob!.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                              const SizedBox(height: 4),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('Client: ${jobState.proposedJob!.customerName}', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                                  Text(
                                    'Payout: ₹${jobState.proposedJob!.price.toStringAsFixed(0)}',
                                    style: const TextStyle(fontWeight: FontWeight.bold, color: SemanticColors.success, fontSize: 13),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: AppSpacing.l),

                        // Countdown UI
                        Stack(
                          alignment: Alignment.center,
                          children: [
                            SizedBox(
                              width: 60,
                              height: 60,
                              child: CircularProgressIndicator(
                                value: jobState.jobAlertCountdown / 45,
                                strokeWidth: 5,
                                color: jobState.jobAlertCountdown > 10 ? AppColors.primary : SemanticColors.error,
                                backgroundColor: Colors.grey.shade200,
                              ),
                            ),
                            Text(
                              '${jobState.jobAlertCountdown}',
                              style: TextStyle(
                                fontSize: 18, 
                                fontWeight: FontWeight.bold,
                                color: jobState.jobAlertCountdown > 10 ? AppColors.textPrimary : SemanticColors.error
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.l),

                        // Accept/Reject buttons
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () {
                                  notifier.rejectProposedJob();
                                },
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  side: const BorderSide(color: SemanticColors.error),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                child: const Text('Decline', style: TextStyle(color: SemanticColors.error, fontWeight: FontWeight.bold)),
                              ),
                            ),
                            const SizedBox(width: AppSpacing.m),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () {
                                  notifier.acceptProposedJob();
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: SemanticColors.success,
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                child: const Text('Accept Payout', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                              ),
                            ),
                          ],
                        )
                      ],
                    ),
                  ),
                ),
              ),
            ),

          // Bottom sticky action panel
          if (activeJob != null)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(AppSpacing.m),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 10,
                      offset: const Offset(0, -3),
                    ),
                  ],
                ),
                child: SafeArea(
                  top: false,
                  child: _buildActionWidget(context, jobState, notifier),
                ),
              ),
            )
        ],
      ),
    );
  }

  Widget _buildActionWidget(BuildContext context, JobState jobState, JobStateNotifier notifier) {
    final activeJob = jobState.activeJob!;
    
    if (activeJob.status == TechJobStatus.accepted) {
      return SwipeToConfirmButton(
        key: ValueKey('swipe_start_journey_$_resetSwipeButton'),
        text: 'Swipe to Start Journey',
        thumbIcon: Icons.local_shipping,
        onConfirm: () {
          notifier.startJourney();
        },
      );
    } else if (activeJob.status == TechJobStatus.onTheWay) {
      return SwipeToConfirmButton(
        key: ValueKey('swipe_mark_arrived_$_resetSwipeButton'),
        text: 'Swipe to Mark Arrived',
        thumbIcon: Icons.location_on,
        thumbColor: SemanticColors.success,
        trackColor: SemanticColors.success.withValues(alpha: 0.15),
        textColor: SemanticColors.success,
        onConfirm: () {
          notifier.markArrived();
        },
      );
    } else if (activeJob.status == TechJobStatus.arrived) {
      return SwipeToConfirmButton(
        key: ValueKey('swipe_start_job_$_resetSwipeButton'),
        text: 'Swipe to Start Job',
        thumbIcon: Icons.play_arrow,
        thumbColor: AppColors.primary,
        onConfirm: () {
          _showStartOtpModal(context, jobState, notifier);
        },
      );
    } else if (activeJob.status == TechJobStatus.otpVerified) {
      return PrimaryButton(
        text: 'Begin Service Work',
        onPressed: () {
          notifier.startService();
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => ServiceExecutionPage(bookingId: activeJob.id),
            ),
          );
        },
      );
    }

    return const SizedBox.shrink();
  }
}
