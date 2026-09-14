import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/semantic_colors.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../../shared/widgets/secondary_button.dart';
import '../../../shared/widgets/swipe_to_confirm_button.dart';
import '../../dashboard/presentation/dashboard_provider.dart';
import '../domain/job.dart';
import 'states/job_state.dart';
import 'additional_work_bottom_sheet.dart';
import 'forward_service_page.dart';

class ServiceExecutionPage extends ConsumerStatefulWidget {
  final String bookingId;
  const ServiceExecutionPage({super.key, required this.bookingId});

  @override
  ConsumerState<ServiceExecutionPage> createState() => _ServiceExecutionPageState();
}

class _ServiceExecutionPageState extends ConsumerState<ServiceExecutionPage> {
  final _endOtpController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  String? _endOtpError;
  bool _resetSwipe = false;

  @override
  void dispose() {
    _endOtpController.dispose();
    super.dispose();
  }

  void _showEndJobInvoiceModal(BuildContext context, TechJob activeJob, JobState jobState, JobStateNotifier notifier) {
    setState(() {
      _endOtpController.clear();
      _endOtpError = null;
    });

    // Calculate invoice values
    final baseCost = activeJob.price;
    const visitFee = 99.0;
    final approvedAddons = activeJob.addOns.where((a) => a.isApproved).toList();
    final addonsTotal = approvedAddons.fold(0.0, (sum, item) => sum + item.price);
    final subtotal = baseCost + visitFee + addonsTotal;
    final gstTax = subtotal * 0.18;
    final grandTotal = subtotal + gstTax;

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
            child: SingleChildScrollView(
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Align(
                      alignment: Alignment.center,
                      child: Container(
                        width: 40,
                        height: 5,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.m),
                    const Text(
                      'Generated Invoice Summary',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                    ),
                    const SizedBox(height: AppSpacing.s),
                    const Divider(),
                    
                    // Invoice Itemized list
                    _buildInvoiceRow('Base Service Cost', '₹${baseCost.toStringAsFixed(0)}'),
                    _buildInvoiceRow('Visit Conveyance Fee', '₹${visitFee.toStringAsFixed(0)}'),
                    if (approvedAddons.isNotEmpty) ...[
                      ...approvedAddons.map((addon) => _buildInvoiceRow('${addon.name} (Approved)', '₹${addon.price.toStringAsFixed(0)}')),
                    ],
                    const Divider(),
                    _buildInvoiceRow('Subtotal', '₹${subtotal.toStringAsFixed(0)}', isBold: true),
                    _buildInvoiceRow('GST Tax (18%)', '₹${gstTax.toStringAsFixed(2)}'),
                    _buildInvoiceRow('Grand Total Earnings', '₹${grandTotal.toStringAsFixed(2)}', isBold: true, isPrimaryColor: true),
                    const Divider(),
                    
                    const SizedBox(height: AppSpacing.m),
                    const Text(
                      'Input Customer End-OTP',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    const Text(
                      'Ask the customer for the 4-digit end OTP shown on their screen to authorize payment & complete job:',
                      style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: AppSpacing.s),
                    TextFormField(
                      controller: _endOtpController,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      maxLength: 4,
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 8),
                      decoration: InputDecoration(
                        hintText: '0000',
                        counterText: '',
                        filled: true,
                        fillColor: Colors.grey.shade50,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().length != 4) {
                          return 'Enter 4-digit code';
                        }
                        return null;
                      },
                    ),
                    if (_endOtpError != null) ...[
                      const SizedBox(height: AppSpacing.s),
                      Text(
                        _endOtpError!,
                        style: const TextStyle(color: SemanticColors.error, fontSize: 13, fontWeight: FontWeight.w500),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.m),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              Navigator.pop(context);
                              setState(() {
                                _resetSwipe = !_resetSwipe;
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
                                final otp = _endOtpController.text.trim();
                                final verified = await notifier.verifyEndOtpOnServer(otp);
                                if (verified) {
                                  if (context.mounted) {
                                    Navigator.pop(context);
                                    
                                    // Record final earnings
                                    ref.read(dashboardProvider.notifier).addEarnings(grandTotal);
                                    notifier.completeService();
                                    
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Job BT-${activeJob.id} completed. Wallet credited with ₹${grandTotal.toStringAsFixed(2)}!'),
                                        backgroundColor: SemanticColors.success,
                                      ),
                                    );
                                    
                                    notifier.clearJob();
                                    Navigator.pop(context);
                                  }
                                } else {
                                  setModalState(() {
                                    _endOtpError = ref.read(jobStateProvider).errorMessage ?? 'Invalid End-OTP. Verify again.';
                                  });
                                }
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: SemanticColors.success,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                            child: const Text('Verify & End Job'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.s),
                    Align(
                      alignment: Alignment.center,
                      child: Text(
                        'Hint: Customer\'s End-OTP is ${jobState.endOtp}',
                        style: TextStyle(color: Colors.grey.shade400, fontSize: 11),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ).then((_) {
      if (!ref.read(jobStateProvider).isEndOtpVerified) {
        setState(() {
          _resetSwipe = !_resetSwipe;
        });
      }
    });
  }

  Widget _buildInvoiceRow(String label, String value, {bool isBold = false, bool isPrimaryColor = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: isBold ? AppColors.textPrimary : AppColors.textSecondary,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              color: isPrimaryColor ? AppColors.primary : AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  void _openAddonSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.l)),
      ),
      builder: (context) => const AdditionalWorkBottomSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final jobState = ref.watch(jobStateProvider);
    final activeJob = jobState.activeJob;
    final notifier = ref.read(jobStateProvider.notifier);

    if (activeJob == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Service Execution')),
        body: const Center(child: Text('No active job in progress.')),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Execution Console'),
        automaticallyImplyLeading: false,
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(AppSpacing.m, AppSpacing.m, AppSpacing.m, 180),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Service In Progress',
                      style: AppTypography.h2,
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: activeJob.status == TechJobStatus.forwardRequest
                            ? SemanticColors.warning.withValues(alpha: 0.1)
                            : AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: AppRadius.round,
                      ),
                      child: Text(
                        activeJob.status.name.toUpperCase(),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: activeJob.status == TechJobStatus.forwardRequest
                              ? SemanticColors.warning
                              : AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.m),

                // OSM Location Pinning Map View at top of Service Execution Page
                Card(
                  clipBehavior: Clip.antiAlias,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.m)),
                  child: SizedBox(
                    height: 180,
                    width: double.infinity,
                    child: FlutterMap(
                      options: MapOptions(
                        initialCenter: LatLng(
                          activeJob.customerLatitude ?? 12.971598,
                          activeJob.customerLongitude ?? 77.594566,
                        ),
                        initialZoom: 15.0,
                        interactionOptions: const InteractionOptions(flags: InteractiveFlag.none),
                      ),
                      children: [
                        TileLayer(
                          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                          userAgentPackageName: 'com.bookurtechnician.technician',
                        ),
                        MarkerLayer(
                          markers: [
                            Marker(
                              point: LatLng(
                                activeJob.customerLatitude ?? 12.971598,
                                activeJob.customerLongitude ?? 77.594566,
                              ),
                              width: 34,
                              height: 34,
                              child: const Icon(Icons.location_pin, color: Colors.red, size: 28),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.m),

                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.m),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Customer: ${activeJob.customerName}', style: AppTypography.titleMedium),
                        const SizedBox(height: AppSpacing.xxs),
                        Text('Location: ${activeJob.customerAddress}', style: AppTypography.bodyMedium),
                        const SizedBox(height: AppSpacing.s),
                        const Divider(),
                        const SizedBox(height: AppSpacing.s),
                        Text('Job Details: ${activeJob.title}', style: AppTypography.titleMedium),
                        Text('Base Price: ₹${activeJob.price}', style: AppTypography.bodyLarge.copyWith(color: AppColors.primary)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.m),

                if (activeJob.status == TechJobStatus.forwardRequest) ...[
                  Card(
                    color: SemanticColors.warning.withValues(alpha: 0.08),
                    shape: const RoundedRectangleBorder(
                      borderRadius: AppRadius.medium,
                      side: BorderSide(color: SemanticColors.warning, width: 1),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.m),
                      child: Column(
                        children: [
                          const Text(
                            'Next-Day Reschedule Requested',
                            style: TextStyle(color: SemanticColors.warning, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            'Reason: ${activeJob.forwardDetails?.reason}\nProposed Date: ${activeJob.forwardDetails?.requestedDate}',
                            style: AppTypography.bodyMedium,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: AppSpacing.m),
                          const Text(
                            '⚙️ Mock Customer Decision Simulator:',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                          ),
                          const SizedBox(height: AppSpacing.s),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () {
                                    notifier.simulateCustomerForwardDecision(false);
                                  },
                                  child: const Text('Decline Request', style: TextStyle(color: SemanticColors.error)),
                                ),
                              ),
                              const SizedBox(width: AppSpacing.s),
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: () {
                                    notifier.simulateCustomerForwardDecision(true);
                                  },
                                  style: ElevatedButton.styleFrom(backgroundColor: SemanticColors.success),
                                  child: const Text('Approve Reschedule', style: TextStyle(color: Colors.white)),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.m),
                ] else if (activeJob.status == TechJobStatus.forwardApproved) ...[
                  Card(
                    color: SemanticColors.success.withValues(alpha: 0.08),
                    shape: const RoundedRectangleBorder(
                      borderRadius: AppRadius.medium,
                      side: BorderSide(color: SemanticColors.success, width: 1),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.m),
                      child: Column(
                        children: [
                          const Text(
                            'Reschedule Request Approved',
                            style: TextStyle(color: SemanticColors.success, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            'Next service scheduled for ${activeJob.forwardDetails?.requestedDate}. You can resume next-day.',
                            style: AppTypography.bodyMedium,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: AppSpacing.m),
                          PrimaryButton(
                            text: 'Resume Next-Day Work',
                            onPressed: () {
                              notifier.resumeForwardedService();
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.m),
                ],

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Additional Work & Materials', style: AppTypography.titleMedium),
                    TextButton.icon(
                      onPressed: () => _openAddonSheet(context),
                      icon: const Icon(Icons.add_circle_outline, size: 16),
                      label: const Text('Add Work'),
                    ),
                  ],
                ),
                if (activeJob.addOns.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: AppSpacing.s),
                    child: Text('No additional add-ons requested yet.', style: TextStyle(color: Colors.grey)),
                  )
                else
                  ...activeJob.addOns.map((addon) {
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.m),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(addon.name, style: AppTypography.titleMedium),
                                Text('₹${addon.price.toStringAsFixed(0)}', style: AppTypography.titleMedium.copyWith(color: AppColors.primary)),
                              ],
                            ),
                            Text('Reason: ${addon.reason}', style: AppTypography.bodyMedium),
                            const SizedBox(height: AppSpacing.xs),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  addon.isApproved ? 'Approved & Paid' : 'Pending Customer Approval',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: addon.isApproved ? SemanticColors.success : SemanticColors.warning,
                                  ),
                                ),
                                if (!addon.isApproved)
                                  TextButton(
                                    onPressed: () {
                                      notifier.simulateCustomerAddonDecision(addon.id, true);
                                    },
                                    child: const Text('Simulate Approve'),
                                  )
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
              ],
            ),
          ),

          // Bottom sticky navigation action bar
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
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (activeJob.status == TechJobStatus.serviceStarted || activeJob.status == TechJobStatus.resumed) ...[
                      SecondaryButton(
                        text: 'Forward Next-Day Reschedule',
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ForwardServicePage(bookingId: activeJob.id),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: AppSpacing.s),
                      SwipeToConfirmButton(
                        key: ValueKey('swipe_end_job_$_resetSwipe'),
                        text: 'Swipe to End Job',
                        thumbIcon: Icons.check,
                        thumbColor: SemanticColors.success,
                        trackColor: SemanticColors.success.withValues(alpha: 0.15),
                        textColor: SemanticColors.success,
                        onConfirm: () {
                          _showEndJobInvoiceModal(context, activeJob, jobState, notifier);
                        },
                      ),
                    ],
                  ],
                ),
              ),
            ),
          )
        ],
      ),
    );
  }
}
