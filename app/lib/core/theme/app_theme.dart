import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import 'design_tokens.dart';

class AppTheme {
  const AppTheme._();

  static ThemeData get light => _build(Brightness.light);

  static ThemeData get dark => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final primary = isDark ? AppColors.darkPrimary : AppColors.primary;
    final primaryContainer = isDark
        ? AppColors.darkPrimarySoft
        : AppColors.primarySoft;
    final background = isDark ? AppColors.darkBackground : AppColors.background;
    final surface = isDark ? AppColors.darkSurface : AppColors.surface;
    final surfaceSoft = isDark
        ? AppColors.darkSurfaceSoft
        : AppColors.surfaceSoft;
    final textPrimary = isDark
        ? AppColors.darkTextPrimary
        : AppColors.textPrimary;
    final textSecondary = isDark
        ? AppColors.darkTextSecondary
        : AppColors.textSecondary;
    final divider = isDark ? AppColors.darkDivider : AppColors.divider;

    final scheme =
        ColorScheme.fromSeed(
          seedColor: primary,
          brightness: brightness,
        ).copyWith(
          primary: primary,
          onPrimary: isDark ? AppColors.darkBackground : Colors.white,
          primaryContainer: primaryContainer,
          onPrimaryContainer: textPrimary,
          secondary: primary,
          onSecondary: Colors.white,
          surface: surface,
          onSurface: textPrimary,
          surfaceContainerHighest: surfaceSoft,
          error: AppColors.danger,
          outlineVariant: divider,
        );
    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: background,
      visualDensity: VisualDensity.standard,
      materialTapTargetSize: MaterialTapTargetSize.padded,
    );

    return base.copyWith(
      textTheme: _textTheme(base.textTheme, textPrimary, textSecondary),
      dividerColor: divider,
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: background,
        foregroundColor: textPrimary,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w600,
          letterSpacing: 0,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceSoft,
        border: _inputBorder,
        enabledBorder: _inputBorder,
        focusedBorder: _inputBorder,
        disabledBorder: _inputBorder,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        hintStyle: TextStyle(color: textSecondary, letterSpacing: 0),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          minimumSize: const Size.square(AppControlSize.minTapTarget),
          tapTargetSize: MaterialTapTargetSize.padded,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, AppControlSize.minTapTarget),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.control),
          ),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            letterSpacing: 0,
          ),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(88, AppControlSize.minTapTarget),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.control),
          ),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.emphasized),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: textPrimary,
        contentTextStyle: TextStyle(color: surface),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.control),
        ),
      ),
    );
  }

  static const _inputBorder = OutlineInputBorder(
    borderRadius: BorderRadius.all(Radius.circular(AppRadii.control)),
    borderSide: BorderSide.none,
  );

  static TextTheme _textTheme(
    TextTheme base,
    Color textPrimary,
    Color textSecondary,
  ) {
    TextStyle? style(
      TextStyle? source,
      double size,
      Color color, {
      FontWeight? weight,
    }) => source?.copyWith(
      fontSize: size,
      color: color,
      fontWeight: weight,
      letterSpacing: 0,
    );

    return base.copyWith(
      displaySmall: style(
        base.displaySmall,
        28,
        textPrimary,
        weight: FontWeight.w600,
      ),
      headlineMedium: style(
        base.headlineMedium,
        22,
        textPrimary,
        weight: FontWeight.w600,
      ),
      titleLarge: style(
        base.titleLarge,
        18,
        textPrimary,
        weight: FontWeight.w600,
      ),
      titleMedium: style(
        base.titleMedium,
        16,
        textPrimary,
        weight: FontWeight.w600,
      ),
      bodyLarge: style(base.bodyLarge, 16, textPrimary),
      bodyMedium: style(base.bodyMedium, 14, textSecondary),
      bodySmall: style(base.bodySmall, 12, textSecondary),
      labelLarge: style(
        base.labelLarge,
        14,
        textPrimary,
        weight: FontWeight.w600,
      ),
    );
  }
}
