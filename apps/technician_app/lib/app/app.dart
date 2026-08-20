import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../main.dart';
import '../core/theme/app_theme.dart';
import '../features/auth/presentation/login_page.dart';
import '../features/dashboard/presentation/main_shell_page.dart';
import '../features/onboarding/presentation/splash_page.dart';
import '../features/onboarding/presentation/onboarding_page.dart';

class TechnicianApp extends ConsumerWidget {
  const TechnicianApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: 'BookUrTechnician Pro',
      navigatorKey: rootNavigatorKey,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.light,
      home: const SplashPage(),
      routes: {
        '/splash': (context) => const SplashPage(),
        '/onboarding': (context) => const TechnicianOnboardingPage(),
        '/login': (context) => const LoginPage(),
        '/dashboard': (context) => const MainShellPage(),
      },
      debugShowCheckedModeBanner: false,
    );
  }
}

