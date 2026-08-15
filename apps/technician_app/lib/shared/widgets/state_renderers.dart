import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_typography.dart';
import '../../core/theme/semantic_colors.dart';

class LoadingRenderer extends StatelessWidget {
  final String message;
  const LoadingRenderer({super.key, this.message = 'Loading...'});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(color: AppColors.primary),
          const SizedBox(height: AppSpacing.m),
          Text(message, style: AppTypography.bodyMedium),
        ],
      ),
    );
  }
}

class EmptyRenderer extends StatelessWidget {
  final String message;
  final IconData icon;
  const EmptyRenderer({
    super.key,
    this.message = 'No data available',
    this.icon = Icons.info_outline,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 48, color: AppColors.textSecondary.withValues(alpha: 0.5)),
          const SizedBox(height: AppSpacing.s),
          Text(message, style: AppTypography.titleMedium.copyWith(color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}

class ErrorRenderer extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const ErrorRenderer({
    super.key,
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.l),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: SemanticColors.error),
            const SizedBox(height: AppSpacing.s),
            Text(
              message,
              style: AppTypography.bodyLarge.copyWith(color: SemanticColors.error),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.m),
            ElevatedButton(
              onPressed: onRetry,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: const RoundedRectangleBorder(borderRadius: AppRadius.small),
              ),
              child: const Text('Retry', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
}

class SkeletonLoader extends StatelessWidget {
  final double width;
  final double height;
  final BorderRadius borderRadius;

  const SkeletonLoader({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius = AppRadius.small,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppColors.border.withValues(alpha: 0.5),
        borderRadius: borderRadius,
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: borderRadius,
          gradient: LinearGradient(
            colors: [
              Colors.transparent,
              Colors.white.withValues(alpha: 0.2),
              Colors.transparent,
            ],
            stops: const [0.3, 0.5, 0.7],
            begin: const Alignment(-1.0, -0.3),
            end: const Alignment(1.0, 0.3),
          ),
        ),
      ),
    );
  }
}
