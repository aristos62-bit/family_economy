import 'dart:math' as math;
import 'package:flutter/material.dart';

/// ============================================================
/// UI TOKENS (Colors + Typography)
/// Single source of truth for design system
/// ============================================================
class ColorsUI {
  // ============================================================
  // PRIMARY COLORS
  // ============================================================
  static const Color primaryLight = Color(0xFF6750A4);
  static const Color primaryDark = Color(0xFFD0BCFF);

  static const Color secondaryLight = Color(0xFF625B71);
  static const Color secondaryDark = Color(0xFFCCC2DC);

  static const Color tertiaryLight = Color(0xFF7D5260);
  static const Color tertiaryDark = Color(0xFFEFB8C8);

  // "On" colors (text/icons displayed on top of the colors above)
  static const Color onPrimaryLight = Colors.white;
  static const Color onSecondaryLight = Colors.white;
  static const Color onTertiaryLight = Colors.white;
  static const Color onErrorLight = Colors.white;

  static const Color onPrimaryDark = Colors.black;
  static const Color onSecondaryDark = Colors.black;
  static const Color onTertiaryDark = Colors.black;
  static const Color onErrorDark = Colors.black;

  // ============================================================
  // SEMANTIC COLORS - Light Mode
  // ============================================================
  static const Color successLight = Color(0xFF2E7D32);
  static const Color warningLight = Color(0xFFED6C02);
  static const Color errorLight = Color(0xFFC62828);
  static const Color infoLight = Color(0xFF0277BD);

  static const Color incomeLight = Color(0xFF2E7D32);
  static const Color expenseLight = Color(0xFFC62828);
  static const Color transferLight = Color(0xFF0277BD);

  // ============================================================
  // SEMANTIC COLORS - Dark Mode
  // ============================================================
  static const Color successDark = Color(0xFF81C784);
  static const Color warningDark = Color(0xFFFFB74D);
  static const Color errorDark = Color(0xFFE57373);
  static const Color infoDark = Color(0xFF64B5F6);

  static const Color incomeDark = Color(0xFF81C784);
  static const Color expenseDark = Color(0xFFE57373);
  static const Color transferDark = Color(0xFF64B5F6);

  // ============================================================
  // BACKGROUND / SURFACE
  // ============================================================
  static const Color backgroundLight = Color(0xFFE1E0E0);
  static const Color backgroundDark = Color(0xFF1C1B1F);

  static const Color surfaceLight = Color(0xFFE8EBFA);
  static const Color surfaceDark = Color(0xFF2B2930);

  static const Color cardLight = Color(0xFFE8EBFA);
  static const Color cardDark = Color(0xFF2B2930);

  // ============================================================
  // TEXT
  // ============================================================
  static const Color textPrimaryLight = Color(0xFF1C1B1F);
  static const Color textPrimaryDark = Color(0xFFE6E1E5);

  static const Color textSecondaryLight = Color(0xFF49454F);
  static const Color textSecondaryDark = Color(0xFFCAC4D0);

  static const Color textTertiaryLight = Color(0xFF79747E);
  static const Color textTertiaryDark = Color(0xFF938F99);

  static const Color textDisabledLight = Color(0xFFBDBDBD);
  static const Color textDisabledDark = Color(0xFF5F5F5F);

  // ============================================================
  // BORDER / DIVIDER
  // ============================================================
  static const Color borderLight = Color(0xFFE0E0E0);
  static const Color borderDark = Color(0xFF3E3E3E);

  static const Color dividerLight = Color(0xFFE0E0E0);
  static const Color dividerDark = Color(0xFF3E3E3E);

  // ============================================================
  // OVERLAYS / SHADOWS
  // ============================================================
  static const Color overlayLight = Color(0x1F000000);
  static const Color overlayDark = Color(0x1FFFFFFF);

  static const Color shadowLight = Color(0x1A000000);
  static const Color shadowDark = Color(0x33000000);

  // ============================================================
  // INPUTS
  // ============================================================
  static const Color inputFillLight = Color(0xFFF5F5F5);
  static const Color inputFillDark = Color(0xFF2B2930);

  static const Color inputBorderLight = Color(0xFFBDBDBD);
  static const Color inputBorderDark = Color(0xFF5F5F5F);

  static const Color inputFocusBorderLight = Color(0xFF6750A4);
  static const Color inputFocusBorderDark = Color(0xFFD0BCFF);

  // ============================================================
  // SPLASH & LOGIN GRADIENTS (kept as original design)
  // ============================================================
  static const List<Color> splashGradient = [
    Color(0xFF42A5F5),
    Color(0xFF1976D2),
    Color(0xFF7B1FA2),
  ];

  static final List<Color> loginGradient = [
    Colors.blue.shade600,
    Colors.blue.shade800,
  ];

  // ============================================================
  // CHART COLORS
  // ============================================================
  static const List<Color> chartColorsLight = [
    Color(0xFF6750A4),
    Color(0xFF2E7D32),
    Color(0xFFED6C02),
    Color(0xFF0277BD),
    Color(0xFFC62828),
    Color(0xFF7D5260),
    Color(0xFF00838F),
    Color(0xFFF57F17),
  ];

  static const List<Color> chartColorsDark = [
    Color(0xFFD0BCFF),
    Color(0xFF81C784),
    Color(0xFFFFB74D),
    Color(0xFF64B5F6),
    Color(0xFFE57373),
    Color(0xFFEFB8C8),
    Color(0xFF4DD0E1),
    Color(0xFFFFF176),
  ];

  // ============================================================
  // HELPERS
  // ============================================================
  static Color byBrightness({
    required Brightness brightness,
    required Color light,
    required Color dark,
  }) =>
      brightness == Brightness.light ? light : dark;

  static Color getPrimary(Brightness b) =>
      byBrightness(brightness: b, light: primaryLight, dark: primaryDark);

  static Color getSecondary(Brightness b) =>
      byBrightness(brightness: b, light: secondaryLight, dark: secondaryDark);

  static Color getTertiary(Brightness b) =>
      byBrightness(brightness: b, light: tertiaryLight, dark: tertiaryDark);

  static Color getOnPrimary(Brightness b) =>
      byBrightness(brightness: b, light: onPrimaryLight, dark: onPrimaryDark);

  static Color getOnSecondary(Brightness b) =>
      byBrightness(brightness: b, light: onSecondaryLight, dark: onSecondaryDark);

  static Color getOnTertiary(Brightness b) =>
      byBrightness(brightness: b, light: onTertiaryLight, dark: onTertiaryDark);

  static Color getOnError(Brightness b) =>
      byBrightness(brightness: b, light: onErrorLight, dark: onErrorDark);

  static Color getBackground(Brightness b) =>
      byBrightness(brightness: b, light: backgroundLight, dark: backgroundDark);

  static Color getSurface(Brightness b) =>
      byBrightness(brightness: b, light: surfaceLight, dark: surfaceDark);

  static Color getCard(Brightness b) =>
      byBrightness(brightness: b, light: cardLight, dark: cardDark);

  static Color getTextPrimary(Brightness b) =>
      byBrightness(brightness: b, light: textPrimaryLight, dark: textPrimaryDark);

  static Color getTextSecondary(Brightness b) =>
      byBrightness(brightness: b, light: textSecondaryLight, dark: textSecondaryDark);

  static Color getDivider(Brightness b) =>
      byBrightness(brightness: b, light: dividerLight, dark: dividerDark);

  static Color getBorder(Brightness b) =>
      byBrightness(brightness: b, light: borderLight, dark: borderDark);

  static Color getInputFill(Brightness b) =>
      byBrightness(brightness: b, light: inputFillLight, dark: inputFillDark);

  static Color getInputBorder(Brightness b) =>
      byBrightness(brightness: b, light: inputBorderLight, dark: inputBorderDark);

  static Color getInputFocusBorder(Brightness b) => byBrightness(
    brightness: b,
    light: inputFocusBorderLight,
    dark: inputFocusBorderDark,
  );

  static Color getIncomeColor(Brightness b) =>
      byBrightness(brightness: b, light: incomeLight, dark: incomeDark);

  static Color getExpenseColor(Brightness b) =>
      byBrightness(brightness: b, light: expenseLight, dark: expenseDark);

  static Color getTransferColor(Brightness b) =>
      byBrightness(brightness: b, light: transferLight, dark: transferDark);

  static Color getSuccess(Brightness b) =>
      byBrightness(brightness: b, light: successLight, dark: successDark);

  static Color getWarning(Brightness b) =>
      byBrightness(brightness: b, light: warningLight, dark: warningDark);

  static Color getError(Brightness b) =>
      byBrightness(brightness: b, light: errorLight, dark: errorDark);

  static Color getInfo(Brightness b) =>
      byBrightness(brightness: b, light: infoLight, dark: infoDark);

  static List<Color> getChartColors(Brightness b) =>
      b == Brightness.light ? chartColorsLight : chartColorsDark;

  static List<Color> getSplashGradient(Brightness _) => splashGradient;
  static List<Color> getLoginGradient(Brightness _) => loginGradient;

  // ============================================================
  // LOGIN TOKENS (theme-aware so they won't break in dark)
  // ============================================================
  static Color loginInputText(Brightness b) => getTextPrimary(b);
  static Color loginInputLabel(Brightness b) => getTextSecondary(b);
  static Color loginInputIcon(Brightness b) => getPrimary(b);
  static Color loginInputFill(Brightness b) => getInputFill(b);

  // ============================================================
  // ACCESSIBILITY HELPERS
  // ============================================================
  static bool hasGoodContrast(Color foreground, Color background) {
    final ratio = _calculateContrastRatio(foreground, background);
    return ratio >= 7.0;
  }

  static double _calculateContrastRatio(Color c1, Color c2) {
    final lum1 = _getRelativeLuminance(c1);
    final lum2 = _getRelativeLuminance(c2);
    final lighter = lum1 > lum2 ? lum1 : lum2;
    final darker = lum1 > lum2 ? lum2 : lum1;
    return (lighter + 0.05) / (darker + 0.05);
  }

  static double _getRelativeLuminance(Color color) {
    final r = _linearize(color.r);
    final g = _linearize(color.g);
    final b = _linearize(color.b);
    return 0.2126 * r + 0.7152 * g + 0.0722 * b;
  }

  static double _linearize(double c) {
    if (c <= 0.03928) return c / 12.92;
    return math.pow((c + 0.055) / 1.055, 2.4).toDouble();
  }

  static Color getAccessibleTextColor(Color background) {
    final luminance = _getRelativeLuminance(background);
    return luminance > 0.5 ? textPrimaryLight : textPrimaryDark;
  }
}

/// ============================================================
/// TYPOGRAPHY
/// ============================================================
class TypographyUI {
  static const String primaryFont = 'Roboto';

  // Display
  static TextStyle displayXlarge(Brightness b) => TextStyle(
    fontFamily: primaryFont,
    fontSize: 70,
    fontWeight: FontWeight.w400,
    letterSpacing: -0.25,
    height: 1.12,
    color: ColorsUI.getTextPrimary(b),
  );

  static TextStyle displayLarge(Brightness b) => TextStyle(
    fontFamily: primaryFont,
    fontSize: 57,
    fontWeight: FontWeight.w400,
    letterSpacing: -0.25,
    height: 1.12,
    color: ColorsUI.getTextPrimary(b),
  );

  static TextStyle displayMedium(Brightness b) => TextStyle(
    fontFamily: primaryFont,
    fontSize: 45,
    fontWeight: FontWeight.w400,
    height: 1.16,
    color: ColorsUI.getTextPrimary(b),
  );

  static TextStyle displaySmall(Brightness b) => TextStyle(
    fontFamily: primaryFont,
    fontSize: 36,
    fontWeight: FontWeight.w400,
    height: 1.22,
    color: ColorsUI.getTextPrimary(b),
  );

  // Headline
  static TextStyle headlineLarge(Brightness b) => TextStyle(
    fontFamily: primaryFont,
    fontSize: 32,
    fontWeight: FontWeight.w600,
    height: 1.25,
    color: ColorsUI.getTextPrimary(b),
  );

  static TextStyle headlineMedium(Brightness b) => TextStyle(
    fontFamily: primaryFont,
    fontSize: 28,
    fontWeight: FontWeight.w600,
    height: 1.29,
    color: ColorsUI.getTextPrimary(b),
  );

  static TextStyle headlineSmall(Brightness b) => TextStyle(
    fontFamily: primaryFont,
    fontSize: 24,
    fontWeight: FontWeight.w600,
    height: 1.33,
    color: ColorsUI.getTextPrimary(b),
  );

  // Title
  static TextStyle titleLarge(Brightness b) => TextStyle(
    fontFamily: primaryFont,
    fontSize: 22,
    fontWeight: FontWeight.w600,
    height: 1.27,
    color: ColorsUI.getTextPrimary(b),
  );

  static TextStyle titleMedium(Brightness b) => TextStyle(
    fontFamily: primaryFont,
    fontSize: 16,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.15,
    height: 1.50,
    color: ColorsUI.getTextPrimary(b),
  );

  static TextStyle titleSmall(Brightness b) => TextStyle(
    fontFamily: primaryFont,
    fontSize: 14,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.1,
    height: 1.43,
    color: ColorsUI.getTextPrimary(b),
  );

  // Labels
  static TextStyle labelLarge(Brightness b) => TextStyle(
    fontFamily: primaryFont,
    fontSize: 14,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.1,
    height: 1.43,
    color: ColorsUI.getTextPrimary(b),
  );

  static TextStyle labelMedium(Brightness b) => TextStyle(
    fontFamily: primaryFont,
    fontSize: 12,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.5,
    height: 1.33,
    color: ColorsUI.getTextPrimary(b),
  );

  static TextStyle labelSmall(Brightness b) => TextStyle(
    fontFamily: primaryFont,
    fontSize: 11,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.5,
    height: 1.45,
    color: ColorsUI.getTextPrimary(b),
  );

  // Body
  static TextStyle bodyLarge(Brightness b) => TextStyle(
    fontFamily: primaryFont,
    fontSize: 16,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.5,
    height: 1.50,
    color: ColorsUI.getTextPrimary(b),
  );

  static TextStyle bodyMedium(Brightness b) => TextStyle(
    fontFamily: primaryFont,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.25,
    height: 1.43,
    color: ColorsUI.getTextPrimary(b),
  );

  static TextStyle bodySmall(Brightness b) => TextStyle(
    fontFamily: primaryFont,
    fontSize: 12,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.4,
    height: 1.33,
    color: ColorsUI.getTextSecondary(b),
  );

  // Specialized
  static TextStyle currencyLarge(Brightness b) => TextStyle(
    fontFamily: primaryFont,
    fontSize: 36,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.5,
    height: 1.22,
    color: ColorsUI.getTextPrimary(b),
    fontFeatures: const [FontFeature.tabularFigures()],
  );

  static TextStyle currencyMedium(Brightness b) => TextStyle(
    fontFamily: primaryFont,
    fontSize: 24,
    fontWeight: FontWeight.w700,
    height: 1.33,
    color: ColorsUI.getTextPrimary(b),
    fontFeatures: const [FontFeature.tabularFigures()],
  );

  static TextStyle currencySmall(Brightness b) => TextStyle(
    fontFamily: primaryFont,
    fontSize: 16,
    fontWeight: FontWeight.w600,
    height: 1.50,
    color: ColorsUI.getTextPrimary(b),
    fontFeatures: const [FontFeature.tabularFigures()],
  );

  static TextStyle error(Brightness b) => TextStyle(
    fontFamily: primaryFont,
    fontSize: 12,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.4,
    height: 1.33,
    color: ColorsUI.getError(b),
  );

  static TextStyle success(Brightness b) => TextStyle(
    fontFamily: primaryFont,
    fontSize: 12,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.4,
    height: 1.33,
    color: ColorsUI.getSuccess(b),
  );

  static TextStyle helperText(Brightness b) => TextStyle(
    fontFamily: primaryFont,
    fontSize: 12,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.4,
    height: 1.33,
    color: ColorsUI.getTextSecondary(b),
  );

  static TextStyle placeholder(Brightness b) => TextStyle(
    fontFamily: primaryFont,
    fontSize: 16,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.5,
    height: 1.50,
    color: ColorsUI.getTextSecondary(b),
  );

  /// IMPORTANT: no fixed color here.
  /// Buttons should take color from the ButtonTheme (scheme.onPrimary etc.)
  static TextStyle buttonBase() => const TextStyle(
    fontFamily: primaryFont,
    fontSize: 14,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.1,
    height: 1.43,
  );

  static TextTheme getTextTheme(Brightness b) {
    return TextTheme(
      displayLarge: displayLarge(b),
      displayMedium: displayMedium(b),
      displaySmall: displaySmall(b),
      headlineLarge: headlineLarge(b),
      headlineMedium: headlineMedium(b),
      headlineSmall: headlineSmall(b),
      titleLarge: titleLarge(b),
      titleMedium: titleMedium(b),
      titleSmall: titleSmall(b),
      bodyLarge: bodyLarge(b),
      bodyMedium: bodyMedium(b),
      bodySmall: bodySmall(b),
      labelLarge: labelLarge(b),
      labelMedium: labelMedium(b),
      labelSmall: labelSmall(b),
    );
  }
}

/// Handy TextStyle helpers
extension TextStyleX on TextStyle {
  TextStyle get bold => copyWith(fontWeight: FontWeight.w700);
  TextStyle get semiBold => copyWith(fontWeight: FontWeight.w600);
  TextStyle get italic => copyWith(fontStyle: FontStyle.italic);
  TextStyle get underline => copyWith(decoration: TextDecoration.underline);
  TextStyle withColor(Color color) => copyWith(color: color);
  TextStyle withScale(double scale) =>
      copyWith(fontSize: (fontSize ?? 14) * scale);
}

/// Handy context access (no need to pass Brightness everywhere)
extension ThemeContextX on BuildContext {
  Brightness get brightness => Theme.of(this).brightness;

  // Colors
  Color get cPrimary => ColorsUI.getPrimary(brightness);
  Color get cOnPrimary => ColorsUI.getOnPrimary(brightness);
  Color get cBg => ColorsUI.getBackground(brightness);
  Color get cSurface => ColorsUI.getSurface(brightness);
  Color get cText => ColorsUI.getTextPrimary(brightness);
  Color get cText2 => ColorsUI.getTextSecondary(brightness);

  // Typography shortcuts
  TextStyle get h1 => TypographyUI.headlineLarge(brightness);
  TextStyle get h2 => TypographyUI.headlineMedium(brightness);
  TextStyle get h3 => TypographyUI.headlineSmall(brightness);

  TextStyle get titleLg => TypographyUI.titleLarge(brightness);
  TextStyle get titleMd => TypographyUI.titleMedium(brightness);

  TextStyle get bodyLg => TypographyUI.bodyLarge(brightness);
  TextStyle get bodyMd => TypographyUI.bodyMedium(brightness);
  TextStyle get bodySm => TypographyUI.bodySmall(brightness);

  TextStyle get moneyLg => TypographyUI.currencyLarge(brightness);
  TextStyle get moneyMd => TypographyUI.currencyMedium(brightness);
  TextStyle get moneySm => TypographyUI.currencySmall(brightness);

  TextStyle get btn => TypographyUI.buttonBase();
}
