import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'ui_tokens.dart';

class AppTheme {
  static ThemeData lightTheme = _build(Brightness.light);
  static ThemeData darkTheme = _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;

    final scheme = isDark
        ? ColorScheme.dark(
      primary: ColorsUI.primaryDark,
      onPrimary: ColorsUI.onPrimaryDark,
      secondary: ColorsUI.secondaryDark,
      onSecondary: ColorsUI.onSecondaryDark,
      tertiary: ColorsUI.tertiaryDark,
      onTertiary: ColorsUI.onTertiaryDark,
      error: ColorsUI.errorDark,
      onError: ColorsUI.onErrorDark,
      surface: ColorsUI.surfaceDark,
      onSurface: ColorsUI.textPrimaryDark,
    )
        : ColorScheme.light(
      primary: ColorsUI.primaryLight,
      onPrimary: ColorsUI.onPrimaryLight,
      secondary: ColorsUI.secondaryLight,
      onSecondary: ColorsUI.onSecondaryLight,
      tertiary: ColorsUI.tertiaryLight,
      onTertiary: ColorsUI.onTertiaryLight,
      error: ColorsUI.errorLight,
      onError: ColorsUI.onErrorLight,
      surface: ColorsUI.surfaceLight,
      onSurface: ColorsUI.textPrimaryLight,
    );

    final bg = ColorsUI.getBackground(brightness);
    final textPrimary = ColorsUI.getTextPrimary(brightness);
    final textSecondary = ColorsUI.getTextSecondary(brightness);

    final overlay = isDark
        ? SystemUiOverlayStyle.light
        : SystemUiOverlayStyle.dark;

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,

      scaffoldBackgroundColor: bg,

      textTheme: TypographyUI.getTextTheme(brightness),

      appBarTheme: AppBarTheme(
        backgroundColor: bg,
        foregroundColor: textPrimary,
        elevation: 0,
        centerTitle: true,
        systemOverlayStyle: overlay,
        titleTextStyle: TypographyUI.titleLarge(brightness),
        iconTheme: IconThemeData(color: textPrimary),
      ),

      cardTheme: CardThemeData(
        color: ColorsUI.getCard(brightness),
        elevation: 0,
        shadowColor: isDark ? ColorsUI.shadowDark : ColorsUI.shadowLight,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: ColorsUI.getBorder(brightness),
            width: 1,
          ),
        ),
      ),

      dividerTheme: DividerThemeData(
        color: ColorsUI.getDivider(brightness),
        thickness: 1,
        space: 1,
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: ColorsUI.getInputFill(brightness),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: ColorsUI.getInputBorder(brightness)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: ColorsUI.getInputBorder(brightness)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: ColorsUI.getInputFocusBorder(brightness),
            width: 2,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: scheme.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: scheme.error, width: 2),
        ),
        contentPadding:
        const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        labelStyle: TypographyUI.bodyMedium(brightness),
        hintStyle: TypographyUI.placeholder(brightness),
        helperStyle: TypographyUI.helperText(brightness),
        errorStyle: TypographyUI.error(brightness),
      ),

      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: TypographyUI.buttonBase(),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: scheme.primary,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: TypographyUI.buttonBase(),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: scheme.primary,
          side: BorderSide(color: scheme.primary),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: TypographyUI.buttonBase(),
        ),
      ),

      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: scheme.surface,
        selectedItemColor: scheme.primary,
        unselectedItemColor: textSecondary,
        showSelectedLabels: true,
        showUnselectedLabels: true,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),

      snackBarTheme: SnackBarThemeData(
        backgroundColor: scheme.inverseSurface,
        contentTextStyle: TypographyUI.bodyMedium(
          isDark ? Brightness.light : Brightness.dark,
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surface,
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        titleTextStyle: TypographyUI.headlineSmall(brightness),
        contentTextStyle: TypographyUI.bodyMedium(brightness),
      ),

      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return scheme.primary;
          return null;
        }),
        checkColor: WidgetStatePropertyAll(scheme.onPrimary),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),

      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return scheme.primary;
          return null;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return scheme.primary.withValues(alpha:0.5);
          }
          return null;
        }),
      ),

      listTileTheme: ListTileThemeData(
        iconColor: textPrimary,
        textColor: textPrimary,
      ),

      iconTheme: IconThemeData(color: textPrimary, size: 24),
    );
  }
}
