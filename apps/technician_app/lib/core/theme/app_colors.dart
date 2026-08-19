import 'package:flutter/material.dart';

class AppColors {
  // Core Brand Colors - Urban Company Style
  static const Color primary = Color(0xFF1E3A8A);        // Deep Navy Blue (#1E3A8A)
  static const Color primaryDark = Color(0xFF0F2366);    // Rich Royal Dark Blue
  static const Color primaryLight = Color(0xFFEFF6FF);   // Soft Ice Navy Tint (#EFF6FF)
  static const Color black = Color(0xFF0F172A);          // Deep Slate / Midnight Black
  static const Color background = Color(0xFFF8FAFC);     // Light Slate Canvas Background (#F8FAFC)
  static const Color surface = Color(0xFFFFFFFF);        // Crisp White Card Surface
  static const Color card = Color(0xFFFFFFFF);           // Card Surface (#FFFFFF)
  
  // Text Colors
  static const Color textPrimary = Color(0xFF0F172A);    // Crisp Dark Navy Slate
  static const Color textSecondary = Color(0xFF64748B);  // Muted Slate (#64748B)
  static const Color textMuted = Color(0xFF94A3B8);      // Light Muted Grey
  
  // Borders & Dividers
  static const Color border = Color(0xFFE2E8F0);         // Subtle Border Outline (#E2E8F0)
  static const Color borderLight = Color(0xFFF1F5F9);    // Ultra Light Divider
  
  // Functional Status Colors
  static const Color onlineGreen = Color(0xFF10B981);    // Emerald Green (#10B981)
  static const Color onlineGreenLight = Color(0xFFECFDF5); // Light Emerald Tint (#ECFDF5)
  static const Color offlineRed = Color(0xFFEF4444);     // Alert Red (#EF4444)
  static const Color offlineRedLight = Color(0xFFFEF2F2); // Light Red Tint (#FEF2F2)
  static const Color warningAmber = Color(0xFFF59E0B);   // Amber Star/Pending

  // Aliases for compatibility
  static const Color success = onlineGreen;
  static const Color warning = warningAmber;
  static const Color error = offlineRed;
  static const Color secondary = primaryLight;
  static const Color offlineGray = textSecondary;
}

