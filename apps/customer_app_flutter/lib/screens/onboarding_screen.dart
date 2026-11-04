import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _controller = PageController();
  int _currentPage = 0;
  bool _hasSelectedLanguage = false;
  String _selectedLang = 'en'; // 'en' or 'hi'

  @override
  void initState() {
    super.initState();
    _loadLanguagePreference();
  }

  Future<void> _loadLanguagePreference() async {
    final prefs = await SharedPreferences.getInstance();
    final savedLang = prefs.getString('selected_language');
    if (savedLang != null && savedLang.isNotEmpty) {
      if (mounted) {
        setState(() {
          _selectedLang = savedLang;
        });
      }
    }
  }

  Future<void> _confirmLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('selected_language', _selectedLang);
    if (mounted) {
      setState(() {
        _hasSelectedLanguage = true;
      });
    }
  }

  Future<void> _completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('has_seen_onboarding', true);
    await prefs.setString('selected_language', _selectedLang);
    if (mounted) {
      Navigator.pushReplacementNamed(context, '/login');
    }
  }

  List<_SlideData> get _slides => _selectedLang == 'hi'
      ? [
          const _SlideData(
            title: 'भरोसेमंद विशेषज्ञ खोजें',
            subtitle: 'आपके घर के लिए सत्यापित और अनुभवी तकनीशियन तुरंत उपलब्ध।',
            trustText: 'सत्यापित • कुशल • भरोसेमंद',
            illustration: TechnicianIllustration(),
          ),
          const _SlideData(
            title: 'आसानी से सेवाएं बुक करें',
            subtitle: 'पारदर्शी मूल्य और उपलब्ध समय स्लॉट के साथ मिनटों में सेवा बुक करें।',
            trustText: 'पारदर्शी कीमत • सुरक्षित भुगतान',
            illustration: PaymentsIllustration(),
          ),
          const _SlideData(
            title: 'अपने तकनीशियन को लाइव ट्रैक करें',
            subtitle: 'रीयल-टाइम मैप पर अपने तकनीशियन की लोकेशन और आने का समय देखें।',
            trustText: 'बुकिंग से आगमन तक लाइव अपडेट',
            illustration: TrackingIllustration(),
          ),
        ]
      : [
          const _SlideData(
            title: 'Find Trusted Professionals',
            subtitle: 'Verified and background-checked specialists ready for your home service needs.',
            trustText: 'Skilled • Verified • Trusted',
            illustration: TechnicianIllustration(),
          ),
          const _SlideData(
            title: 'Book Services Easily',
            subtitle: 'Choose real-time available slots with transparent server-validated pricing.',
            trustText: 'Transparent Pricing • Instant Confirmation',
            illustration: PaymentsIllustration(),
          ),
          const _SlideData(
            title: 'Track Your Technician Live',
            subtitle: "Follow your assigned technician's live GPS location and arrival estimate in real time.",
            trustText: 'Stay updated from booking to completion.',
            illustration: TrackingIllustration(),
          ),
        ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _buildLanguageSelectionView() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          Row(
            children: [
              const BrandLogoIcon(size: 38),
              const SizedBox(width: 10),
              RichText(
                text: const TextSpan(
                  style: TextStyle(
                    fontSize: 22,
                    fontFamily: 'Inter',
                    letterSpacing: -0.5,
                  ),
                  children: [
                    TextSpan(
                      text: 'bookur',
                      style: TextStyle(color: kDeepNavy, fontWeight: FontWeight.w900),
                    ),
                    TextSpan(
                      text: 'technician',
                      style: TextStyle(color: kRoyalBlue, fontWeight: FontWeight.w900),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          const Text(
            'Choose Your Language\nअपनी भाषा चुनें',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w900,
              color: kDeepNavy,
              height: 1.25,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Select your preferred language to continue using BookurTechnician.',
            style: TextStyle(fontSize: 14, color: kSecondaryText),
          ),
          const SizedBox(height: 28),
          _buildLanguageCard(
            code: 'en',
            title: 'English',
            subtitle: 'Default Application Language',
            badgeText: 'A',
          ),
          const SizedBox(height: 16),
          _buildLanguageCard(
            code: 'hi',
            title: 'हिन्दी (Hindi)',
            subtitle: 'भारतीय राष्ट्रीय भाषा',
            badgeText: 'अ',
          ),
          const Spacer(),
          BTYellowCtaButton(
            label: _selectedLang == 'hi' ? 'आगे बढ़ें (Continue)' : 'Continue',
            icon: Icons.arrow_forward_rounded,
            onPressed: _confirmLanguage,
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildLanguageCard({
    required String code,
    required String title,
    required String subtitle,
    required String badgeText,
  }) {
    final isSelected = _selectedLang == code;
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => setState(() => _selectedLang = code),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isSelected ? kLightBlueTint : kWhite,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? kRoyalBlue : kBorderColor,
            width: isSelected ? 2.2 : 1.2,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: kRoyalBlue.withValues(alpha: 0.10),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
                ]
              : const [],
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: isSelected ? kRoyalBlue : kLightBlueTint,
                borderRadius: BorderRadius.circular(14),
              ),
              alignment: Alignment.center,
              child: Text(
                badgeText,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: isSelected ? kBrightYellow : kRoyalBlue,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: kDeepNavy,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 13,
                      color: kSecondaryText,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected ? kBrightYellow : Colors.transparent,
                border: Border.all(
                  color: isSelected ? kRoyalBlue : kBorderColor,
                  width: 2,
                ),
              ),
              child: isSelected
                  ? const Icon(Icons.check_rounded, size: 16, color: kDeepNavy)
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final slides = _slides;
    return Scaffold(
      backgroundColor: kWhite,
      body: SafeArea(
        child: !_hasSelectedLanguage
            ? _buildLanguageSelectionView()
            : Column(
                children: [
                  // Brand Logo Header + Language Switch Pill
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const BrandLogoIcon(size: 32),
                            const SizedBox(width: 8),
                            RichText(
                              text: const TextSpan(
                                style: TextStyle(
                                  fontSize: 20,
                                  fontFamily: 'Inter',
                                  letterSpacing: -0.5,
                                ),
                                children: [
                                  TextSpan(
                                    text: 'bookur',
                                    style: TextStyle(
                                      color: kDeepNavy,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  TextSpan(
                                    text: 'technician',
                                    style: TextStyle(
                                      color: kRoyalBlue,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        InkWell(
                          onTap: () => setState(() => _hasSelectedLanguage = false),
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: kLightBlueTint,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: kBorderColor),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.language_rounded, size: 15, color: kRoyalBlue),
                                const SizedBox(width: 4),
                                Text(
                                  _selectedLang == 'hi' ? 'हिन्दी' : 'EN',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    color: kRoyalBlue,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Onboarding content page view
                  Expanded(
                    child: PageView.builder(
                      controller: _controller,
                      onPageChanged: (index) {
                        setState(() {
                          _currentPage = index;
                        });
                      },
                      itemCount: slides.length,
                      itemBuilder: (context, index) {
                        final slide = slides[index];
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Expanded(
                                child: Center(
                                  child: slide.illustration,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                slide.title,
                                style: const TextStyle(
                                  fontSize: 25,
                                  fontWeight: FontWeight.w900,
                                  color: kDeepNavy,
                                  letterSpacing: -0.5,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                slide.subtitle,
                                style: const TextStyle(
                                  fontSize: 15,
                                  color: kSecondaryText,
                                  height: 1.45,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 16),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                decoration: BoxDecoration(
                                  color: kLightBlueTint,
                                  borderRadius: BorderRadius.circular(100),
                                  border: Border.all(color: kBorderColor),
                                ),
                                child: Text(
                                  slide.trustText,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    color: kRoyalBlue,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 28),
                            ],
                          ),
                        );
                      },
                    ),
                  ),

                  // Pagination indicators (Bright Yellow active, Light Blue inactive)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(slides.length, (i) {
                      final isActive = _currentPage == i;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: isActive ? 26 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: isActive ? kBrightYellow : kBorderColor,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 24),

                  // Navigation Buttons Section
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        BTPrimaryButton(
                          label: _currentPage < slides.length - 1
                              ? (_selectedLang == 'hi' ? 'अगला (Next)' : 'Continue')
                              : (_selectedLang == 'hi' ? 'शुरू करें (Get Started)' : 'Get Started'),
                          useYellowHighlight: _currentPage == slides.length - 1,
                          onPressed: () {
                            if (_currentPage < slides.length - 1) {
                              _controller.nextPage(
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeInOut,
                              );
                            } else {
                              _completeOnboarding();
                            }
                          },
                        ),
                        const SizedBox(height: 4),
                        TextButton(
                          onPressed: _completeOnboarding,
                          style: TextButton.styleFrom(
                            foregroundColor: kSecondaryText,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          child: Text(
                            _selectedLang == 'hi' ? 'छोड़ें (Skip)' : 'Skip',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _SlideData {
  final String title;
  final String subtitle;
  final String trustText;
  final Widget illustration;

  const _SlideData({
    required this.title,
    required this.subtitle,
    required this.trustText,
    required this.illustration,
  });
}

// ─── BRAND LOGO WIDGET ────────────────────────────────────────────────────────

class BrandLogoIcon extends StatelessWidget {
  final double size;
  const BrandLogoIcon({super.key, this.size = 36});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: const [
          BoxShadow(
            color: Color(0x1F000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: ClipOval(
        child: Image.asset(
          'assets/images/app_logo.png',
          width: size,
          height: size,
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}


// ─── FLOATING ASSET UTILITY ──────────────────────────────────────────────────

class _FloatingAsset extends StatelessWidget {
  final Widget child;
  final double angle;
  const _FloatingAsset({required this.child, this.angle = 0.0});

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: angle,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: const BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Color(0x0F000000),
              blurRadius: 6,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: child,
      ),
    );
  }
}

// ─── SCREEN 1: TECHNICIAN ILLUSTRATION ────────────────────────────────────────

class TechnicianIllustration extends StatelessWidget {
  const TechnicianIllustration({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 240,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Background soft gradient circle
          Container(
            width: 200,
            height: 200,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const RadialGradient(
                colors: [
                  Color(0x2606B6D4),
                  Color(0x051E40AF),
                  Colors.transparent,
                ],
                stops: [0.4, 0.8, 1.0],
              ),
            ),
          ),
          
          // Floating yellow stars / sparkles
          Positioned(
            left: 40,
            top: 30,
            child: Icon(Icons.star, color: Colors.amber.shade400, size: 24),
          ),
          Positioned(
            right: 50,
            top: 40,
            child: Icon(Icons.star, color: Colors.amber.shade300, size: 16),
          ),
          Positioned(
            left: 60,
            bottom: 40,
            child: Icon(Icons.star, color: Colors.amber.shade400, size: 14),
          ),

          // Floating tool 1 (wrench)
          Positioned(
            left: 20,
            top: 90,
            child: _FloatingAsset(
              angle: -0.2,
              child: const Icon(Icons.build_rounded, color: Color(0xFF1E40AF), size: 24),
            ),
          ),
          
          // Floating tool 2 (screwdriver)
          Positioned(
            right: 25,
            top: 100,
            child: _FloatingAsset(
              angle: 0.3,
              child: const Icon(Icons.construction_rounded, color: Color(0xFF06B6D4), size: 24),
            ),
          ),

          // Centered Technician Figure
          Positioned(
            bottom: 0,
            child: SizedBox(
              width: 160,
              height: 200,
              child: CustomPaint(
                painter: _TechnicianPainter(),
              ),
            ),
          ),

          // Overlapping "Verified" Badge
          Positioned(
            bottom: 10,
            right: 60,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Color(0x1A000000),
                    blurRadius: 8,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: Color(0xFF10B981), // Success green
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.verified_user_rounded,
                  color: Colors.white,
                  size: 18,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TechnicianPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final bodyPaint = Paint()..color = const Color(0xFF0F172A); // Navy/Black shirt
    final skinPaint = Paint()..color = const Color(0xFFE5A67C); // South Asian tone
    final darkPaint = Paint()..color = const Color(0xFF1E1E24); // Hair / beard
    final accentPaint = Paint()..color = const Color(0xFF06B6D4); // Teal collar

    // 1. Draw shoulders & body
    final bodyPath = Path()
      ..moveTo(w * 0.1, h)
      ..lineTo(w * 0.9, h)
      ..lineTo(w * 0.85, h * 0.6)
      ..quadraticBezierTo(w * 0.8, h * 0.5, w * 0.7, h * 0.5)
      ..lineTo(w * 0.3, h * 0.5)
      ..quadraticBezierTo(w * 0.2, h * 0.5, w * 0.15, h * 0.6)
      ..close();
    canvas.drawPath(bodyPath, bodyPaint);

    // 2. Draw collar (Teal accent)
    final collarPath = Path()
      ..moveTo(w * 0.35, h * 0.5)
      ..lineTo(w * 0.5, h * 0.62)
      ..lineTo(w * 0.65, h * 0.5)
      ..lineTo(w * 0.58, h * 0.5)
      ..lineTo(w * 0.5, h * 0.55)
      ..lineTo(w * 0.42, h * 0.5)
      ..close();
    canvas.drawPath(collarPath, accentPaint);

    // 3. Draw neck
    final neckPath = Path()
      ..moveTo(w * 0.42, h * 0.52)
      ..lineTo(w * 0.58, h * 0.52)
      ..lineTo(w * 0.56, h * 0.4)
      ..lineTo(w * 0.44, h * 0.4)
      ..close();
    canvas.drawPath(neckPath, skinPaint);

    // 4. Draw head/face
    final faceRect = Rect.fromLTWH(w * 0.32, h * 0.16, w * 0.36, h * 0.28);
    canvas.drawRRect(RRect.fromRectAndRadius(faceRect, Radius.circular(w * 0.18)), skinPaint);

    // 5. Draw hair and beard
    final hairPath = Path()
      ..moveTo(w * 0.32, h * 0.25)
      ..quadraticBezierTo(w * 0.32, h * 0.15, w * 0.5, h * 0.14)
      ..quadraticBezierTo(w * 0.68, h * 0.15, w * 0.68, h * 0.25)
      ..lineTo(w * 0.68, h * 0.2)
      ..quadraticBezierTo(w * 0.5, h * 0.12, w * 0.32, h * 0.2)
      ..close();
    canvas.drawPath(hairPath, darkPaint);
    
    final hairTopPath = Path()
      ..addArc(Rect.fromLTWH(w * 0.32, h * 0.12, w * 0.36, h * 0.12), -3.14, 3.14);
    canvas.drawPath(hairTopPath, darkPaint);

    final beardPath = Path()
      ..moveTo(w * 0.32, h * 0.3)
      ..lineTo(w * 0.34, h * 0.4)
      ..quadraticBezierTo(w * 0.5, h * 0.48, w * 0.66, h * 0.4)
      ..lineTo(w * 0.68, h * 0.3)
      ..lineTo(w * 0.62, h * 0.35)
      ..quadraticBezierTo(w * 0.5, h * 0.42, w * 0.38, h * 0.35)
      ..close();
    canvas.drawPath(beardPath, darkPaint);

    // Eyes
    final eyePaint = Paint()..color = const Color(0xFF1E1E24);
    canvas.drawCircle(Offset(w * 0.44, h * 0.28), 2.2, eyePaint);
    canvas.drawCircle(Offset(w * 0.56, h * 0.28), 2.2, eyePaint);

    // Eyebrows
    canvas.drawRect(Rect.fromLTWH(w * 0.41, h * 0.25, w * 0.07, h * 0.015), darkPaint);
    canvas.drawRect(Rect.fromLTWH(w * 0.52, h * 0.25, w * 0.07, h * 0.015), darkPaint);

    // Smile
    final smilePaint = Paint()
      ..color = const Color(0xFF8E3B3B)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromLTWH(w * 0.46, h * 0.32, w * 0.08, h * 0.05),
      0.1,
      2.9,
      false,
      smilePaint,
    );

    // 6. Draw crossed arms
    final armsPaint = Paint()..color = const Color(0xFF1E293B);
    final armPath = Path()
      ..moveTo(w * 0.22, h * 0.72)
      ..lineTo(w * 0.78, h * 0.72)
      ..lineTo(w * 0.72, h * 0.88)
      ..lineTo(w * 0.28, h * 0.88)
      ..close();
    canvas.drawPath(armPath, armsPaint);

    // Hands
    final handPath = Path()
      ..addOval(Rect.fromLTWH(w * 0.24, h * 0.72, w * 0.09, h * 0.07))
      ..addOval(Rect.fromLTWH(w * 0.67, h * 0.72, w * 0.09, h * 0.07));
    canvas.drawPath(handPath, skinPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ─── SCREEN 2: TRACKING ILLUSTRATION ─────────────────────────────────────────

class TrackingIllustration extends StatelessWidget {
  const TrackingIllustration({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 240,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Background soft circular gradient
          Container(
            width: 220,
            height: 220,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const RadialGradient(
                colors: [
                  Color(0x1F06B6D4),
                  Color(0x051E40AF),
                  Colors.transparent,
                ],
              ),
            ),
          ),
          
          // Smartphone Frame Mockup
          Container(
            width: 140,
            height: 220,
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A),
              borderRadius: BorderRadius.circular(24),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x26000000),
                  blurRadius: 15,
                  offset: Offset(0, 10),
                ),
              ],
            ),
            padding: const EdgeInsets.all(4),
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(20),
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                children: [
                  // 1. Map roads and green parks
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _MapPainter(),
                    ),
                  ),
                  
                  // 2. Customer Home Pin
                  const Positioned(
                    top: 50,
                    right: 35,
                    child: Icon(
                      Icons.home,
                      color: Color(0xFF1E40AF),
                      size: 28,
                    ),
                  ),

                  // 3. Technician Pin
                  const Positioned(
                    bottom: 70,
                    left: 25,
                    child: Icon(
                      Icons.directions_bike_rounded,
                      color: Color(0xFF06B6D4),
                      size: 26,
                    ),
                  ),

                  // 4. Mini ETA Card at the bottom
                  Positioned(
                    bottom: 8,
                    left: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x1A000000),
                            blurRadius: 4,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 24,
                            height: 24,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Color(0xFFE2E8F0),
                            ),
                            child: const Icon(Icons.person, size: 16, color: Color(0xFF64748B)),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: const [
                                Text(
                                  'Rohit Kumar',
                                  style: TextStyle(
                                    fontSize: 8,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF0F172A),
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  '12 min • 2.4 km',
                                  style: TextStyle(
                                    fontSize: 7,
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.phone, size: 10, color: Color(0xFF10B981)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // Floating Location Badge
          Positioned(
            left: 20,
            top: 40,
            child: _FloatingAsset(
              child: const Icon(Icons.location_on, color: Color(0xFFEF4444), size: 20),
            ),
          ),
          
          // Floating Time ETA Badge
          Positioned(
            right: 15,
            bottom: 60,
            child: _FloatingAsset(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Text('ETA', style: TextStyle(fontSize: 8, color: Colors.grey, fontWeight: FontWeight.bold)),
                  Text('12m', style: TextStyle(fontSize: 11, color: Color(0xFF06B6D4), fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MapPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Green areas (parks)
    final parkPaint = Paint()..color = const Color(0xFFE2F0D9);
    canvas.drawRect(Rect.fromLTWH(0, 0, w * 0.4, h * 0.25), parkPaint);
    canvas.drawRect(Rect.fromLTWH(w * 0.6, h * 0.5, w * 0.4, h * 0.3), parkPaint);

    // Water (soft blue)
    final waterPaint = Paint()
      ..color = const Color(0xFFE0F2FE)
      ..strokeWidth = 10
      ..style = PaintingStyle.stroke;
    final waterPath = Path()
      ..moveTo(0, h * 0.1)
      ..quadraticBezierTo(w * 0.3, h * 0.15, w * 0.5, h * 0.05)
      ..quadraticBezierTo(w * 0.7, -0.05, w, 0);
    canvas.drawPath(waterPath, waterPaint);

    // Roads (white)
    final roadPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 6
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(Offset(0, h * 0.4), Offset(w, h * 0.45), roadPaint);
    canvas.drawLine(Offset(w * 0.5, 0), Offset(w * 0.5, h), roadPaint);
    canvas.drawLine(Offset(w * 0.1, h * 0.8), Offset(w * 0.9, h * 0.6), roadPaint);

    // Dotted route line
    final routePaint = Paint()
      ..color = const Color(0xFF06B6D4)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final routePath = Path()
      ..moveTo(w * 0.22, h * 0.7)
      ..quadraticBezierTo(w * 0.3, h * 0.55, w * 0.5, h * 0.58)
      ..quadraticBezierTo(w * 0.52, h * 0.4, w * 0.7, h * 0.3);

    final pathMetrics = routePath.computeMetrics();
    for (var metric in pathMetrics) {
      double distance = 0.0;
      const dashLength = 4.0;
      const gapLength = 4.0;
      while (distance < metric.length) {
        final extract = metric.extractPath(distance, distance + dashLength);
        canvas.drawPath(extract, routePaint);
        distance += dashLength + gapLength;
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ─── SCREEN 3: PAYMENTS ILLUSTRATION ─────────────────────────────────────────

class PaymentsIllustration extends StatelessWidget {
  const PaymentsIllustration({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 240,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Background soft circle
          Container(
            width: 220,
            height: 220,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const RadialGradient(
                colors: [
                  Color(0x1A1E40AF),
                  Color(0x0506B6D4),
                  Colors.transparent,
                ],
              ),
            ),
          ),
          
          // Smartphone Frame Mockup (slightly tilted)
          Transform.rotate(
            angle: -0.1,
            child: Container(
              width: 130,
              height: 210,
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(24),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x1E000000),
                    blurRadius: 15,
                    offset: Offset(-4, 10),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(4),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                padding: const EdgeInsets.all(12),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(
                        color: Color(0xFFD1FAE5),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check_circle,
                        color: Color(0xFF10B981),
                        size: 28,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Payment\nSuccessful',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Divider(height: 1),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: const [
                        Text('Service ID', style: TextStyle(fontSize: 6, color: Colors.grey)),
                        Text('#BT-9041', style: TextStyle(fontSize: 6, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: const [
                        Text('Paid', style: TextStyle(fontSize: 6, color: Colors.grey)),
                        Text('₹549.00', style: TextStyle(fontSize: 6, fontWeight: FontWeight.bold, color: Color(0xFF1E40AF))),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          
          // Overlapping Credit Card
          Positioned(
            right: 15,
            top: 60,
            child: Transform.rotate(
              angle: 0.15,
              child: Container(
                width: 90,
                height: 56,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x33000000),
                      blurRadius: 8,
                      offset: Offset(2, 4),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          width: 10,
                          height: 8,
                          decoration: BoxDecoration(
                            color: Colors.amber.shade200,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const Text(
                          'VISA',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 8,
                            fontWeight: FontWeight.bold,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                    const Text(
                      '•••• 4567',
                      style: TextStyle(color: Colors.white, fontSize: 8, letterSpacing: 1),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Security Shield
          Positioned(
            left: 10,
            bottom: 50,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Color(0x14000000),
                    blurRadius: 10,
                    offset: Offset(-2, 4),
                  ),
                ],
              ),
              child: CustomPaint(
                size: const Size(36, 42),
                painter: _ShieldPainter(),
              ),
            ),
          ),

          // Gold Rupee Coin
          Positioned(
            right: 40,
            bottom: 30,
            child: _FloatingAsset(
              child: Container(
                width: 24,
                height: 24,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [Color(0xFFFCD34D), Color(0xFFF59E0B)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                child: const Center(
                  child: Text(
                    '₹',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ShieldPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final shieldPaint = Paint()
      ..color = const Color(0xFF1E40AF)
      ..style = PaintingStyle.fill;
    final linePaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final path = Path()
      ..moveTo(w * 0.5, 0)
      ..lineTo(w, h * 0.2)
      ..lineTo(w, h * 0.65)
      ..quadraticBezierTo(w * 0.5, h * 0.95, w * 0.5, h)
      ..quadraticBezierTo(w * 0.5, h * 0.95, 0, h * 0.65)
      ..lineTo(0, h * 0.2)
      ..close();

    canvas.drawPath(path, shieldPaint);

    final checkPath = Path()
      ..moveTo(w * 0.3, h * 0.5)
      ..lineTo(w * 0.45, h * 0.62)
      ..lineTo(w * 0.72, h * 0.35);
    canvas.drawPath(checkPath, linePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
