import 'package:flutter/material.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_typography.dart';
import '../../core/theme/semantic_colors.dart';

class DangerButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool enabled;

  const DangerButton({
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
      child: ElevatedButton(
        onPressed: enabled ? onPressed : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: SemanticColors.error,
          disabledBackgroundColor: SemanticColors.error.withValues(alpha: 0.5),
          shape: const RoundedRectangleBorder(
            borderRadius: AppRadius.medium,
          ),
          elevation: 0,
        ),
        child: Text(
          text,
          style: AppTypography.titleMedium.copyWith(color: Colors.white),
        ),
      ),
    );
  }
}
