import 'package:flutter/material.dart';

class AppColors {
  const AppColors._();

  static const Color primary = Color(0xFF2563EB);
  static const Color primaryStrong = Color(0xFF1D4ED8);
  static const Color primarySoft = Color(0xFFE8F0FF);
  static const Color background = Color(0xFFF5F7FB);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceSoft = Color(0xFFEEF3FA);
  static const Color surfaceMuted = Color(0xFFE4EAF3);
  static const Color textPrimary = Color(0xFF172033);
  static const Color textSecondary = Color(0xFF6F7D91);
  static const Color textTertiary = Color(0xFF8D98A8);
  static const Color textQuaternary = textSecondary;
  static const Color textBlack = textPrimary;
  static const Color accent = primary;
  static const Color danger = Color(0xFFF6695E);
  static const Color divider = Color(0x14162339);
  static const Color iconPrimary = textPrimary;
  static const Color iconSecondary = textSecondary;

  static const Color darkPrimary = Color(0xFF5B8CFF);
  static const Color darkPrimaryStrong = Color(0xFF8CB3FF);
  static const Color darkPrimarySoft = Color(0xFF172E5C);
  static const Color darkBackground = Color(0xFF0D1424);
  static const Color darkSurface = Color(0xFF131D30);
  static const Color darkSurfaceSoft = Color(0xFF1B2940);
  static const Color darkSurfaceMuted = Color(0xFF26364F);
  static const Color darkTextPrimary = Color(0xFFF5F7FB);
  static const Color darkTextSecondary = Color(0xFFAEB9CA);
  static const Color darkDivider = Color(0x1AFFFFFF);

  // Compatibility aliases are removed as pages migrate to semantic tokens.
  static const Color settingsDivider = divider;
  static const Color settingsTextMuted = textTertiary;
  static const Color settingsAvatarBg = surfaceMuted;
  static const Color settingsDeactivateBg = danger;
  static const Color settingsLogoutBg = Color(0xFFFEECEB);
  static const Color settingsItemPressed = surfaceSoft;
}
