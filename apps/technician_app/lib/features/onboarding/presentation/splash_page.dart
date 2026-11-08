import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../auth/presentation/auth_provider.dart';
import '../../auth/presentation/login_page.dart';
import '../../dashboard/presentation/main_shell_page.dart';
import 'onboarding_page.dart';

class SplashPage extends ConsumerStatefulWidget {
  const SplashPage({super.key});

  @override
  ConsumerState<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends ConsumerState<SplashPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<double> _badgeSlideAnimation;
  Timer? _timer;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );

    _scaleAnimation = Tween<double>(begin: 0.82, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOutBack),
      ),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.45, curve: Curves.easeIn),
      ),
    );

    _badgeSlideAnimation = Tween<double>(begin: 20.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.4, 0.85, curve: Curves.easeOutCubic),
      ),
    );

    _controller.forward();

    // Hold for exactly 3 seconds before navigating to the next screen
    _timer = Timer(const Duration(seconds: 3), () {
      if (mounted) {
        _navigateNext();
      }
    });
  }

  Future<void> _navigateNext() async {
    final prefs = await SharedPreferences.getInstance();
    final hasSeenOnboarding = prefs.getBool('has_seen_technician_onboarding') ?? false;
    final authState = ref.read(authProvider);

    // Direct token check from storage to avoid any async initialization delay
    final directToken = await ref.read(authProvider.notifier).getStoredToken();

    if (!mounted) return;

    Widget targetScreen;
    if (authState.status == AuthStatus.authenticated || (directToken != null && directToken.isNotEmpty)) {
      targetScreen = const MainShellPage();
    } else if (!hasSeenOnboarding) {
      targetScreen = const TechnicianOnboardingPage();
    } else {
      targetScreen = const LoginPage();
    }

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => targetScreen,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFCF9F6), // Warm Background (#FCF9F6)
      body: Stack(
        children: [
          // Subtle Warm Peach Radial Accent
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                color: Color(0xFFFCF9F6),
              ),
            ),
          ),

          // Center Logo & Branding
          Center(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return Opacity(
                  opacity: _fadeAnimation.value,
                  child: Transform.scale(
                    scale: _scaleAnimation.value,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // App Logo Container
                        Container(
                          width: 112,
                          height: 112,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white,
                            border: Border.all(
                              color: const Color(0xFFF46B12),
                              width: 3.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFF46B12).withValues(alpha: 0.18),
                                blurRadius: 30,
                                spreadRadius: 2,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          padding: const EdgeInsets.all(12),
                          child: ClipOval(
                            child: Image.asset(
                              'assets/images/app_logo.png',
                              fit: BoxFit.contain,
                              errorBuilder: (context, error, stackTrace) {
                                return const Icon(
                                  Icons.bolt_rounded,
                                  size: 54,
                                  color: Color(0xFFF46B12),
                                );
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 28),

                        // App Brand Title
                        RichText(
                          textAlign: TextAlign.center,
                          text: const TextSpan(
                            style: TextStyle(
                              fontSize: 27,
                              fontWeight: FontWeight.bold,
                              letterSpacing: -0.5,
                              fontFamily: 'Inter',
                            ),
                            children: [
                              TextSpan(
                                text: 'Bookur',
                                style: TextStyle(
                                  color: Color(0xFF222222),
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              TextSpan(
                                text: 'Technician',
                                style: TextStyle(
                                  color: Color(0xFFF46B12), // Primary Orange
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Partner Pro Badge
                        Transform.translate(
                          offset: Offset(0, _badgeSlideAnimation.value),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFBE4D5),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: const Color(0xFFF46B12).withValues(alpha: 0.4),
                                width: 1.2,
                              ),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.verified_rounded,
                                  color: Color(0xFFF46B12),
                                  size: 16,
                                ),
                                SizedBox(width: 6),
                                Text(
                                  'PARTNER PRO',
                                  style: TextStyle(
                                    color: Color(0xFFE85B08),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          // Bottom Loading & Version Info
          const Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Column(
              children: [
                SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Color(0xFFF46B12),
                    ),
                  ),
                ),
                SizedBox(height: 14),
                Text(
                  'Expert Electrical Partner Network',
                  style: TextStyle(
                    color: Color(0xFF77716C),
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
