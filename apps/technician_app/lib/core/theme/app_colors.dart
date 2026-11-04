import 'package:flutter/material.dart';

class AppColors {
  // Official Royal Blue + Bright Yellow + Pure White Brand Design System (Part 1)
  static const Color primary = Color(0xFF173B8F);        // Royal Blue (#173B8F)
  static const Color primaryDark = Color(0xFF102A63);    // Deep Navy (#102A63)
  static const Color primaryLight = Color(0xFFEDF3FF);   // Light Blue Background (#EDF3FF)
  static const Color accentYellow = Color(0xFFFFC928);   // Bright Yellow (#FFC928)
  static const Color black = Color(0xFF102A63);          // Deep Navy (#102A63)
  static const Color background = Color(0xFFEDF3FF);     // Light Blue Canvas Background (#EDF3FF)
  static const Color surface = Color(0xFFFFFFFF);        // Pure White Card Surface (#FFFFFF)
  static const Color card = Color(0xFFFFFFFF);           // Pure White Card (#FFFFFF)
  static const Color cardSurface = Color(0xFF102A63);    // Deep Navy Surface (#102A63)
  static const Color cardBorder = Color(0xFFE4E9F1);     // Border (#E4E9F1)

  // Brand Accents
  static const Color obsidianBlack = Color(0xFF102A63);
  static const Color pureWhite = Color(0xFFFFFFFF);
  static const Color platinumSilver = Color(0xFFE4E9F1);
  static const Color electricGold = Color(0xFFFFC928);   // Bright Yellow (#FFC928)
  static const Color electricGoldGlow = Color(0x33FFC928);
  static const Color electricCyan = Color(0xFF173B8F);

  // Text Colors
  static const Color textPrimary = Color(0xFF202938);    // Dark Text (#202938)
  static const Color textSecondary = Color(0xFF737D8C);  // Secondary Text (#737D8C)
  static const Color textMuted = Color(0xFF8C96A6);      // Muted Slate Grey

  // Borders & Dividers
  static const Color border = Color(0xFFE4E9F1);         // Border (#E4E9F1)
  static const Color borderLight = Color(0xFFEDF3FF);    // Light Blue Divider (#EDF3FF)

  // Functional Status Colors
  static const Color onlineGreen = Color(0xFF18864B);    // Success (#18864B)
  static const Color onlineGreenLight = Color(0xFFE6F6EE);
  static const Color offlineRed = Color(0xFFD64545);     // Error (#D64545)
  static const Color offlineRedLight = Color(0xFFFDECEC);
  static const Color warningAmber = Color(0xFFFFC928);   // Bright Yellow (#FFC928)

  // Aliases for compatibility
  static const Color success = onlineGreen;
  static const Color warning = warningAmber;
  static const Color error = offlineRed;
  static const Color secondary = primaryLight;
  static const Color offlineGray = textSecondary;
}

typedef TechColors = AppColors;
