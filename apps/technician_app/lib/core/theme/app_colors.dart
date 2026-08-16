import 'package:flutter/material.dart';

// ─── BOOKURTECHNICIAN TECHNICIAN APP — STRICT ROYAL BLUE + BLACK COLOR SYSTEM ───

class AppColors {
  // Core Brand Colors
  static const Color primary = Color(0xFF1E40AF);        // Primary Royal Blue (#1E40AF)
  static const Color primaryDark = Color(0xFF1D3FAF);    // Deep Royal Blue (#1D3FAF)
  static const Color primaryLight = Color(0xFFF1F5F9);   // Neutral Light Surface (#F1F5F9)
  static const Color black = Color(0xFF000000);          // Black (#000000)
  static const Color background = Color(0xFFFFFFFF);     // Clean White Surface (#FFFFFF)
  static const Color card = Color(0xFFFFFFFF);           // White Card (#FFFFFF)
  
  // Text Colors
  static const Color textPrimary = Color(0xFF000000);    // Black Text (#000000)
  static const Color textSecondary = Color(0xFF475569);  // Secondary Slate Text (#475569)
  
  // Borders & Accents
  static const Color border = Color(0xFFE2E8F0);         // Subtle Border Outline (#E2E8F0)
  
  // Functional Status Colors (Universal Recognition)
  static const Color success = Color(0xFF16A34A);        // Functional Green (#16A34A)
  static const Color warning = Color(0xFFF59E0B);        // Functional Amber (#F59E0B)
  static const Color error = Color(0xFFDC2626);          // Functional Red (#DC2626)

  // Secondary aliases
  static const Color secondary = primaryLight;
  static const Color onlineGreen = success;
  static const Color offlineGray = textSecondary;
}
