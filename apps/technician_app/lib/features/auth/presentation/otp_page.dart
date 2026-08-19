import 'dart:async';
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
  int _countdown = 30;
  StreamSubscription<int>? _timerSub;
  bool _isResending = false;

  @override
  void initState() {
    super.initState();
    _startCountdown();
  }

  void _startCountdown() {
    _countdown = 30;
    _timerSub?.cancel();
    _timerSub = Stream.periodic(const Duration(seconds: 1), (i) => i).listen((_) {
      if (!mounted) return;
      if (_countdown > 0) {
        setState(() => _countdown--);
      } else {
        _timerSub?.cancel();
      }
    });
  }

  @override
  void dispose() {
    _timerSub?.cancel();
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

  void _resendCode() async {
    if (_countdown > 0 || _isResending) return;

    setState(() => _isResending = true);
    final res = await ref.read(authProvider.notifier).requestOtp(
      widget.phoneNumber.isNotEmpty ? widget.phoneNumber : null,
      email: widget.emailAddress,
      fullName: widget.fullName,
      age: widget.age,
    );
    setState(() => _isResending = false);

    if (mounted) {
      if (res is ApiSuccess<bool>) {
        _startCountdown();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF166534),
            content: Text('New verification code sent to ${widget.emailAddress}!'),
          ),
        );
      } else if (res is ApiFailure<bool>) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFFDC2626),
            content: Text(res.message),
          ),
        );
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
        title: const Text('Partner OTP Verification'),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.l),
          child: Card(
            elevation: 4,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Official App Logo
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF1E3A8A).withValues(alpha: 0.12),
                            blurRadius: 14,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Image.asset('assets/images/app_logo.png', fit: BoxFit.cover),
                    ),
                    const SizedBox(height: 16),
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
                      onPressed: (_countdown == 0 && !_isResending) ? _resendCode : null,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_isResending) ...[
                            const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF1E3A8A)),
                            ),
                            const SizedBox(width: 6),
                          ],
                          Text(
                            _countdown > 0
                                ? 'Resend OTP in ${_countdown}s'
                                : 'Resend Code',
                            style: TextStyle(
                              color: _countdown > 0 ? AppColors.textSecondary : const Color(0xFF1E3A8A),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
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
