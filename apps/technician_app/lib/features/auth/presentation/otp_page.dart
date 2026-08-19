import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../dashboard/presentation/main_shell_page.dart';
import '../../onboarding/data/skill_service.dart';
import '../../onboarding/presentation/skill_selection_page.dart';
import 'auth_provider.dart';
import '../../../core/network/api_result.dart';

class OtpPage extends ConsumerStatefulWidget {
  final String phoneNumber;
  final String emailAddress;
  final String? fullName;
  final int? age;
  final double? latitude;
  final double? longitude;

  const OtpPage({
    super.key,
    required this.phoneNumber,
    required this.emailAddress,
    this.fullName,
    this.age,
    this.latitude,
    this.longitude,
  });

  @override
  ConsumerState<OtpPage> createState() => _OtpPageState();
}

class _OtpPageState extends ConsumerState<OtpPage> {
  final _otpController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  String? _errorMsg;

  @override
  void dispose() {
    _otpController.dispose();
    super.dispose();
  }

  void _verifyOtp() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _errorMsg = null;
      });
      
      final code = _otpController.text.trim();
      final res = await ref.read(authProvider.notifier).verifyOtp(
        widget.phoneNumber, 
        code, 
        email: widget.emailAddress,
        fullName: widget.fullName,
        age: widget.age,
        latitude: widget.latitude,
        longitude: widget.longitude,
      );
      
      if (res is ApiSuccess<String>) {
        if (mounted) {
          // Check if technician already has skills configured
          try {
            final skillService = SkillService();
            final profile = await skillService.fetchMySkillProfile();
            if (profile != null && profile.skills.isNotEmpty) {
              if (mounted) {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (context) => const MainShellPage()),
                  (route) => false,
                );
              }
              return;
            }
          } catch (_) {}

          // Route to "Select Your Skills" onboarding screen
          if (mounted) {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (context) => const SkillSelectionPage(isOnboarding: true)),
              (route) => false,
            );
          }
        }
      } else if (res is ApiFailure<String>) {
        setState(() {
          _errorMsg = res.message;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final isBtnLoading = authState.status == AuthStatus.authenticating;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('OTP Verification'),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.l),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.m),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(Icons.mark_email_read_outlined, size: 36, color: Color(0xFF1E3A8A)),
                    ),
                    const SizedBox(height: AppSpacing.s),
                    if (widget.fullName != null && widget.fullName!.isNotEmpty) ...[
                      Text(
                        'Welcome, ${widget.fullName}!',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 4),
                    ],
                    Text(
                      'We sent a 6-digit verification code to\n${widget.emailAddress}',
                      style: AppTypography.bodyMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.l),
                    TextFormField(
                      controller: _otpController,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      maxLength: 6,
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: 8, color: Color(0xFF1E3A8A)),
                      decoration: const InputDecoration(
                        labelText: 'Enter 6-digit OTP',
                        hintText: '• • • • • •',
                        border: OutlineInputBorder(
                          borderRadius: AppRadius.small,
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().length != 6) {
                          return 'Please enter 6-digit code';
                        }
                        return null;
                      },
                    ),
                    if (_errorMsg != null) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        _errorMsg!,
                        style: const TextStyle(color: Color(0xFFDC2626), fontSize: 12),
                        textAlign: TextAlign.center,
                      ),
                    ],
                    const SizedBox(height: AppSpacing.l),
                    PrimaryButton(
                      text: 'Verify & Enter Console',
                      onPressed: _verifyOtp,
                      isLoading: isBtnLoading,
                    ),
                    const SizedBox(height: AppSpacing.m),
                    TextButton(
                      onPressed: () {
                        ref.read(authProvider.notifier).requestOtp(
                          widget.phoneNumber,
                          email: widget.emailAddress,
                          fullName: widget.fullName,
                          age: widget.age,
                        );
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Verification code resent to your email.')),
                        );
                      },
                      child: const Text('Resend Code', style: TextStyle(color: Color(0xFF1E3A8A), fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

