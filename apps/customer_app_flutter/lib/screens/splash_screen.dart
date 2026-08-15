import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme.dart';
import 'onboarding_screen.dart';
import 'login_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _logoScale;
  late Animation<double> _logoOpacity;
  late Animation<double> _wrenchRotation;
  late Animation<double> _textOpacity;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    // 200–550 ms: Logo scales from 85% to 100% (Interval: 0.167 to 0.458)
    _logoScale = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.167, 0.458, curve: Curves.easeOut),
      ),
    );

    // 200–550 ms: Logo opacity fades from 0% to 100%
    _logoOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.167, 0.458, curve: Curves.easeIn),
      ),
    );

    // 550–800 ms: Wrench rotates subtly into place (-15 degrees to 0 degrees) (Interval: 0.458 to 0.667)
    _wrenchRotation = Tween<double>(begin: -0.26, end: 0.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.458, 0.667, curve: Curves.easeInOut),
      ),
    );

    // 800–1000 ms: Text fades in below the logo (Interval: 0.667 to 0.833)
    _textOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.667, 0.833, curve: Curves.easeIn),
      ),
    );

    // Start splash timeline animation
    _controller.forward();

    // Navigate to next screen after animation completes (at 1200ms)
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _navigateToNextScreen();
      }
    });
  }

  Future<void> _navigateToNextScreen() async {
    final prefs = await SharedPreferences.getInstance();
    final hasSeenOnboarding = prefs.getBool('has_seen_onboarding') ?? false;
    
    if (!mounted) return;

    // Transition with a smooth cross-fade duration of 400ms
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) {
          return hasSeenOnboarding ? const LoginScreen() : const OnboardingScreen();
        },
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: animation,
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // BT Logo Container
                Opacity(
                  opacity: _logoOpacity.value,
                  child: Transform.scale(
                    scale: _logoScale.value,
                    child: Container(
                      width: 96,
                      height: 96,
                      decoration: const BoxDecoration(
                        borderRadius: BorderRadius.all(Radius.circular(24)),
                        boxShadow: [
                          BoxShadow(
                            color: Color(0x26077E9B),
                            blurRadius: 16,
                            offset: Offset(0, 8),
                          ),
                        ],
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: CustomPaint(
                        size: const Size(96, 96),
                        painter: _SplashLogoPainter(
                          wrenchAngle: _wrenchRotation.value,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                // Brand Name below logo
                Opacity(
                  opacity: _textOpacity.value,
                  child: RichText(
                    text: const TextSpan(
                      style: TextStyle(
                        fontSize: 24,
                        fontFamily: 'Inter',
                        letterSpacing: -0.5,
                      ),
                      children: [
                        TextSpan(
                          text: 'bookur',
                          style: TextStyle(
                            color: kTextNavy,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        TextSpan(
                          text: 'technician',
                          style: TextStyle(
                            color: kBrandSecondary,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _SplashLogoPainter extends CustomPainter {
  final double wrenchAngle;
  _SplashLogoPainter({required this.wrenchAngle});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    
    // Draw diagonal background split: top-left is light cyan, bottom-right is dark teal/blue
    final paintLight = Paint()..color = const Color(0xFF19B5D5);
    final paintDark = Paint()..color = const Color(0xFF077E9B);
    
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
      
    // 1. Draw "B" vertical stem and backing
    final pathB = Path()
      ..moveTo(24 * scaleX, 25 * scaleY)
      ..lineTo(32 * scaleX, 25 * scaleY)
      ..lineTo(32 * scaleX, 61 * scaleY)
      ..lineTo(24 * scaleX, 61 * scaleY)
      ..close();
      
    // Top loop of "B"
    final pathBLoop = Path()
      ..moveTo(32 * scaleX, 25 * scaleY)
      ..lineTo(44 * scaleX, 25 * scaleY)
      ..cubicTo(
        52 * scaleX, 25 * scaleY,
        52 * scaleX, 43 * scaleY,
        44 * scaleX, 43 * scaleY,
      )
      ..lineTo(32 * scaleX, 43 * scaleY)
      ..close();
      
    // Hole in top loop of "B"
    final pathBHole = Path()
      ..moveTo(32 * scaleX, 31 * scaleY)
      ..lineTo(40 * scaleX, 31 * scaleY)
      ..cubicTo(
        44 * scaleX, 31 * scaleY,
        44 * scaleX, 37 * scaleY,
        40 * scaleX, 37 * scaleY,
      )
      ..lineTo(32 * scaleX, 37 * scaleY)
      ..close();

    var finalB = Path.combine(PathOperation.union, pathB, pathBLoop);
    finalB = Path.combine(PathOperation.difference, finalB, pathBHole);

    // 2. Draw "T"
    final pathT = Path()
      ..moveTo(51 * scaleX, 43 * scaleY)
      ..lineTo(78 * scaleX, 43 * scaleY)
      ..lineTo(78 * scaleX, 50 * scaleY)
      ..lineTo(68.5 * scaleX, 50 * scaleY)
      ..lineTo(68.5 * scaleX, 76 * scaleY)
      ..lineTo(60.5 * scaleX, 76 * scaleY)
      ..lineTo(60.5 * scaleX, 50 * scaleY)
      ..lineTo(51 * scaleX, 50 * scaleY)
      ..close();

    // 3. Draw Wrench Jaw as the bottom loop of "B" (centered at 46, 59)
    final cx = 46.0 * scaleX;
    final cy = 59.0 * scaleY;
    final outerRadius = 12.0 * scaleX;
    final innerRadius = 6.0 * scaleX;
    
    final wrenchOuter = Path()
      ..addOval(Rect.fromCircle(center: Offset(cx, cy), radius: outerRadius));
      
    final wrenchInner = Path()
      ..addOval(Rect.fromCircle(center: Offset(cx, cy), radius: innerRadius));

    // Wrench cutout slot (rotated by -45 degrees + dynamic wrenchAngle)
    final slotPath = Path();
    final totalAngle = -0.785 + wrenchAngle; 
    final cosA = math.cos(totalAngle);
    final sinA = math.sin(totalAngle);
    
    Offset rotPoint(double x, double y) {
      return Offset(
        cx + (x * cosA - y * sinA) * scaleX,
        cy + (x * sinA + y * cosA) * scaleY,
      );
    }
    
    slotPath.moveTo(rotPoint(0, -4.5).dx, rotPoint(0, -4.5).dy);
    slotPath.lineTo(rotPoint(16, -4.5).dx, rotPoint(16, -4.5).dy);
    slotPath.lineTo(rotPoint(16, 4.5).dx, rotPoint(16, 4.5).dy);
    slotPath.lineTo(rotPoint(0, 4.5).dx, rotPoint(0, 4.5).dy);
    slotPath.close();

    var wrench = Path.combine(PathOperation.difference, wrenchOuter, wrenchInner);
    wrench = Path.combine(PathOperation.difference, wrench, slotPath);

    // Rotate wrench around center (cx, cy)
    if (wrenchAngle != 0.0) {
      final Matrix4 matrix = Matrix4.identity()
        ..multiply(Matrix4.translationValues(cx, cy, 0.0))
        ..rotateZ(wrenchAngle)
        ..multiply(Matrix4.translationValues(-cx, -cy, 0.0));
      wrench = wrench.transform(matrix.storage);
    }

    // Connector from B stem to wrench head
    final connector = Path()
      ..moveTo(32 * scaleX, 43 * scaleY)
      ..lineTo(32 * scaleX, 53 * scaleY)
      ..quadraticBezierTo(32 * scaleX, 59 * scaleY, cx, 59 * scaleY)
      ..lineTo(cx, 47 * scaleY)
      ..quadraticBezierTo(32 * scaleX, 47 * scaleY, 32 * scaleX, 43 * scaleY)
      ..close();

    var logoText = Path.combine(PathOperation.union, finalB, pathT);
    logoText = Path.combine(PathOperation.union, logoText, wrench);
    logoText = Path.combine(PathOperation.union, logoText, connector);
    
    // Draw diagonal long shadow
    final paintShadow = Paint()
      ..color = const Color(0x80055A6F)
      ..style = PaintingStyle.fill;
      
    for (double i = 1.0; i <= 4.0; i += 1.0) {
      canvas.drawPath(logoText.shift(Offset(i * 0.8 * scaleX, i * 0.8 * scaleY)), paintShadow);
    }
    
    canvas.drawPath(logoText, paintWhite);
  }

  @override
  bool shouldRepaint(covariant _SplashLogoPainter oldDelegate) =>
      oldDelegate.wrenchAngle != wrenchAngle;
}
