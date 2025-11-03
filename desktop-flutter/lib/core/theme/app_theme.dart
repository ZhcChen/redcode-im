import 'package:flutter/material.dart';

ThemeData buildAppTheme() {
  // 使用与 desktop (Vue) 完全一致的主色 #4ECDC4
  const seed = Color(0xFF4ECDC4);
  final colorScheme = ColorScheme.fromSeed(
    seedColor: seed,
    brightness: Brightness.light,
  );

  return ThemeData(
    colorScheme: colorScheme,
    scaffoldBackgroundColor: const Color(0xFFF5F4F5),
    useMaterial3: true,
    textTheme: _buildTextTheme(ThemeData(brightness: Brightness.light).textTheme),
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
    inputDecorationTheme: const InputDecorationTheme(
      filled: true,
      fillColor: Color(0xFFF3F7F8),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(22)),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(22)),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(22)),
        borderSide: BorderSide(color: Color(0xFF4ECDC4), width: 1),
      ),
      contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
    ),
    checkboxTheme: CheckboxThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      side: const BorderSide(color: Color(0xFFCFD4DD)),
    ),
  );
}

TextTheme _buildTextTheme(TextTheme base) {
  return base.copyWith(
    displaySmall: base.displaySmall?.copyWith(color: const Color(0xFF2C3E50), fontSize: 32, fontWeight: FontWeight.bold),
    headlineSmall: base.headlineSmall?.copyWith(color: const Color(0xFF2C3E50), fontWeight: FontWeight.w600),
    headlineMedium: base.headlineMedium?.copyWith(fontWeight: FontWeight.bold, color: const Color(0xFF2C3E50)),
    titleLarge: base.titleLarge?.copyWith(fontWeight: FontWeight.w600, color: const Color(0xFF2C3E50)),
    titleMedium: base.titleMedium?.copyWith(color: const Color(0xFF333333), fontSize: 16),
    bodyMedium: base.bodyMedium?.copyWith(color: const Color(0xFF707991), fontSize: 14),
    bodySmall: base.bodySmall?.copyWith(color: const Color(0xFF9B9BB0), fontSize: 11),
  );
}
