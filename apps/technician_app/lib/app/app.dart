import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme/app_theme.dart';
import '../features/auth/presentation/auth_provider.dart';
import '../features/auth/presentation/login_page.dart';
import '../features/dashboard/presentation/main_shell_page.dart';

class TechnicianApp extends ConsumerWidget {
  const TechnicianApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);

    return MaterialApp(
      title: 'BookUrTechnician Pro',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.light,
      home: authState.status == AuthStatus.authenticated
          ? const MainShellPage()
          : const LoginPage(),
      debugShowCheckedModeBanner: false,
    );
  }
}
