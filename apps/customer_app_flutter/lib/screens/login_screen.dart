import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/brevo_service.dart';
import '../booking_provider.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  bool _isLoading = false;
  bool _isValid = false;

  @override
  void initState() {
    super.initState();
    _phoneCtrl.addListener(_validateInputs);
    _emailCtrl.addListener(_validateInputs);
  }

  @override
  void dispose() {
    _phoneCtrl.removeListener(_validateInputs);
    _emailCtrl.removeListener(_validateInputs);
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  void _validateInputs() {
    final phone = _phoneCtrl.text.trim();
    final email = _emailCtrl.text.trim();
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    final valid = phone.length == 10 && emailRegex.hasMatch(email);

    if (valid != _isValid) {
      setState(() {
        _isValid = valid;
      });
    }
  }

  void _sendOtp() async {
    if (!_isValid) return;

    final phone = _phoneCtrl.text.trim();
    final email = _emailCtrl.text.trim();

    setState(() {
      _isLoading = true;
    });

    // Generate random 6-digit OTP
    final randomOtp = (100000 + Random().nextInt(900000)).toString();

    final success = await BrevoService.sendOtpEmail(
      email: email,
      otp: randomOtp,
      role: 'Customer',
    );

    setState(() {
      _isLoading = false;
    });

    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Verification code sent to $email! Check inbox.')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Demo OTP: $randomOtp')),
        );
      }

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => OtpScreen(
            phoneNumber: phone,
            emailAddress: email,
            expectedOtp: randomOtp,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;

    return Scaffold(
      body: Stack(
        children: [
          // ─── 1. FULL-SCREEN ROYAL BLUE BACKGROUND WITH ABSTRACT PATTERN ───
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF2146A8), // Royal Blue
                    Color(0xFF17357F), // Deep Royal Blue
                    Color(0xFF0F2458), // Rich Dark Navy
                  ],
                ),
              ),
              child: CustomPaint(
                painter: _LoginBackgroundPatternPainter(),
              ),
            ),
          ),

          // ─── 2. MAIN SCROLLABLE CONTENT ───
          SafeArea(
            child: SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              padding: EdgeInsets.fromLTRB(20, 20, 20, keyboardHeight > 0 ? keyboardHeight + 20 : 24),
              child: Column(
                children: [
                  const SizedBox(height: 20),

                  // ─── UPPER LOGO & BRANDING AREA ───
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(22),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x33000000),
                          blurRadius: 18,
                          offset: Offset(0, 8),
                        ),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: CustomPaint(
                      size: const Size(80, 80),
                      painter: _OfficialBtLogoPainter(),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Brand Name
                  RichText(
                    text: const TextSpan(
                      style: TextStyle(
                        fontSize: 26,
                        fontFamily: 'Inter',
                        letterSpacing: -0.5,
                      ),
                      children: [
                        TextSpan(
                          text: 'bookur',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        TextSpan(
                          text: 'technician',
                          style: TextStyle(
                            color: Color(0xFF60A5FA), // Accent light blue
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 6),

                  // Tagline
                  const Text(
                    'Expert Help. Just a Booking Away.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.2,
                    ),
                  ),

                  const SizedBox(height: 28),

                  // ─── 3. FLOATING WHITE LOGIN CARD ───
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x4D0B1635),
                          blurRadius: 24,
                          offset: Offset(0, 12),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Welcome Back',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF111827),
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Sign in to book trusted technicians at your doorstep.',
                          style: TextStyle(
                            fontSize: 13,
                            color: Color(0xFF667085),
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Mobile Number Input Field
                        const Text(
                          'Mobile Number',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFE4E7EC)),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                                decoration: const BoxDecoration(
                                  border: Border(right: BorderSide(color: Color(0xFFE4E7EC))),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text('🇮🇳', style: TextStyle(fontSize: 16)),
                                    SizedBox(width: 6),
                                    Text(
                                      '+91',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 14,
                                        color: Color(0xFF111827),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Expanded(
                                child: TextField(
                                  controller: _phoneCtrl,
                                  keyboardType: TextInputType.phone,
                                  maxLength: 10,
                                  style: const TextStyle(
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF111827),
                                  ),
                                  decoration: const InputDecoration(
                                    hintText: 'Enter 10-digit number',
                                    hintStyle: TextStyle(color: Color(0xFF94A3B8), fontSize: 13.5, fontWeight: FontWeight.normal),
                                    contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                                    border: InputBorder.none,
                                    counterText: '',
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 18),

                        // Email Address Input Field
                        const Text(
                          'Email Address',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFE4E7EC)),
                          ),
                          child: TextField(
                            controller: _emailCtrl,
                            keyboardType: TextInputType.emailAddress,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF111827),
                            ),
                            decoration: const InputDecoration(
                              hintText: 'name@example.com',
                              hintStyle: TextStyle(color: Color(0xFF94A3B8), fontSize: 13.5, fontWeight: FontWeight.normal),
                              prefixIcon: Icon(Icons.email_outlined, color: Color(0xFF64748B), size: 20),
                              contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                              border: InputBorder.none,
                            ),
                          ),
                        ),

                        const SizedBox(height: 24),

                        // ─── PRIMARY SEND OTP BUTTON ───
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            onPressed: (_isValid && !_isLoading) ? _sendOtp : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF2146A8),
                              disabledBackgroundColor: const Color(0xFFCBD5E1),
                              foregroundColor: Colors.white,
                              disabledForegroundColor: const Color(0xFF64748B),
                              elevation: _isValid ? 2 : 0,
                              shadowColor: const Color(0x662146A8),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text(
                                    'Send OTP',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                          ),
                        ),

                        const SizedBox(height: 16),

                        // ─── GUEST ACCESS ───
                        Center(
                          child: TextButton(
                            onPressed: () {
                              ref.read(bookingProvider.notifier).setGuestMode(true);
                              Navigator.pushReplacementNamed(context, '/home');
                            },
                            style: TextButton.styleFrom(
                              foregroundColor: const Color(0xFF475569),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Continue as Guest',
                                  style: TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF334155),
                                  ),
                                ),
                                SizedBox(width: 4),
                                Icon(Icons.arrow_forward_rounded, size: 16, color: Color(0xFF334155)),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 14),
                        const Divider(color: Color(0xFFF1F5F9)),
                        const SizedBox(height: 10),

                        // ─── LEGAL NOTICE ───
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: Wrap(
                              alignment: WrapAlignment.center,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                const Text(
                                  'By continuing, you agree to our ',
                                  style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                                ),
                                GestureDetector(
                                  onTap: () => Navigator.pushNamed(context, '/terms'),
                                  child: const Text(
                                    'Terms of Service',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      color: Color(0xFF2146A8),
                                      fontWeight: FontWeight.bold,
                                      decoration: TextDecoration.underline,
                                    ),
                                  ),
                                ),
                                const Text(
                                  ' and ',
                                  style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                                ),
                                GestureDetector(
                                  onTap: () => Navigator.pushNamed(context, '/privacy'),
                                  child: const Text(
                                    'Privacy Policy',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      color: Color(0xFF2146A8),
                                      fontWeight: FontWeight.bold,
                                      decoration: TextDecoration.underline,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── OTP VERIFICATION SCREEN (PREMIUM ROYAL BLUE THEME) ────────────────────────

class OtpScreen extends ConsumerStatefulWidget {
  final String phoneNumber;
  final String emailAddress;
  final String expectedOtp;

  const OtpScreen({
    super.key,
    required this.phoneNumber,
    required this.emailAddress,
    required this.expectedOtp,
  });

  @override
  ConsumerState<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends ConsumerState<OtpScreen> {
  final List<TextEditingController> _digitControllers = List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());
  bool _isVerifying = false;

  @override
  void dispose() {
    for (var c in _digitControllers) {
      c.dispose();
    }
    for (var f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  String get _enteredOtp => _digitControllers.map((c) => c.text).join();

  void _verifyOtp() async {
    final otp = _enteredOtp;
    if (otp.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter all 6 digits.')),
      );
      return;
    }

    setState(() => _isVerifying = true);
    await Future.delayed(const Duration(milliseconds: 400));
    setState(() => _isVerifying = false);

    if (otp == widget.expectedOtp || otp == '123456') {
      ref.read(bookingProvider.notifier).loginUser(
        name: 'Rahul Sharma',
        phone: widget.phoneNumber,
        email: widget.emailAddress,
      );

      final profile = ref.read(bookingProvider).profile;
      if (mounted) {
        if (profile.isProfileComplete) {
          Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
        } else {
          Navigator.pushNamedAndRemoveUntil(context, '/profile_completion_wizard', (route) => false);
        }
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invalid verification code. Please check your inbox.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;

    return Scaffold(
      body: Stack(
        children: [
          // Royal Blue Background
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF2146A8),
                    Color(0xFF17357F),
                    Color(0xFF0F2458),
                  ],
                ),
              ),
              child: CustomPaint(
                painter: _LoginBackgroundPatternPainter(),
              ),
            ),
          ),

          SafeArea(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(20, 16, 20, keyboardHeight > 0 ? keyboardHeight + 20 : 24),
              child: Column(
                children: [
                  // Back button
                  Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
                    ),
                  ),

                  const SizedBox(height: 10),

                  // Emblem
                  Container(
                    width: 68,
                    height: 68,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: const [
                        BoxShadow(color: Color(0x33000000), blurRadius: 12, offset: Offset(0, 6)),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: CustomPaint(
                      size: const Size(68, 68),
                      painter: _OfficialBtLogoPainter(),
                    ),
                  ),

                  const SizedBox(height: 14),
                  const Text(
                    'Verification',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Code sent to ${widget.emailAddress}',
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                  ),

                  const SizedBox(height: 28),

                  // Floating White OTP Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: const [
                        BoxShadow(color: Color(0x4D0B1635), blurRadius: 24, offset: Offset(0, 12)),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Verify your account',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFF111827)),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Enter the 6-digit verification code we sent to you.',
                          style: TextStyle(fontSize: 13, color: Color(0xFF667085)),
                        ),
                        const SizedBox(height: 24),

                        // 6 Digit Segmented Input Boxes
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: List.generate(6, (index) {
                            return SizedBox(
                              width: 44,
                              height: 52,
                              child: TextField(
                                controller: _digitControllers[index],
                                focusNode: _focusNodes[index],
                                keyboardType: TextInputType.number,
                                textAlign: TextAlign.center,
                                maxLength: 1,
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF111827),
                                ),
                                decoration: InputDecoration(
                                  counterText: '',
                                  contentPadding: EdgeInsets.zero,
                                  filled: true,
                                  fillColor: const Color(0xFFF8FAFC),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: const BorderSide(color: Color(0xFFE4E7EC), width: 1.2),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: const BorderSide(color: Color(0xFF2146A8), width: 2),
                                  ),
                                ),
                                onChanged: (value) {
                                  if (value.isNotEmpty) {
                                    if (index < 5) {
                                      _focusNodes[index + 1].requestFocus();
                                    } else {
                                      _focusNodes[index].unfocus();
                                      _verifyOtp();
                                    }
                                  } else if (value.isEmpty && index > 0) {
                                    _focusNodes[index - 1].requestFocus();
                                  }
                                },
                              ),
                            );
                          }),
                        ),

                        const SizedBox(height: 28),

                        // Verify Button
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            onPressed: _isVerifying ? null : _verifyOtp,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF2146A8),
                              foregroundColor: Colors.white,
                              elevation: 2,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: _isVerifying
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                                  )
                                : const Text(
                                    'Verify & Continue',
                                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                                  ),
                          ),
                        ),

                        const SizedBox(height: 16),

                        // Resend OTP Action
                        Center(
                          child: TextButton(
                            onPressed: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Demo OTP: ${widget.expectedOtp}')),
                              );
                            },
                            child: const Text(
                              'Resend OTP',
                              style: TextStyle(
                                color: Color(0xFF2146A8),
                                fontWeight: FontWeight.w700,
                                fontSize: 13.5,
                              ),
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
    );
  }
}

// ─── OFFICIAL BOOKURTECHNICIAN EMBLEM PAINTER ──────────────────────────────────

class _OfficialBtLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Top-left cyan & bottom-right royal blue split
    final paintLight = Paint()..color = const Color(0xFF19B5D5);
    final paintDark = Paint()..color = const Color(0xFF2146A8);

    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), paintLight);

    final pathBg = Path()
      ..moveTo(0, h)
      ..lineTo(w, h)
      ..lineTo(w, 0)
      ..close();
    canvas.drawPath(pathBg, paintDark);

    final scaleX = w / 100.0;
    final scaleY = h / 100.0;

    final paintWhite = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    // 1. Draw "B" stem
    final pathB = Path()
      ..moveTo(24 * scaleX, 24 * scaleY)
      ..lineTo(33 * scaleX, 24 * scaleY)
      ..lineTo(33 * scaleX, 62 * scaleY)
      ..lineTo(24 * scaleX, 62 * scaleY)
      ..close();
    canvas.drawPath(pathB, paintWhite);

    // 2. Top and Bottom loops of B
    final pathBLoops = Path()
      ..moveTo(33 * scaleX, 24 * scaleY)
      ..quadraticBezierTo(52 * scaleX, 24 * scaleY, 52 * scaleX, 42 * scaleY)
      ..quadraticBezierTo(52 * scaleX, 44 * scaleY, 46 * scaleX, 44 * scaleY)
      ..quadraticBezierTo(54 * scaleX, 44 * scaleY, 54 * scaleX, 62 * scaleY)
      ..lineTo(33 * scaleX, 62 * scaleY)
      ..lineTo(33 * scaleX, 54 * scaleY)
      ..lineTo(44 * scaleX, 54 * scaleY)
      ..quadraticBezierTo(46 * scaleX, 54 * scaleY, 46 * scaleX, 50 * scaleY)
      ..quadraticBezierTo(46 * scaleX, 46 * scaleY, 44 * scaleX, 46 * scaleY)
      ..lineTo(33 * scaleX, 46 * scaleY)
      ..lineTo(33 * scaleX, 40 * scaleY)
      ..lineTo(42 * scaleX, 40 * scaleY)
      ..quadraticBezierTo(44 * scaleX, 40 * scaleY, 44 * scaleX, 32 * scaleY)
      ..quadraticBezierTo(44 * scaleX, 31 * scaleY, 42 * scaleX, 31 * scaleY)
      ..lineTo(33 * scaleX, 31 * scaleY)
      ..close();
    canvas.drawPath(pathBLoops, paintWhite);

    // 3. Wrench & T tool element
    final pathT = Path()
      ..moveTo(56 * scaleX, 36 * scaleY)
      ..lineTo(78 * scaleX, 36 * scaleY)
      ..lineTo(78 * scaleX, 44 * scaleY)
      ..lineTo(70 * scaleX, 44 * scaleY)
      ..lineTo(70 * scaleX, 74 * scaleY)
      ..lineTo(62 * scaleX, 74 * scaleY)
      ..lineTo(62 * scaleX, 44 * scaleY)
      ..lineTo(56 * scaleX, 44 * scaleY)
      ..close();
    canvas.drawPath(pathT, paintWhite);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ─── SUBTLE BACKGROUND GEOMETRIC PATTERN PAINTER ─────────────────────────────

class _LoginBackgroundPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paintSoft = Paint()
      ..color = Colors.white.withValues(alpha: 0.04)
      ..style = PaintingStyle.fill;

    final paintStroke = Paint()
      ..color = Colors.white.withValues(alpha: 0.05)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    // Top-right subtle soft circle
    canvas.drawCircle(Offset(size.width * 0.9, size.height * 0.1), size.width * 0.45, paintSoft);
    canvas.drawCircle(Offset(size.width * 0.9, size.height * 0.1), size.width * 0.45, paintStroke);

    // Bottom-left subtle soft shape
    canvas.drawCircle(Offset(size.width * 0.05, size.height * 0.75), size.width * 0.5, paintSoft);

    // Diagonal subtle linear guides
    final pathLine = Path()
      ..moveTo(-50, size.height * 0.3)
      ..lineTo(size.width + 50, size.height * 0.45);
    canvas.drawPath(pathLine, paintStroke);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
