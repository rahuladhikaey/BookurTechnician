import 'package:flutter/material.dart';

// ─── BOOKURTECHNICIAN OFFICIAL STRICT ROYAL BLUE + BLACK + WHITE COLOR SYSTEM ───

// Primary Brand Colors
const Color kBrandPrimary = Color(0xFF1E40AF);      // Primary Royal Blue (#1E40AF)
const Color kDeepRoyalBlue = Color(0xFF1D3FAF);     // Deep Royal Blue (#1D3FAF)
const Color kBlack = Color(0xFF000000);             // Pure Black (#000000)
const Color kWhite = Color(0xFFFFFFFF);             // Pure White (#FFFFFF)
const Color kLightBlueTint = Color(0xFFF1F5F9);     // Neutral Surface Highlight (#F1F5F9)
const Color kTextDark = Color(0xFF000000);          // Primary Black Text (#000000)
const Color kSecondaryText = Color(0xFF475569);     // Secondary Text (#475569)
const Color kBorderColor = Color(0xFFE2E8F0);       // Subtle Outline Border (#E2E8F0)
const Color kBackgroundLight = Color(0xFFFFFFFF);   // Pure White Background (#FFFFFF)

// Semantic Status Colors (Retained for Universal Clarity)
const Color kSuccessGreen = Color(0xFF16A34A);      // Success Green
const Color kWarningAmber = Color(0xFFF59E0B);      // Warning Amber
const Color kErrorRed = Color(0xFFDC2626);          // Error Red

// Aliases for Backwards Compatibility
const Color kDeepNavy = kDeepRoyalBlue;
const Color kLightBlue = kLightBlueTint;
const Color kPrimaryText = kTextDark;
const Color kBrandSecondary = kBlack;
const Color kCardWhite = kWhite;
const Color kTextNavy = kBlack;
const Color kTextGray = kSecondaryText;
const Color kGreenSuccess = kSuccessGreen;
const Color kYellowWarning = kWarningAmber;
const Color kRedError = kErrorRed;

ThemeData buildAppTheme() {
  return ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: kWhite,
    colorScheme: const ColorScheme.light(
      primary: kBrandPrimary,
      secondary: kDeepRoyalBlue,
      surface: kWhite,
      onPrimary: kWhite,
      onSecondary: kWhite,
      onSurface: kBlack,
      outline: kBorderColor,
      error: kErrorRed,
    ),
    fontFamily: 'Inter',
    appBarTheme: const AppBarTheme(
      backgroundColor: kWhite,
      foregroundColor: kBlack,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(
        color: kBlack,
        fontWeight: FontWeight.w800,
        fontSize: 17,
        letterSpacing: -0.3,
      ),
      iconTheme: IconThemeData(color: kBrandPrimary),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: kWhite,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: kBorderColor, width: 1),
      ),
      margin: EdgeInsets.zero,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: kBlack,
        foregroundColor: kWhite,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        textStyle: const TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 15,
          letterSpacing: -0.2,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        backgroundColor: kWhite,
        foregroundColor: kBlack,
        side: const BorderSide(color: kBlack, width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        textStyle: const TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 15,
          letterSpacing: -0.2,
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: kBorderColor),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: kBorderColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: kBrandPrimary, width: 1.8),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      hintStyle: const TextStyle(color: kSecondaryText, fontSize: 13.5),
    ),
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return kBrandPrimary;
        }
        return Colors.transparent;
      }),
      checkColor: const WidgetStatePropertyAll(kWhite),
      side: const BorderSide(color: kBorderColor, width: 1.5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
    ),
    radioTheme: RadioThemeData(
      fillColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return kBrandPrimary;
        }
        return kSecondaryText;
      }),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return kWhite;
        }
        return kSecondaryText;
      }),
      trackColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return kBrandPrimary;
        }
        return const Color(0xFFCBD5E1);
      }),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: kBlack,
      selectedItemColor: kWhite,
      unselectedItemColor: Color(0xFF94A3B8),
      selectedLabelStyle: TextStyle(fontWeight: FontWeight.w800, fontSize: 11.5),
      unselectedLabelStyle: TextStyle(fontWeight: FontWeight.w500, fontSize: 11.5),
      type: BottomNavigationBarType.fixed,
      elevation: 8,
    ),
    dividerTheme: const DividerThemeData(
      color: kBorderColor,
      thickness: 1,
      space: 1,
    ),
  );
}

// ─── REUSABLE DESIGN SYSTEM COMPONENTS ──────────────────────────────────────

/// Official Primary Action Button (Royal Blue, White text)
class BTPrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final IconData? icon;
  final double? height;

  const BTPrimaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.isLoading = false,
    this.icon,
    this.height = 50,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: kBlack,
          foregroundColor: kWhite,
          disabledBackgroundColor: const Color(0xFFCBD5E1),
          disabledForegroundColor: const Color(0xFF64748B),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 0,
        ),
        child: isLoading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(color: kWhite, strokeWidth: 2.5),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 18, color: kWhite),
                    const SizedBox(width: 8),
                  ],
                  Text(
                    label,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                  ),
                ],
              ),
      ),
    );
  }
}

/// Official Secondary Action Button (White Background, Royal Blue Border & Text)
class BTSecondaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final double? height;

  const BTSecondaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.height = 50,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          backgroundColor: kWhite,
          foregroundColor: kBlack,
          side: const BorderSide(color: kBlack, width: 1.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 18, color: kBlack),
              const SizedBox(width: 8),
            ],
            Text(
              label,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: kBlack),
            ),
          ],
        ),
      ),
    );
  }
}

/// Official Outlined Action Button alias
class BTOutlinedButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final double? height;

  const BTOutlinedButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.height = 50,
  });

  @override
  Widget build(BuildContext context) {
    return BTSecondaryButton(
      label: label,
      onPressed: onPressed,
      icon: icon,
      height: height,
    );
  }
}

/// Semantic Status Badge Component (Success, Warning, Info, Error)
class BTStatusBadge extends StatelessWidget {
  final String label;
  final Color backgroundColor;
  final Color textColor;

  const BTStatusBadge({
    super.key,
    required this.label,
    required this.backgroundColor,
    required this.textColor,
  });

  factory BTStatusBadge.success(String text) =>
      BTStatusBadge(label: text, backgroundColor: const Color(0xFFDCFCE7), textColor: kSuccessGreen);

  factory BTStatusBadge.warning(String text) =>
      BTStatusBadge(label: text, backgroundColor: const Color(0xFFFEF3C7), textColor: kWarningAmber);

  factory BTStatusBadge.info(String text) =>
      BTStatusBadge(label: text, backgroundColor: const Color(0xFFEFF6FF), textColor: kBrandPrimary);

  factory BTStatusBadge.error(String text) =>
      BTStatusBadge(label: text, backgroundColor: const Color(0xFFFEE2E2), textColor: kErrorRed);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: textColor,
          fontWeight: FontWeight.w800,
          fontSize: 11,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}
