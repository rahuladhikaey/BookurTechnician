import 'package:flutter/material.dart';

class AppColors {
  // Deep luxury dark canvas
  static const Color obsidianBlack = Color(0xFF0A0E17);
  static const Color cardSurface = Color(0xFF141B29);
  static const Color surfaceLight = Color(0xFF1F293D);
  static const Color surfaceElevated = Color(0xFF26334D);

  // Borders & Dividers
  static const Color borderGlow = Color(0xFF2A364F);
  static const Color borderLight = Color(0xFF3B4866);

  // Vibrant Accents & Highlights
  static const Color electricGold = Color(0xFFFFB800);
  static const Color amberGold = Color(0xFFF59E0B);
  static const Color neonBlue = Color(0xFF38BDF8);
  static const Color royalBlue = Color(0xFF2563EB);
  static const Color emeraldGreen = Color(0xFF10B981);
  static const Color crimsonRed = Color(0xFFEF4444);
  static const Color accentPurple = Color(0xFF8B5CF6);
  static const Color accentCyan = Color(0xFF06B6D4);

  // Text hierarchy
  static const Color pureWhite = Color(0xFFFFFFFF);
  static const Color textPrimary = Color(0xFFF8FAFC);
  static const Color textSecondary = Color(0xFF94A3B8);
  static const Color textMuted = Color(0xFF64748B);

  // Status Aliases
  static const Color success = emeraldGreen;
  static const Color warning = amberGold;
  static const Color error = crimsonRed;
  static const Color info = neonBlue;
}

class AppTheme {
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.obsidianBlack,
      primaryColor: AppColors.electricGold,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.electricGold,
        onPrimary: AppColors.obsidianBlack,
        secondary: AppColors.neonBlue,
        onSecondary: AppColors.obsidianBlack,
        surface: AppColors.cardSurface,
        onSurface: AppColors.textPrimary,
        error: AppColors.crimsonRed,
        onError: Colors.white,
      ),
      cardTheme: CardThemeData(
        color: AppColors.cardSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.borderGlow, width: 1),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.obsidianBlack,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: AppColors.pureWhite,
          fontWeight: FontWeight.w800,
          fontSize: 18,
          letterSpacing: 0.5,
        ),
        iconTheme: IconThemeData(color: AppColors.pureWhite),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.electricGold,
          foregroundColor: AppColors.obsidianBlack,
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 15,
            letterSpacing: 0.5,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          backgroundColor: Colors.transparent,
          foregroundColor: AppColors.electricGold,
          side: const BorderSide(color: AppColors.electricGold, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 15,
            letterSpacing: 0.5,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.cardSurface,
        hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 14),
        labelStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.borderGlow),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.borderGlow),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.electricGold, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.crimsonRed),
        ),
      ),
    );
  }
}
