import 'package:flutter/material.dart';

// ─── BOOKURTECHNICIAN TECHNICIAN APP — ROYAL BLUE + BLACK COLOR SYSTEM ─────────

class AppColors {
  // Core Brand Colors
  static const Color primary = Color(0xFF2146A8);        // Official Royal Blue (#2146A8)
  static const Color primaryDark = Color(0xFF17357F);    // Deep Royal Blue (#17357F)
  static const Color primaryLight = Color(0xFFEEF3FF);   // Light Blue Tint (#EEF3FF)
  static const Color black = Color(0xFF000000);          // Black (#000000)
  static const Color background = Color(0xFFFFFFFF);     // Clean White Surface (#FFFFFF)
  static const Color card = Color(0xFFFFFFFF);           // White Card (#FFFFFF)
  
  // Text Colors
  static const Color textPrimary = Color(0xFF111827);    // Primary Heading & Dark Text (#111827)
  static const Color textSecondary = Color(0xFF667085);  // Muted Secondary Text (#667085)
  
  // Borders & Accents
  static const Color border = Color(0xFFE4E7EC);         // Subtle Border Outline (#E4E7EC)
  
  // Functional Status Colors (Universal Recognition)
  static const Color success = Color(0xFF16A34A);        // Functional Green (#16A34A)
  static const Color warning = Color(0xFFF59E0B);        // Functional Amber (#F59E0B)
  static const Color error = Color(0xFFDC2626);          // Functional Red (#DC2626)

  // Secondary aliases
  static const Color secondary = primaryLight;
  static const Color onlineGreen = success;
  static const Color offlineGray = textSecondary;
}
