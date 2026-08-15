import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/primary_button.dart';
import 'states/job_state.dart';

class ForwardServicePage extends ConsumerStatefulWidget {
  final String bookingId;
  const ForwardServicePage({super.key, required this.bookingId});

  @override
  ConsumerState<ForwardServicePage> createState() => _ForwardServicePageState();
}

class _ForwardServicePageState extends ConsumerState<ForwardServicePage> {
  final _reasonController = TextEditingController();
  final _dateController = TextEditingController(text: '15 Aug 2026');
  final _explanationController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _reasonController.dispose();
    _dateController.dispose();
    _explanationController.dispose();
    super.dispose();
  }

  void _submitRequest() {
    if (_formKey.currentState!.validate()) {
      final reason = _reasonController.text.trim();
      final date = _dateController.text.trim();
      final exp = _explanationController.text.trim();

      ref.read(jobStateProvider.notifier).requestForwardNextDay(
        reason,
        date,
        exp,
      );
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Next-day forward request submitted to customer for decision.'),
        ),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Forward Request Form'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.m),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Reschedule Next-Day Request',
                style: AppTypography.h1,
              ),
              const SizedBox(height: AppSpacing.xxs),
              const Text(
                'Complete this form to notify the customer why the service cannot be finished today and propose a new completion slot.',
                style: AppTypography.bodyMedium,
              ),
              const SizedBox(height: AppSpacing.l),
              
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.m),
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _reasonController,
                        decoration: const InputDecoration(
                          labelText: 'Mandatory Delay Reason',
                          hintText: 'e.g. Required replacement part unavailable today',
                          border: OutlineInputBorder(borderRadius: AppRadius.small),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Reschedule reason is mandatory';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: AppSpacing.m),
                      TextFormField(
                        controller: _dateController,
                        decoration: const InputDecoration(
                          labelText: 'Proposed Completion Date',
                          border: OutlineInputBorder(borderRadius: AppRadius.small),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Date is required';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: AppSpacing.m),
                      TextFormField(
                        controller: _explanationController,
                        maxLines: 4,
                        decoration: const InputDecoration(
                          labelText: 'Technician Explanation',
                          hintText: 'Provide details on what parts need to be sourced...',
                          border: OutlineInputBorder(borderRadius: AppRadius.small),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Detailed explanation is required';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: AppSpacing.l),
                      PrimaryButton(
                        text: 'Submit Forward Request',
                        onPressed: _submitRequest,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
