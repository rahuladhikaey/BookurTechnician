import 'package:flutter/material.dart';

// ─── BOOKURTECHNICIAN ROYAL BLACK & WHITE LUXURY DESIGN SYSTEM ───

// Primary Brand Colors (Royal Black & White Monochrome with Luxe Accents)
const Color kBrandPrimary = Color(0xFF000000);      // Pure Obsidian Black (#000000)
const Color kDeepRoyalBlue = Color(0xFF09090B);     // Deep Charcoal / Onyx (#09090B)
const Color kBlack = Color(0xFF000000);             // Pure Black (#000000)
const Color kWhite = Color(0xFFFFFFFF);             // Pure High-Contrast White (#FFFFFF)
const Color kLightBlueTint = Color(0xFFF4F4F5);     // Luxury Off-White / Zinc-100 (#F4F4F5)
const Color kTextDark = Color(0xFF09090B);          // Primary Black Text (#09090B)
const Color kSecondaryText = Color(0xFF71717A);     // Elegant Slate Text (#71717A)
const Color kBorderColor = Color(0xFFE4E4E7);       // Subtle Platinum Outline Border (#E4E4E7)
const Color kBackgroundLight = Color(0xFFFFFFFF);   // Pure White Background (#FFFFFF)
const Color kCardBackground = Color(0xFFFFFFFF);    // Card Surface
const Color kSurfaceSubtle = Color(0xFFF8F9FA);     // Subtle Background Surface

// Luxury Dark Accents
const Color kCharcoalDark = Color(0xFF18181B);      // Dark Slate Surface (#18181B)
const Color kCharcoalMedium = Color(0xFF27272A);    // Border / Divider for Dark Mode
const Color kGoldAccent = Color(0xFFD4AF37);        // Subtle Royal Gold Accent for Ratings/Badges

// Semantic Status Colors
const Color kSuccessGreen = Color(0xFF10B981);      // Emerald Live Success (#10B981)
const Color kWarningAmber = Color(0xFFF59E0B);      // Amber Warning (#F59E0B)
const Color kErrorRed = Color(0xFFEF4444);          // Red Error (#EF4444)

// Aliases for Backwards Compatibility
const Color kDeepNavy = kDeepRoyalBlue;
const Color kLightBlue = kLightBlueTint;
const Color kPrimaryText = kTextDark;
const Color kBrandSecondary = kBlack;
const Color kCardWhite = kWhite;
const Color kTextNavy = kBlack;
const Color kTextGray = kSecondaryText;
const Color kGreenSuccess = kSuccessGreen;
const Color kRedError = kErrorRed;

class AppColors {
  static const Color primary = kBlack;
  static const Color secondary = kCharcoalDark;
  static const Color background = kWhite;
  static const Color text = kTextDark;
  static const Color success = kSuccessGreen;
  static const Color error = kErrorRed;
}

ThemeData buildAppTheme() {
  return ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: kWhite,
    colorScheme: const ColorScheme.light(
      primary: kBlack,
      secondary: kCharcoalDark,
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
        fontWeight: FontWeight.w900,
        fontSize: 18,
        letterSpacing: -0.5,
      ),
      iconTheme: IconThemeData(color: kBlack),
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        textStyle: const TextStyle(
          fontWeight: FontWeight.w800,
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        textStyle: const TextStyle(
          fontWeight: FontWeight.w800,
          fontSize: 15,
          letterSpacing: -0.2,
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFFF8F9FA),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: kBorderColor),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: kBorderColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: kBlack, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      hintStyle: const TextStyle(color: kSecondaryText, fontSize: 14),
    ),
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return kBlack;
        }
        return Colors.transparent;
      }),
      checkColor: const WidgetStatePropertyAll(kWhite),
      side: const BorderSide(color: kBlack, width: 1.5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
    ),
    radioTheme: RadioThemeData(
      fillColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return kBlack;
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
          return kBlack;
        }
        return const Color(0xFFCBD5E1);
      }),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: kBlack,
      selectedItemColor: kWhite,
      unselectedItemColor: Color(0xFF71717A),
      selectedLabelStyle: TextStyle(fontWeight: FontWeight.w900, fontSize: 11.5),
      unselectedLabelStyle: TextStyle(fontWeight: FontWeight.w600, fontSize: 11.5),
      type: BottomNavigationBarType.fixed,
      elevation: 12,
    ),
    dividerTheme: const DividerThemeData(
      color: kBorderColor,
      thickness: 1,
      space: 1,
    ),
  );
}

// ─── REUSABLE ROYAL BLACK & WHITE DESIGN SYSTEM COMPONENTS ──────────────────

/// Official Primary Action Button (Pure Black, White text, high contrast)
class BTPrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final IconData? icon;
  final double? height;
  final Widget? trailing;

  const BTPrimaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.isLoading = false,
    this.icon,
    this.height = 54,
    this.trailing,
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
          disabledBackgroundColor: const Color(0xFFE4E4E7),
          disabledForegroundColor: const Color(0xFFA1A1AA),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
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
                    Icon(icon, size: 20, color: kWhite),
                    const SizedBox(width: 10),
                  ],
                  Text(
                    label,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: -0.2),
                  ),
                  if (trailing != null) ...[
                    const Spacer(),
                    trailing!,
                  ],
                ],
              ),
      ),
    );
  }
}

/// Official Secondary Action Button (White Background, Black Border & Text)
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
    this.height = 54,
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
          side: const BorderSide(color: kBlack, width: 1.8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          elevation: 0,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 20, color: kBlack),
              const SizedBox(width: 10),
            ],
            Text(
              label,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: kBlack),
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
    this.height = 54,
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

/// High-contrast Uber/Rapido-style Pill Tag
class UBPillTag extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool isDark;
  final Color? customBg;
  final Color? customText;

  const UBPillTag({
    super.key,
    required this.label,
    this.icon,
    this.isDark = true,
    this.customBg,
    this.customText,
  });

  @override
  Widget build(BuildContext context) {
    final bg = customBg ?? (isDark ? kBlack : const Color(0xFFF4F4F5));
    final fg = customText ?? (isDark ? kWhite : kBlack);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? Colors.transparent : const Color(0xFFE4E4E7),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: fg),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              color: fg,
              fontWeight: FontWeight.w800,
              fontSize: 11.5,
              letterSpacing: 0.1,
            ),
          ),
        ],
      ),
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
      BTStatusBadge(label: text, backgroundColor: const Color(0xFFDCFCE7), textColor: const Color(0xFF15803D));

  factory BTStatusBadge.warning(String text) =>
      BTStatusBadge(label: text, backgroundColor: const Color(0xFFFEF3C7), textColor: const Color(0xFFB45309));

  factory BTStatusBadge.info(String text) =>
      BTStatusBadge(label: text, backgroundColor: const Color(0xFFF4F4F5), textColor: kBlack);

  factory BTStatusBadge.error(String text) =>
      BTStatusBadge(label: text, backgroundColor: const Color(0xFFFEE2E2), textColor: const Color(0xFFB91C1C));

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: textColor,
          fontWeight: FontWeight.w900,
          fontSize: 11,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

/// Minimalist Uber Silver/Dark Map Style JSON
const String kUberMapStyleJson = '''
[
  {
    "elementType": "geometry",
    "stylers": [{"color": "#f5f5f5"}]
  },
  {
    "elementType": "labels.icon",
    "stylers": [{"visibility": "off"}]
  },
  {
    "elementType": "labels.text.fill",
    "stylers": [{"color": "#616161"}]
  },
  {
    "elementType": "labels.text.stroke",
    "stylers": [{"color": "#f5f5f5"}]
  },
  {
    "featureType": "administrative.land_parcel",
    "elementType": "labels.text.fill",
    "stylers": [{"color": "#bdbdbd"}]
  },
  {
    "featureType": "poi",
    "elementType": "geometry",
    "stylers": [{"color": "#eeeeee"}]
  },
  {
    "featureType": "poi",
    "elementType": "labels.text.fill",
    "stylers": [{"color": "#757575"}]
  },
  {
    "featureType": "road",
    "elementType": "geometry",
    "stylers": [{"color": "#ffffff"}]
  },
  {
    "featureType": "road.arterial",
    "elementType": "labels.text.fill",
    "stylers": [{"color": "#757575"}]
  },
  {
    "featureType": "road.highway",
    "elementType": "geometry",
    "stylers": [{"color": "#dadada"}]
  },
  {
    "featureType": "road.highway",
    "elementType": "labels.text.fill",
    "stylers": [{"color": "#616161"}]
  },
  {
    "featureType": "transit.line",
    "elementType": "geometry",
    "stylers": [{"color": "#e5e5e5"}]
  },
  {
    "featureType": "water",
    "elementType": "geometry",
    "stylers": [{"color": "#c9c9c9"}]
  },
  {
    "featureType": "water",
    "elementType": "labels.text.fill",
    "stylers": [{"color": "#9e9e9e"}]
  }
]
''';
