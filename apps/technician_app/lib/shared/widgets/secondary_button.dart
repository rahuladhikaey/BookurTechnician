import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_typography.dart';

class SecondaryButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool enabled;

  const SecondaryButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: OutlinedButton(
        onPressed: enabled ? onPressed : null,
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: AppColors.secondary, width: 1.5),
          shape: const RoundedRectangleBorder(
            borderRadius: AppRadius.medium,
          ),
          elevation: 0,
        ),
        child: Text(
          text,
          style: AppTypography.titleMedium.copyWith(color: AppColors.secondary),
        ),
      ),
    );
  }
}
