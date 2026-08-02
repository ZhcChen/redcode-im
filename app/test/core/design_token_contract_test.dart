import 'package:app/core/constants/app_colors.dart';
import 'package:app/core/theme/app_theme.dart';
import 'package:app/core/theme/design_tokens.dart';
import 'package:app/core/theme/phone_density.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('2.0 design tokens', () {
    test('light palette matches the frozen design source', () {
      expect(AppColors.primary, const Color(0xFF2563EB));
      expect(AppColors.primaryStrong, const Color(0xFF1D4ED8));
      expect(AppColors.primarySoft, const Color(0xFFE8F0FF));
      expect(AppColors.background, const Color(0xFFF5F7FB));
      expect(AppColors.surface, const Color(0xFFFFFFFF));
      expect(AppColors.surfaceSoft, const Color(0xFFEEF3FA));
      expect(AppColors.surfaceMuted, const Color(0xFFE4EAF3));
      expect(AppColors.textPrimary, const Color(0xFF172033));
      expect(AppColors.textSecondary, const Color(0xFF6F7D91));
      expect(AppColors.divider, const Color(0x14162339));
      expect(AppColors.danger, const Color(0xFFF6695E));
    });

    test('spacing, radii, control and motion scales stay complete', () {
      expect(AppSpacing.values, const [4, 8, 12, 16, 20, 24]);
      expect(AppRadii.values, const [14, 18, 22]);
      expect(AppControlSize.composer, 40);
      expect(AppControlSize.toolbarSearch, 44);
      expect(AppControlSize.field, 48);
      expect(AppControlSize.minTapTarget, 44);
      expect(AppControlSize.navigationIcon, 26);
      expect(AppMotion.fast, const Duration(milliseconds: 140));
      expect(AppMotion.standard, const Duration(milliseconds: 220));
      expect(AppMotion.emphasized, const Duration(milliseconds: 280));
    });

    test('density uses the frozen 2K, 1.5K and 1K scale factors', () {
      expect(
        resolvePhoneDensityFactor(
          logicalSize: const Size(412, 915),
          devicePixelRatio: 1440 / 412,
          physicalSize: const Size(1440, 3200),
        ),
        1,
      );
      expect(
        resolvePhoneDensityFactor(
          logicalSize: const Size(406.7, 904),
          devicePixelRatio: 3,
          physicalSize: const Size(1220, 2712),
        ),
        0.94,
      );
      expect(
        resolvePhoneDensityFactor(
          logicalSize: const Size(360, 900),
          devicePixelRatio: 3,
          physicalSize: const Size(1080, 2700),
        ),
        0.88,
      );
    });
  });

  group('2.0 themes', () {
    test('light and dark themes expose semantic color schemes', () {
      expect(AppTheme.light.brightness, Brightness.light);
      expect(AppTheme.light.colorScheme.primary, AppColors.primary);
      expect(AppTheme.light.scaffoldBackgroundColor, AppColors.background);
      expect(AppTheme.dark.brightness, Brightness.dark);
      expect(AppTheme.dark.colorScheme.primary, AppColors.darkPrimary);
      expect(AppTheme.dark.scaffoldBackgroundColor, AppColors.darkBackground);
    });

    testWidgets('motion resolves to zero when animations are disabled', (
      tester,
    ) async {
      Duration? duration;
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: child!,
          ),
          home: Builder(
            builder: (context) {
              duration = AppMotion.resolve(context, AppMotion.standard);
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      expect(duration, Duration.zero);
    });
  });
}
