import 'package:flutter/material.dart';

import '../constants/app_colors.dart';

class AppTheme {
  const AppTheme._();

  static ThemeData get light {
    final base = ThemeData.light();
    return base.copyWith(
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: base.colorScheme.copyWith(
        primary: AppColors.primary,
        secondary: AppColors.accent,
        background: AppColors.background,
        surface: AppColors.surface,
      ),
      textTheme: _textTheme(base.textTheme),
      appBarTheme: const AppBarTheme(
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: AppColors.textBlack,
        centerTitle: true,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFF3F7F8),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(44),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        ),
      ),
    );
  }

  static TextTheme _textTheme(TextTheme base) {
    return base.copyWith(
      headlineMedium: base.headlineMedium?.copyWith(
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      ),
      titleLarge: base.titleLarge?.copyWith(
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      ),
      bodyLarge: base.bodyLarge?.copyWith(color: AppColors.textSecondary),
      bodyMedium: base.bodyMedium?.copyWith(color: AppColors.textSecondary),
    );
  }
}
