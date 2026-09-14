import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/theme/app_colors.dart';
import '../../auth/presentation/login_page.dart';

class TechnicianOnboardingPage extends StatefulWidget {
  const TechnicianOnboardingPage({super.key});

  @override
  State<TechnicianOnboardingPage> createState() => _TechnicianOnboardingPageState();
}

class _TechnicianOnboardingPageState extends State<TechnicianOnboardingPage> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<_OnboardingItem> _slides = const [
    _OnboardingItem(
      title: 'Get Real-Time Service Leads',
      subtitle:
          'Connect instantly with thousands of verified local customers needing expert appliance, electrical & plumbing repairs.',
      badgeText: 'Instant Job Alerts',
      icon: Icons.notifications_active_rounded,
      iconColor: Color(0xFF38BDF8),
      bgGradient: [Color(0xFF0F172A), Color(0xFF1E293B)],
    ),
    _OnboardingItem(
      title: 'Live GPS & Smart Navigation',
      subtitle:
          'Turn-by-turn map directions directly to customer doorsteps with live ETA calculations and arrival updates.',
      badgeText: 'Turn-by-Turn GPS',
      icon: Icons.navigation_rounded,
      iconColor: Color(0xFF10B981),
      bgGradient: [Color(0xFF064E3B), Color(0xFF0F172A)],
    ),
    _OnboardingItem(
      title: 'Instant Payouts & 5-Star Growth',
      subtitle:
          'Track your earnings in real-time, get customer ratings, and receive seamless automated direct payouts.',
      badgeText: 'Secure Earnings & Wallet',
      icon: Icons.account_balance_wallet_rounded,
      iconColor: Color(0xFFF59E0B),
      bgGradient: [Color(0xFF312E81), Color(0xFF0F172A)],
    ),
  ];

  Future<void> _completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('has_seen_technician_onboarding', true);

    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => const LoginPage(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 350),
      ),
    );
  }

  void _onNextPressed() {
    if (_currentPage < _slides.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    } else {
      _completeOnboarding();
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Top Bar: Logo & Skip Button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFF1E3A8A).withValues(alpha: 0.1),
                        ),
                        padding: const EdgeInsets.all(6),
                        child: Image.asset(
                          'assets/images/app_logo.png',
                          errorBuilder: (context, error, stackTrace) =>
                              const Icon(Icons.build_rounded,
                                  color: Color(0xFF1E3A8A), size: 20),
                        ),
                      ),
                      const SizedBox(width: 8),
                      RichText(
                        text: const TextSpan(
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Inter',
                          ),
                          children: [
                            TextSpan(
                              text: 'bookur',
                              style: TextStyle(color: Color(0xFF0F172A)),
                            ),
                            TextSpan(
                              text: 'technician',
                              style: TextStyle(color: Color(0xFF1E3A8A)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  TextButton(
                    onPressed: _completeOnboarding,
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.textSecondary,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    ),
                    child: const Text(
                      'Skip',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Middle Carousel Slides
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _slides.length,
                onPageChanged: (index) {
                  setState(() {
                    _currentPage = index;
                  });
                },
                itemBuilder: (context, index) {
                  final slide = _slides[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Slide Hero Graphic Card
                        Container(
                          width: double.infinity,
                          height: 270,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: slide.bgGradient,
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(28),
                            boxShadow: [
                              BoxShadow(
                                color: slide.iconColor.withValues(alpha: 0.25),
                                blurRadius: 30,
                                offset: const Offset(0, 14),
                              ),
                            ],
                          ),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              // Decorative concentric circles
                              Container(
                                width: 190,
                                height: 190,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white.withValues(alpha: 0.05),
                                ),
                              ),
                              Container(
                                width: 140,
                                height: 140,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white.withValues(alpha: 0.08),
                                ),
                              ),
                              // Icon Orb
                              Container(
                                width: 96,
                                height: 96,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: slide.iconColor.withValues(alpha: 0.2),
                                  border: Border.all(
                                    color: slide.iconColor.withValues(alpha: 0.7),
                                    width: 2,
                                  ),
                                ),
                                child: Icon(
                                  slide.icon,
                                  size: 48,
                                  color: slide.iconColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 32),

                        // Slide Badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                          decoration: BoxDecoration(
                            color: slide.iconColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            slide.badgeText.toUpperCase(),
                            style: TextStyle(
                              color: slide.iconColor,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.0,
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Title
                        Text(
                          slide.title,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                            height: 1.25,
                          ),
                        ),
                        const SizedBox(height: 10),

                        // Subtitle
                        Text(
                          slide.subtitle,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 14,
                            color: AppColors.textSecondary,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),

            // Bottom Navigation & Actions
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Column(
                children: [
                  // Smooth Dots Indicator
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      _slides.length,
                      (index) => AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        height: 7,
                        width: _currentPage == index ? 24 : 7,
                        decoration: BoxDecoration(
                          color: _currentPage == index
                              ? const Color(0xFF1E3A8A)
                              : const Color(0xFFCBD5E1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Next / Get Started Button
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _onNextPressed,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1E3A8A),
                        foregroundColor: Colors.white,
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            _currentPage == _slides.length - 1
                                ? 'Get Started as Partner'
                                : 'Next',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            _currentPage == _slides.length - 1
                                ? Icons.arrow_forward_rounded
                                : Icons.chevron_right_rounded,
                            size: 20,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Quick Login shortcut if on slide 1 or 2
                  if (_currentPage < _slides.length - 1)
                    GestureDetector(
                      onTap: _completeOnboarding,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: RichText(
                          text: const TextSpan(
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                              fontFamily: 'Inter',
                            ),
                            children: [
                              TextSpan(text: 'Already registered? '),
                              TextSpan(
                                text: 'Log In',
                                style: TextStyle(
                                  color: Color(0xFF1E3A8A),
                                  fontWeight: FontWeight.bold,
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
          ],
        ),
      ),
    );
  }
}

class _OnboardingItem {
  final String title;
  final String subtitle;
  final String badgeText;
  final IconData icon;
  final Color iconColor;
  final List<Color> bgGradient;

  const _OnboardingItem({
    required this.title,
    required this.subtitle,
    required this.badgeText,
    required this.icon,
    required this.iconColor,
    required this.bgGradient,
  });
}
