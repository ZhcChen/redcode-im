import 'package:flutter/material.dart';

ThemeData buildAppTheme() {
  const seed = Color(0xFF3A68FF);
  final colorScheme = ColorScheme.fromSeed(seedColor: seed, brightness: Brightness.light);

  return ThemeData(
    colorScheme: colorScheme,
    scaffoldBackgroundColor: const Color(0xFFF5F7FB),
    useMaterial3: true,
    textTheme: _buildTextTheme(ThemeData(brightness: Brightness.light).textTheme),
    snackBarTheme: const SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
    ),
    inputDecorationTheme: const InputDecorationTheme(
      border: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(10)),
      ),
    ),
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: Colors.white,
      selectedIconTheme: const IconThemeData(size: 24),
      unselectedIconTheme: IconThemeData(size: 22, color: Colors.grey.shade600),
      selectedLabelTextStyle: const TextStyle(fontWeight: FontWeight.bold),
      unselectedLabelTextStyle: TextStyle(color: Colors.grey.shade600),
    ),
  );
}

TextTheme _buildTextTheme(TextTheme base) {
  return base.copyWith(
    headlineMedium: base.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
    titleLarge: base.titleLarge?.copyWith(fontWeight: FontWeight.w600),
  );
}
