import 'package:flutter/material.dart';

// ============================================================================
// BOOKURTECHNICIAN — ROYAL BLUE + BRIGHT YELLOW + PURE WHITE DESIGN SYSTEM
// Official Uber / Rapido Inspired Home-Services Brand Palette & Components
// ============================================================================

// Primary Brand Colours (Part 1 Specification)
const Color kRoyalBlue = Color(0xFF173B8F);         // Royal Blue (#173B8F)
const Color kDeepNavy = Color(0xFF102A63);          // Deep Navy (#102A63)
const Color kBrightYellow = Color(0xFFFFC928);      // Bright Yellow (#FFC928)
const Color kWhite = Color(0xFFFFFFFF);             // Pure White (#FFFFFF)
const Color kLightBlueTint = Color(0xFFEDF3FF);     // Light Blue Background (#EDF3FF)
const Color kTextDark = Color(0xFF202938);          // Dark Text (#202938)
const Color kSecondaryText = Color(0xFF737D8C);     // Secondary Text (#737D8C)
const Color kSuccessGreen = Color(0xFF18864B);      // Success (#18864B)
const Color kErrorRed = Color(0xFFD64545);          // Error (#D64545)
const Color kBorderColor = Color(0xFFE4E9F1);       // Border (#E4E9F1)
const Color kWarningAmber = Color(0xFFFFC928);      // Bright Yellow Highlight (#FFC928)

// Backwards-Compatible Brand Aliases used across all Customer App screens
const Color kBrandPrimary = kRoyalBlue;             // #173B8F Royal Blue
const Color kDeepRoyalBlue = kDeepNavy;             // #102A63 Deep Navy
const Color kBlack = kDeepNavy;                     // #102A63 Deep Navy for strong headings/controls
const Color kBackgroundLight = kWhite;              // #FFFFFF Pure White
const Color kCardBackground = kWhite;               // #FFFFFF Card Surface
const Color kSurfaceSubtle = kLightBlueTint;        // #EDF3FF Light Blue Surface
const Color kCharcoalDark = kDeepNavy;              // #102A63 Deep Navy Surface
const Color kCharcoalMedium = Color(0xFF1E3F85);    // Medium Royal Blue Divider
const Color kGoldAccent = kBrightYellow;            // #FFC928 Bright Yellow Accent

const Color kLightBlue = kLightBlueTint;
const Color kPrimaryText = kTextDark;
const Color kBrandSecondary = kBrightYellow;
const Color kCardWhite = kWhite;
const Color kTextNavy = kDeepNavy;
const Color kTextGray = kSecondaryText;
const Color kGreenSuccess = kSuccessGreen;
const Color kRedError = kErrorRed;

class AppColors {
  static const Color primary = kRoyalBlue;
  static const Color navy = kDeepNavy;
  static const Color accentYellow = kBrightYellow;
  static const Color secondary = kDeepNavy;
  static const Color background = kWhite;
  static const Color lightBlueBg = kLightBlueTint;
  static const Color text = kTextDark;
  static const Color textSecondary = kSecondaryText;
  static const Color border = kBorderColor;
  static const Color success = kSuccessGreen;
  static const Color error = kErrorRed;
}

ThemeData buildAppTheme() {
  return ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: kWhite,
    primaryColor: kRoyalBlue,
    colorScheme: const ColorScheme.light(
      primary: kRoyalBlue,
      secondary: kBrightYellow,
      tertiary: kDeepNavy,
      surface: kWhite,
      onPrimary: kWhite,
      onSecondary: kDeepNavy,
      onSurface: kTextDark,
      outline: kBorderColor,
      error: kErrorRed,
    ),
    fontFamily: 'Inter',
    appBarTheme: const AppBarTheme(
      backgroundColor: kRoyalBlue,
      foregroundColor: kWhite,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(
        color: kWhite,
        fontWeight: FontWeight.w800,
        fontSize: 18,
        letterSpacing: -0.3,
      ),
      iconTheme: IconThemeData(color: kWhite),
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
        backgroundColor: kRoyalBlue,
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
        foregroundColor: kRoyalBlue,
        side: const BorderSide(color: kRoyalBlue, width: 1.5),
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
      fillColor: kLightBlueTint,
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
        borderSide: const BorderSide(color: kRoyalBlue, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: kErrorRed, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      hintStyle: const TextStyle(color: kSecondaryText, fontSize: 14),
    ),
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return kRoyalBlue;
        }
        return Colors.transparent;
      }),
      checkColor: const WidgetStatePropertyAll(kWhite),
      side: const BorderSide(color: kRoyalBlue, width: 1.5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
    ),
    radioTheme: RadioThemeData(
      fillColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return kRoyalBlue;
        }
        return kSecondaryText;
      }),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return kBrightYellow;
        }
        return kSecondaryText;
      }),
      trackColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return kRoyalBlue;
        }
        return kBorderColor;
      }),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: kDeepNavy,
      selectedItemColor: kBrightYellow,
      unselectedItemColor: Color(0xFFB4C2DC),
      selectedLabelStyle: TextStyle(fontWeight: FontWeight.w800, fontSize: 11.5),
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

// ============================================================================
// PART 5 — REUSABLE DESIGN COMPONENT LIBRARY
// ============================================================================

/// Official Primary Action Button (Royal Blue #173B8F with Pure White Text)
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
    final bgColor = useYellowHighlight ? kBrightYellow : kRoyalBlue;
    final fgColor = useYellowHighlight ? kDeepNavy : kWhite;

    return SizedBox(
      height: height,
      width: double.infinity,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: bgColor,
          foregroundColor: fgColor,
          disabledBackgroundColor: kBorderColor,
          disabledForegroundColor: kSecondaryText,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          elevation: 0,
        ),
        child: isLoading
            ? SizedBox(
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
                    style: TextStyle(
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

/// Official Bright Yellow CTA Highlight Button (#FFC928 background, #102A63 Deep Navy text)
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
          foregroundColor: kRoyalBlue,
          side: const BorderSide(color: kRoyalBlue, width: 1.8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          elevation: 0,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 20, color: kRoyalBlue),
              const SizedBox(width: 10),
            ],
            Text(
              label,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: kRoyalBlue),
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
    final bg = customBg ?? (isDark ? kRoyalBlue : kLightBlueTint);
    final fg = customText ?? (isDark ? kWhite : kDeepNavy);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? Colors.transparent : kBorderColor,
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
      BTStatusBadge(label: text, backgroundColor: const Color(0xFFE6F6EE), textColor: kSuccessGreen);

  factory BTStatusBadge.warning(String text) =>
      BTStatusBadge(label: text, backgroundColor: const Color(0xFFFFF6D6), textColor: kDeepNavy);

  factory BTStatusBadge.info(String text) =>
      BTStatusBadge(label: text, backgroundColor: kLightBlueTint, textColor: kRoyalBlue);

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

/// Loading Skeleton Placeholder (Part 5 & Part 9 — No blank screens)
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
        color: kLightBlueTint,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: kBorderColor, width: 0.8),
      ),
    );
  }
}

/// Clean Empty State Component (Part 5 & Part 9)
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
                color: kLightBlueTint,
                shape: BoxShape.circle,
                border: Border.all(color: kBorderColor),
              ),
              child: Icon(icon, size: 34, color: kRoyalBlue),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: kDeepNavy,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13.5,
                color: kSecondaryText,
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

/// API Failure / Network Offline Retry Component (Part 5 & Part 9)
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
            border: Border.all(color: kBorderColor),
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
                  color: kDeepNavy,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, color: kSecondaryText),
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

/// Minimalist Map Style JSON
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
