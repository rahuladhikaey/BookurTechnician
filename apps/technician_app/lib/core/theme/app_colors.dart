import 'package:flutter/material.dart';

class AppColors {
  // Official Premium Orange × Warm White × Soft Peach Design System (Phase 1)
  static const Color primaryOrange = Color(0xFFF46B12);  // Primary Orange (#F46B12)
  static const Color darkOrange = Color(0xFFE85B08);     // Dark Orange (#E85B08)
  static const Color softPeach = Color(0xFFFBE4D5);      // Soft Peach (#FBE4D5)
  static const Color warmBackground = Color(0xFFFCF9F6); // Warm Background (#FCF9F6)

  static const Color primary = Color(0xFFF46B12);        // Primary Orange (#F46B12)
  static const Color primaryDark = Color(0xFFE85B08);    // Dark Orange (#E85B08)
  static const Color primaryLight = Color(0xFFFBE4D5);   // Soft Peach (#FBE4D5)
  static const Color accentYellow = Color(0xFFF46B12);   // Mapped to Primary Orange (#F46B12)
  static const Color black = Color(0xFF222222);          // Charcoal Primary Text (#222222)
  static const Color background = Color(0xFFFCF9F6);     // Warm Background (#FCF9F6)
  static const Color surface = Color(0xFFFFFFFF);        // Pure White Card Surface (#FFFFFF)
  static const Color card = Color(0xFFFFFFFF);           // Pure White Card (#FFFFFF)
  static const Color cardSurface = Color(0xFF222222);    // Charcoal Surface (#222222)
  static const Color cardBorder = Color(0xFFEEE8E2);     // Warm Border (#EEE8E2)

  // Brand Accents
  static const Color obsidianBlack = Color(0xFF222222);
  static const Color pureWhite = Color(0xFFFFFFFF);
  static const Color platinumSilver = Color(0xFFEEE8E2);
  static const Color electricGold = Color(0xFFF46B12);   // Primary Orange (#F46B12)
  static const Color electricGoldGlow = Color(0x33F46B12);
  static const Color electricCyan = Color(0xFFF46B12);

  // Text Colors
  static const Color textPrimary = Color(0xFF222222);    // Charcoal Primary Text (#222222)
  static const Color textSecondary = Color(0xFF77716C);  // Warm Secondary Text (#77716C)
  static const Color textMuted = Color(0xFF77716C);      // Warm Secondary Text (#77716C)

  // Borders & Dividers
  static const Color border = Color(0xFFEEE8E2);         // Warm Border (#EEE8E2)
  static const Color borderLight = Color(0xFFFBE4D5);    // Soft Peach Divider (#FBE4D5)

  // Functional Status Colors
  static const Color onlineGreen = Color(0xFF198754);    // Success (#198754)
  static const Color onlineGreenLight = Color(0xFFE8F5E9);
  static const Color offlineRed = Color(0xFFDC3545);     // Error (#DC3545)
  static const Color offlineRedLight = Color(0xFFFDECEC);
  static const Color warningAmber = Color(0xFFE5A126);   // Warning (#E5A126)

  // Aliases for compatibility
  static const Color success = onlineGreen;
  static const Color warning = warningAmber;
  static const Color error = offlineRed;
  static const Color secondary = primaryLight;
  static const Color offlineGray = textSecondary;
}

typedef TechColors = AppColors;
