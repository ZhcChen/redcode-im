import 'package:flutter/material.dart';

ThemeData buildAppTheme() {
  const seed = Color(0xFF00C2B3);
  final colorScheme = ColorScheme.fromSeed(
    seedColor: seed,
    brightness: Brightness.light,
  );

  return ThemeData(
    colorScheme: colorScheme,
    scaffoldBackgroundColor: const Color(0xFFF8F9FA),
    useMaterial3: true,
    textTheme: _buildTextTheme(ThemeData(brightness: Brightness.light).textTheme),
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
    inputDecorationTheme: const InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
        borderSide: BorderSide(color: Color(0xFFE0E0E0)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
        borderSide: BorderSide(color: Color(0xFFE0E0E0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
        borderSide: BorderSide(color: Color(0xFF00C2B3)),
      ),
      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
    checkboxTheme: CheckboxThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      side: const BorderSide(color: Color(0xFFCFD4DD)),
    ),
  );
}

TextTheme _buildTextTheme(TextTheme base) {
  return base.copyWith(
    displaySmall: base.displaySmall?.copyWith(color: const Color(0xFF011627)),
    headlineSmall: base.headlineSmall?.copyWith(color: const Color(0xFF011627), fontWeight: FontWeight.w600),
    headlineMedium: base.headlineMedium?.copyWith(fontWeight: FontWeight.bold, color: const Color(0xFF011627)),
    titleLarge: base.titleLarge?.copyWith(fontWeight: FontWeight.w600, color: const Color(0xFF011627)),
    titleMedium: base.titleMedium?.copyWith(color: const Color(0xFF333333)),
    bodyMedium: base.bodyMedium?.copyWith(color: const Color(0xFF666666)),
    bodySmall: base.bodySmall?.copyWith(color: const Color(0xFF9B9BB0)),
  );
}
