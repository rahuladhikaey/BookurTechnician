import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import '../../../core/theme/app_colors.dart';
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

class _LoginPageState extends ConsumerState<LoginPage> with SingleTickerProviderStateMixin {
  // Mode: 0 = Existing Partner Log In, 1 = New Partner Register
  int _selectedMode = 0; 

  final _loginEmailController = TextEditingController();
  
  final _regNameController = TextEditingController();
  final _regAgeController = TextEditingController();
  final _regPhoneController = TextEditingController();
  final _regEmailController = TextEditingController();

  final _formKey = GlobalKey<FormState>();
  String? _errorMsg;
  double? _latitude;
  double? _longitude;

  @override
  void initState() {
    super.initState();
    _requestInitialLocation();
  }

  Future<void> _requestInitialLocation() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.whileInUse || permission == LocationPermission.always) {
        final position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.medium,
          timeLimit: const Duration(seconds: 5),
        );
        if (mounted) {
          setState(() {
            _latitude = position.latitude;
            _longitude = position.longitude;
          });
        }
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _loginEmailController.dispose();
    _regNameController.dispose();
    _regAgeController.dispose();
    _regPhoneController.dispose();
    _regEmailController.dispose();
    super.dispose();
  }

  void _submitDetails() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _errorMsg = null;
      });

      if (_latitude == null || _longitude == null) {
        await _requestInitialLocation();
      }

      final isLogin = _selectedMode == 0;
      final email = isLogin 
          ? _loginEmailController.text.trim() 
          : _regEmailController.text.trim();
      final phone = isLogin 
          ? null 
          : _regPhoneController.text.trim();
      final name = isLogin 
          ? null 
          : _regNameController.text.trim();
      final age = isLogin 
          ? null 
          : int.tryParse(_regAgeController.text.trim());

      final res = await ref.read(authProvider.notifier).requestOtp(
        phone,
        email: email,
        fullName: name,
        age: age,
      );
      
      if (res is ApiSuccess<bool>) {
        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => OtpPage(
                phoneNumber: phone ?? '',
                emailAddress: email,
                fullName: name,
                age: age,
                latitude: _latitude,
                longitude: _longitude,
              ),
            ),
          );
        }
      } else if (res is ApiFailure<bool>) {
        if (mounted) {
          if (!isLogin && (res.message.toLowerCase().contains('already exists') || res.message.toLowerCase().contains('log in'))) {
            setState(() {
              _selectedMode = 0; // Auto-switch to "Existing Partner Log In"
              _loginEmailController.text = email;
              _errorMsg = '⚠️ ${res.message}';
            });
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('⚠️ ${res.message}'),
                backgroundColor: const Color(0xFFD97706),
                duration: const Duration(seconds: 4),
              ),
            );
          } else {
            setState(() {
              _errorMsg = res.message;
            });
          }
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final isBtnLoading = authState.status == AuthStatus.authenticating;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Top Logo Icon Container
                Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF1E3A8A).withValues(alpha: 0.12),
                        blurRadius: 18,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Image.asset(
                    'assets/images/app_logo.png',
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(height: 16),

                const Text(
                  'Join Technician Member',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF1E3A8A),
                    letterSpacing: -0.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),
                const Text(
                  'Sign in or register to receive instant service leads',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),

                // Tab Switcher (Log In vs Register)
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE2E8F0),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedMode = 0;
                              _errorMsg = null;
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: _selectedMode == 0 ? Colors.white : Colors.transparent,
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: _selectedMode == 0
                                  ? [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.06),
                                        blurRadius: 6,
                                        offset: const Offset(0, 2),
                                      )
                                    ]
                                  : [],
                            ),
                            child: Center(
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.login_rounded,
                                    size: 16,
                                    color: _selectedMode == 0 ? const Color(0xFF1E3A8A) : AppColors.textSecondary,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Partner Log In',
                                    style: TextStyle(
                                      fontSize: 13.5,
                                      fontWeight: _selectedMode == 0 ? FontWeight.w800 : FontWeight.w600,
                                      color: _selectedMode == 0 ? const Color(0xFF1E3A8A) : AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedMode = 1;
                              _errorMsg = null;
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: _selectedMode == 1 ? Colors.white : Colors.transparent,
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: _selectedMode == 1
                                  ? [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.06),
                                        blurRadius: 6,
                                        offset: const Offset(0, 2),
                                      )
                                    ]
                                  : [],
                            ),
                            child: Center(
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.person_add_outlined,
                                    size: 16,
                                    color: _selectedMode == 1 ? const Color(0xFF1E3A8A) : AppColors.textSecondary,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'New Register',
                                    style: TextStyle(
                                      fontSize: 13.5,
                                      fontWeight: _selectedMode == 1 ? FontWeight.w800 : FontWeight.w600,
                                      color: _selectedMode == 1 ? const Color(0xFF1E3A8A) : AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                
                // Form Card
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: AppColors.border),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.03),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(20),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _selectedMode == 0 
                              ? 'Log In with Registered Email' 
                              : 'Partner Registration',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _selectedMode == 0
                              ? 'Enter your registered email address to receive your verification OTP.'
                              : 'Please enter your full details to register and get onboarded.',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 18),

                        // ─── LOG IN MODE (Existing Partner) ───
                        if (_selectedMode == 0) ...[
                          TextFormField(
                            controller: _loginEmailController,
                            keyboardType: TextInputType.emailAddress,
                            decoration: InputDecoration(
                              labelText: 'Registered Email Address',
                              hintText: 'e.g. partner@example.com',
                              prefixIcon: const Icon(Icons.email_outlined, color: Color(0xFF1E3A8A)),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            validator: (value) {
                              final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
                              if (value == null || !emailRegex.hasMatch(value.trim())) {
                                return 'Please enter your registered email address';
                              }
                              return null;
                            },
                          ),
                        ],

                        // ─── REGISTER MODE (New Partner) ───
                        if (_selectedMode == 1) ...[
                          // Full Name
                          TextFormField(
                            controller: _regNameController,
                            keyboardType: TextInputType.name,
                            textCapitalization: TextCapitalization.words,
                            decoration: InputDecoration(
                              labelText: 'Full Name',
                              hintText: 'Enter your full name',
                              prefixIcon: const Icon(Icons.person_outline, color: Color(0xFF1E3A8A)),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.trim().length < 2) {
                                return 'Please enter your full name';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 14),

                          // Age
                          TextFormField(
                            controller: _regAgeController,
                            keyboardType: TextInputType.number,
                            maxLength: 2,
                            decoration: InputDecoration(
                              labelText: 'Age (in years)',
                              hintText: 'e.g. 28',
                              counterText: '',
                              prefixIcon: const Icon(Icons.cake_outlined, color: Color(0xFF1E3A8A)),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Please enter your age';
                              }
                              final parsed = int.tryParse(value.trim());
                              if (parsed == null || parsed < 18 || parsed > 75) {
                                return 'Age must be between 18 and 75';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 14),

                          // Mobile Number
                          TextFormField(
                            controller: _regPhoneController,
                            keyboardType: TextInputType.phone,
                            maxLength: 10,
                            decoration: InputDecoration(
                              labelText: 'Mobile Number',
                              hintText: '10 digit mobile number',
                              counterText: '',
                              prefixIcon: const Icon(Icons.phone_outlined, color: Color(0xFF1E3A8A)),
                              prefixText: '+91 ',
                              prefixStyle: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.trim().length != 10) {
                                return 'Please enter a valid 10-digit mobile number';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 14),

                          // Email Address
                          TextFormField(
                            controller: _regEmailController,
                            keyboardType: TextInputType.emailAddress,
                            decoration: InputDecoration(
                              labelText: 'Email Address',
                              hintText: 'Enter email to receive OTP',
                              prefixIcon: const Icon(Icons.email_outlined, color: Color(0xFF1E3A8A)),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            validator: (value) {
                              final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
                              if (value == null || !emailRegex.hasMatch(value.trim())) {
                                return 'Please enter a valid email address';
                              }
                              return null;
                            },
                          ),
                        ],

                        if (_errorMsg != null) ...[
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEF2F2),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFFFCA5A5)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.error_outline, size: 16, color: Color(0xFFDC2626)),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _errorMsg!,
                                    style: const TextStyle(color: Color(0xFFDC2626), fontSize: 12, fontWeight: FontWeight.w600),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 20),

                        PrimaryButton(
                          text: _selectedMode == 0 ? 'Send Log In OTP' : 'Send Verification OTP',
                          onPressed: _submitDetails,
                          isLoading: isBtnLoading,
                        ),
                        const SizedBox(height: 16),

                        // Mode toggle footer link
                        Center(
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                _selectedMode = _selectedMode == 0 ? 1 : 0;
                                _errorMsg = null;
                              });
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Text(
                                _selectedMode == 0 
                                    ? 'New to BookurTechnician? Register here →'
                                    : 'Already registered? Log In with Email →',
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF1E3A8A),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),

                        Center(
                          child: Wrap(
                            alignment: WrapAlignment.center,
                            children: [
                              const Text(
                                'By continuing, you agree to our ',
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
                                    color: Color(0xFF1E3A8A),
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
                                    color: Color(0xFF1E3A8A),
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}
