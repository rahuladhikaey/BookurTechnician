import 'package:flutter/material.dart';

// ============================================================================
// BOOKURTECHNICIAN — ENTERPRISE DESIGN SYSTEM
// Premium Orange (#F46B12) × Warm White (#FCF9F6) × Soft Peach (#FBE4D5)
// ============================================================================

// Primary Design Tokens (Phase 1 Specification)
const Color kPrimaryOrange = Color(0xFFF46B12);      // Primary Orange (#F46B12)
const Color kDarkOrange = Color(0xFFE85B08);         // Dark Orange (#E85B08)
const Color kSoftPeach = Color(0xFFFBE4D5);          // Soft Peach (#FBE4D5)
const Color kWarmBackground = Color(0xFFFCF9F6);     // Warm Background (#FCF9F6)
const Color kWhite = Color(0xFFFFFFFF);              // Pure White (#FFFFFF)
const Color kPrimaryTextColor = Color(0xFF222222);   // Primary Text (#222222)
const Color kSecondaryTextColor = Color(0xFF77716C); // Secondary Text (#77716C)
const Color kBorderWarm = Color(0xFFEEE8E2);         // Border (#EEE8E2)
const Color kSuccessGreen = Color(0xFF198754);       // Success (#198754)
const Color kWarningAmber = Color(0xFFE5A126);       // Warning (#E5A126)
const Color kErrorRed = Color(0xFFDC3545);           // Error (#DC3545)

// Backwards-Compatible Semantic Aliases used across Customer App screens
const Color kRoyalBlue = kPrimaryOrange;             // #F46B12 Primary Orange
const Color kDeepNavy = kPrimaryTextColor;           // #222222 Charcoal Heading/Control
const Color kBrightYellow = kSoftPeach;              // #FBE4D5 Soft Peach Highlight
const Color kLightBlueTint = kWarmBackground;        // #FCF9F6 Warm White Surface
const Color kTextDark = kPrimaryTextColor;           // #222222 Primary Text
const Color kSecondaryText = kSecondaryTextColor;    // #77716C Secondary Text
const Color kBorderColor = kBorderWarm;              // #EEE8E2 Warm Border

const Color kBrandPrimary = kPrimaryOrange;          // #F46B12 Primary Orange
const Color kDeepRoyalBlue = kDarkOrange;            // #E85B08 Dark Orange
const Color kBlack = kPrimaryTextColor;              // #222222 Primary Charcoal
const Color kBackgroundLight = kWarmBackground;      // #FCF9F6 Warm White
const Color kCardBackground = kWhite;                // #FFFFFF Pure White Card
const Color kSurfaceSubtle = kSoftPeach;             // #FBE4D5 Soft Peach Surface
const Color kCharcoalDark = kPrimaryTextColor;       // #222222 Charcoal
const Color kCharcoalMedium = Color(0xFF3D3935);     // Warm Charcoal Medium
const Color kGoldAccent = kPrimaryOrange;            // #F46B12 Orange Accent

const Color kLightBlue = kSoftPeach;
const Color kPrimaryText = kPrimaryTextColor;
const Color kBrandSecondary = kDarkOrange;
const Color kCardWhite = kWhite;
const Color kTextNavy = kPrimaryTextColor;
const Color kTextGray = kSecondaryTextColor;
const Color kGreenSuccess = kSuccessGreen;
const Color kRedError = kErrorRed;

class AppColors {
  static const Color primary = kPrimaryOrange;
  static const Color primaryDark = kDarkOrange;
  static const Color softPeach = kSoftPeach;
  static const Color warmBackground = kWarmBackground;
  static const Color navy = kPrimaryTextColor;
  static const Color accentYellow = kSoftPeach;
  static const Color secondary = kDarkOrange;
  static const Color background = kWarmBackground;
  static const Color surface = kWhite;
  static const Color lightBlueBg = kSoftPeach;
  static const Color text = kPrimaryTextColor;
  static const Color textSecondary = kSecondaryTextColor;
  static const Color border = kBorderWarm;
  static const Color success = kSuccessGreen;
  static const Color warning = kWarningAmber;
  static const Color error = kErrorRed;
}

ThemeData buildAppTheme() {
  return ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: kWarmBackground,
    primaryColor: kPrimaryOrange,
    colorScheme: const ColorScheme.light(
      primary: kPrimaryOrange,
      secondary: kDarkOrange,
      tertiary: kSoftPeach,
      surface: kWhite,
      onPrimary: kWhite,
      onSecondary: kWhite,
      onSurface: kPrimaryTextColor,
      outline: kBorderWarm,
      error: kErrorRed,
    ),
    fontFamily: 'Inter',
    appBarTheme: const AppBarTheme(
      backgroundColor: kWhite,
      foregroundColor: kPrimaryTextColor,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(
        color: kPrimaryTextColor,
        fontWeight: FontWeight.w800,
        fontSize: 18,
        letterSpacing: -0.3,
      ),
      iconTheme: IconThemeData(color: kPrimaryTextColor),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: kWhite,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: kBorderWarm, width: 1),
      ),
      margin: EdgeInsets.zero,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: kPrimaryOrange,
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
        foregroundColor: kPrimaryOrange,
        side: const BorderSide(color: kPrimaryOrange, width: 1.5),
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
      fillColor: kWhite,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: kBorderWarm),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: kBorderWarm),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: kPrimaryOrange, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: kErrorRed, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      hintStyle: const TextStyle(color: kSecondaryTextColor, fontSize: 14),
    ),
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return kPrimaryOrange;
        }
        return Colors.transparent;
      }),
      checkColor: const WidgetStatePropertyAll(kWhite),
      side: const BorderSide(color: kPrimaryOrange, width: 1.5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
    ),
    radioTheme: RadioThemeData(
      fillColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return kPrimaryOrange;
        }
        return kSecondaryTextColor;
      }),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return kWhite;
        }
        return kSecondaryTextColor;
      }),
      trackColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return kPrimaryOrange;
        }
        return kBorderWarm;
      }),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: kWhite,
      selectedItemColor: kPrimaryOrange,
      unselectedItemColor: kSecondaryTextColor,
      selectedLabelStyle: TextStyle(fontWeight: FontWeight.w800, fontSize: 11.5),
      unselectedLabelStyle: TextStyle(fontWeight: FontWeight.w600, fontSize: 11.5),
      type: BottomNavigationBarType.fixed,
      elevation: 8,
    ),
    chipTheme: ChipThemeData(
      backgroundColor: kWhite,
      selectedColor: kSoftPeach,
      disabledColor: kWarmBackground,
      labelStyle: const TextStyle(color: kPrimaryTextColor, fontWeight: FontWeight.w600, fontSize: 12.5),
      secondaryLabelStyle: const TextStyle(color: kDarkOrange, fontWeight: FontWeight.w800, fontSize: 12.5),
      side: const BorderSide(color: kBorderWarm),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    dividerTheme: const DividerThemeData(
      color: kBorderWarm,
      thickness: 1,
      space: 1,
    ),
  );
}

// ============================================================================
// REUSABLE DESIGN COMPONENT LIBRARY (Premium Orange × Warm White × Soft Peach)
// ============================================================================

/// Official Primary Action Button (Primary Orange #F46B12 with Pure White Text)
class BTPrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final IconData? icon;
  final double? height;
  final Widget? trailing;
  final bool useYellowHighlight;

  const BTPrimaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.isLoading = false,
    this.icon,
    this.height = 54,
    this.trailing,
    this.useYellowHighlight = false,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = useYellowHighlight ? kDarkOrange : kPrimaryOrange;
    const fgColor = kWhite;

    return SizedBox(
      height: height,
      width: double.infinity,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: bgColor,
          foregroundColor: fgColor,
          disabledBackgroundColor: kBorderWarm,
          disabledForegroundColor: kSecondaryTextColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          elevation: 0,
        ),
        child: isLoading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(color: fgColor, strokeWidth: 2.5),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 20, color: fgColor),
                    const SizedBox(width: 10),
                  ],
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.2,
                      color: fgColor,
                    ),
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

/// Official Dark Orange CTA Highlight Button (#E85B08 background, #FFFFFF text)
class BTYellowCtaButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final IconData? icon;
  final double? height;

  const BTYellowCtaButton({
    super.key,
    required this.label,
    this.onPressed,
    this.isLoading = false,
    this.icon,
    this.height = 54,
  });

  @override
  Widget build(BuildContext context) {
    return BTPrimaryButton(
      label: label,
      onPressed: onPressed,
      isLoading: isLoading,
      icon: icon,
      height: height,
      useYellowHighlight: true,
    );
  }
}

/// Official Secondary Action Button (White Background, Primary Orange Border & Text)
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
          foregroundColor: kPrimaryOrange,
          side: const BorderSide(color: kPrimaryOrange, width: 1.8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          elevation: 0,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 20, color: kPrimaryOrange),
              const SizedBox(width: 10),
            ],
            Text(
              label,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: kPrimaryOrange),
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

/// Soft Peach & Orange Pill Tag
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
    final bg = customBg ?? (isDark ? kPrimaryOrange : kSoftPeach);
    final fg = customText ?? (isDark ? kWhite : kDarkOrange);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? Colors.transparent : kBorderWarm,
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
      BTStatusBadge(label: text, backgroundColor: const Color(0xFFE8F5E9), textColor: kSuccessGreen);

  factory BTStatusBadge.warning(String text) =>
      BTStatusBadge(label: text, backgroundColor: const Color(0xFFFFF4E0), textColor: kWarningAmber);

  factory BTStatusBadge.info(String text) =>
      BTStatusBadge(label: text, backgroundColor: kSoftPeach, textColor: kDarkOrange);

  factory BTStatusBadge.error(String text) =>
      BTStatusBadge(label: text, backgroundColor: const Color(0xFFFDECEC), textColor: kErrorRed);

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
          fontWeight: FontWeight.w800,
          fontSize: 11,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

/// Loading Skeleton Placeholder
class BTSkeletonBox extends StatelessWidget {
  final double width;
  final double height;
  final double borderRadius;

  const BTSkeletonBox({
    super.key,
    this.width = double.infinity,
    required this.height,
    this.borderRadius = 12,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: kSoftPeach.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: kBorderWarm, width: 0.8),
      ),
    );
  }
}

/// Clean Empty State Component
class BTEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  const BTEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: kSoftPeach,
                shape: BoxShape.circle,
                border: Border.all(color: kBorderWarm),
              ),
              child: Icon(icon, size: 34, color: kPrimaryOrange),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: kPrimaryTextColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13.5,
                color: kSecondaryTextColor,
                height: 1.45,
              ),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 20),
              SizedBox(
                width: 200,
                child: BTPrimaryButton(
                  label: actionLabel!,
                  onPressed: onAction,
                  height: 46,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// API Failure / Network Offline Retry Component
class BTErrorRetryState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  final bool isOffline;

  const BTErrorRetryState({
    super.key,
    required this.message,
    required this.onRetry,
    this.isOffline = false,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: kWhite,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: kBorderWarm),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isOffline ? Icons.wifi_off_rounded : Icons.error_outline_rounded,
                size: 42,
                color: kErrorRed,
              ),
              const SizedBox(height: 12),
              Text(
                isOffline ? 'Connection Unavailable' : 'Something Went Wrong',
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: kPrimaryTextColor,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, color: kSecondaryTextColor),
              ),
              const SizedBox(height: 16),
              BTPrimaryButton(
                label: 'Retry Now',
                icon: Icons.refresh_rounded,
                onPressed: onRetry,
                height: 46,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Warm Minimalist Map Style JSON
const String kUberMapStyleJson = '''
[
  {
    "elementType": "geometry",
    "stylers": [{"color": "#fcf9f6"}]
  },
  {
    "elementType": "labels.icon",
    "stylers": [{"visibility": "off"}]
  },
  {
    "elementType": "labels.text.fill",
    "stylers": [{"color": "#77716c"}]
  },
  {
    "elementType": "labels.text.stroke",
    "stylers": [{"color": "#fcf9f6"}]
  },
  {
    "featureType": "administrative.land_parcel",
    "elementType": "labels.text.fill",
    "stylers": [{"color": "#bdbdbd"}]
  },
  {
    "featureType": "poi",
    "elementType": "geometry",
    "stylers": [{"color": "#f4efe9"}]
  },
  {
    "featureType": "poi",
    "elementType": "labels.text.fill",
    "stylers": [{"color": "#77716c"}]
  },
  {
    "featureType": "road",
    "elementType": "geometry",
    "stylers": [{"color": "#ffffff"}]
  },
  {
    "featureType": "road.arterial",
    "elementType": "labels.text.fill",
    "stylers": [{"color": "#77716c"}]
  },
  {
    "featureType": "road.highway",
    "elementType": "geometry",
    "stylers": [{"color": "#fbe4d5"}]
  },
  {
    "featureType": "road.highway",
    "elementType": "labels.text.fill",
    "stylers": [{"color": "#222222"}]
  },
  {
    "featureType": "transit.line",
    "elementType": "geometry",
    "stylers": [{"color": "#eee8e2"}]
  },
  {
    "featureType": "water",
    "elementType": "geometry",
    "stylers": [{"color": "#e3edf2"}]
  },
  {
    "featureType": "water",
    "elementType": "labels.text.fill",
    "stylers": [{"color": "#77716c"}]
  }
]
''';
