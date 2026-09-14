import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/primary_button.dart';
import 'states/job_state.dart';

class AdditionalWorkBottomSheet extends ConsumerStatefulWidget {
  const AdditionalWorkBottomSheet({super.key});

  @override
  ConsumerState<AdditionalWorkBottomSheet> createState() => _AdditionalWorkBottomSheetState();
}

class _AdditionalWorkBottomSheetState extends ConsumerState<AdditionalWorkBottomSheet> {
  final _nameController = TextEditingController();
  final _priceController = TextEditingController();
  final _reasonController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      final name = _nameController.text.trim();
      final price = double.parse(_priceController.text.trim());
      final reason = _reasonController.text.trim();

      ref.read(jobStateProvider.notifier).addAddOnWork(name, price, reason);
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: AppSpacing.m,
        right: AppSpacing.m,
        top: AppSpacing.m,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Add Additional Work / Charges',
              style: AppTypography.titleMedium,
            ),
            const SizedBox(height: AppSpacing.m),
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Service Name / Material Item',
                hintText: 'e.g. Replacement capacitor node',
                border: OutlineInputBorder(borderRadius: AppRadius.small),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter item details';
                }
                return null;
              },
            ),
            const SizedBox(height: AppSpacing.s),
            TextFormField(
              controller: _priceController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Additional Price (₹)',
                hintText: 'e.g. 250',
                border: OutlineInputBorder(borderRadius: AppRadius.small),
              ),
              validator: (value) {
                if (value == null || double.tryParse(value) == null) {
                  return 'Please enter a valid price amount';
                }
                return null;
              },
            ),
            const SizedBox(height: AppSpacing.s),
            TextFormField(
              controller: _reasonController,
              decoration: const InputDecoration(
                labelText: 'Reason for Additional Work',
                hintText: 'e.g. Existing capacitor damaged causing speed drop',
                border: OutlineInputBorder(borderRadius: AppRadius.small),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Reason explanation is mandatory';
                }
                return null;
              },
            ),
            const SizedBox(height: AppSpacing.l),
            PrimaryButton(
              text: 'Submit to Customer',
              onPressed: _submit,
            ),
            const SizedBox(height: AppSpacing.m),
          ],
        ),
      ),
    );
  }
}
