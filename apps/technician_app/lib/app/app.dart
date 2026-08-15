import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';
import '../features/auth/presentation/login_page.dart';

class TechnicianApp extends StatelessWidget {
  const TechnicianApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BookUrTechnician Pro',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.light,
      home: const LoginPage(),
      debugShowCheckedModeBanner: false,
    );
  }
}
