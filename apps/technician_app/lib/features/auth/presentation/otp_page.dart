import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../dashboard/presentation/main_shell_page.dart';
import 'auth_provider.dart';
import '../../../core/network/api_result.dart';

class OtpPage extends ConsumerStatefulWidget {
  final String phoneNumber;
  final String emailAddress;
  const OtpPage({
    super.key,
    required this.phoneNumber,
    required this.emailAddress,
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
      );
      
      if (res is ApiSuccess<String>) {
        if (mounted) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const MainShellPage()),
            (route) => false,
          );
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
                    const Icon(Icons.email, size: 48, color: AppColors.primary),
                    const SizedBox(height: AppSpacing.s),
                    Text(
                      'We sent a verification code to\n${widget.emailAddress}',
                      style: AppTypography.bodyLarge,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.l),
                    TextFormField(
                      controller: _otpController,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      maxLength: 6,
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: 8),
                      decoration: const InputDecoration(
                        labelText: 'Enter 6-digit OTP',
                        hintText: 'Check email / mock console',
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
                        style: const TextStyle(color: Colors.red, fontSize: 12),
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
                        );
                      },
                      child: const Text('Resend Code'),
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
