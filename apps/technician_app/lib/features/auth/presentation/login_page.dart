import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/primary_button.dart';
import 'auth_provider.dart';
import 'otp_page.dart';
import '../../../core/network/api_result.dart';
import '../../dashboard/presentation/partner_legal_page.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  String? _errorMsg;

  @override
  void dispose() {
    _phoneController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  void _submitPhone() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _errorMsg = null;
      });
      final phone = _phoneController.text.trim();
      final email = _emailController.text.trim();
      final res = await ref.read(authProvider.notifier).requestOtp(phone, email: email);
      
      if (res is ApiSuccess<bool>) {
        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => OtpPage(phoneNumber: phone, emailAddress: email),
            ),
          );
        }
      } else if (res is ApiFailure<bool>) {
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
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.l),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Image.asset(
                  'assets/images/app_logo.png',
                  width: 90,
                  height: 90,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: AppRadius.medium,
                    ),
                    child: const Icon(Icons.construction, size: 40, color: AppColors.primary),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.l),
              const Text(
                'BookUrTechnician Pro',
                style: AppTypography.h1,
              ),
              const SizedBox(height: AppSpacing.xxs),
              const Text(
                'Technician partner console terminal',
                style: AppTypography.bodyMedium,
              ),
              const SizedBox(height: AppSpacing.xl),
              
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.m),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Register / Log In',
                          style: AppTypography.titleMedium,
                        ),
                        const SizedBox(height: AppSpacing.s),
                        TextFormField(
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          maxLength: 10,
                          decoration: const InputDecoration(
                            labelText: 'Mobile Number',
                            hintText: 'Enter 10 digit phone',
                            prefixIcon: Icon(Icons.phone),
                            border: OutlineInputBorder(
                              borderRadius: AppRadius.small,
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().length != 10) {
                              return 'Please enter 10 digits mobile';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: AppSpacing.s),
                        TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          decoration: const InputDecoration(
                            labelText: 'Email Address',
                            hintText: 'Enter email to send OTP',
                            prefixIcon: Icon(Icons.email),
                            border: OutlineInputBorder(
                              borderRadius: AppRadius.small,
                            ),
                          ),
                          validator: (value) {
                            final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
                            if (value == null || !emailRegex.hasMatch(value.trim())) {
                              return 'Please enter a valid email';
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
                        const SizedBox(height: AppSpacing.m),
                        PrimaryButton(
                          text: 'Send OTP to Email',
                          onPressed: _submitPhone,
                          isLoading: isBtnLoading,
                        ),
                        const SizedBox(height: AppSpacing.m),
                        Center(
                          child: Wrap(
                            alignment: WrapAlignment.center,
                            children: [
                              const Text(
                                'By registering as a Partner, you agree to our ',
                                style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                              ),
                              GestureDetector(
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => const PartnerLegalPage(initialTabIndex: 0)),
                                ),
                                child: const Text(
                                  'Partner Agreement',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.bold,
                                    decoration: TextDecoration.underline,
                                  ),
                                ),
                              ),
                              const Text(
                                ' & ',
                                style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                              ),
                              GestureDetector(
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => const PartnerLegalPage(initialTabIndex: 2)),
                                ),
                                child: const Text(
                                  'Privacy Policy',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.bold,
                                    decoration: TextDecoration.underline,
                                  ),
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
            ],
          ),
        ),
      ),
    );
  }
}
