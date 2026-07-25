import 'package:app/core/theme/phone_density.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('resolvePhoneDensityFactor', () {
    test('keeps 2k phones at default density', () {
      expect(
        resolvePhoneDensityFactor(
          logicalSize: const Size(412, 915),
          devicePixelRatio: 1440 / 412,
          physicalSize: const Size(1440, 3200),
        ),
        1.0,
      );
    });

    test('tightens 1.5k phones slightly', () {
      expect(
        resolvePhoneDensityFactor(
          logicalSize: const Size(406.7, 904),
          devicePixelRatio: 3,
          physicalSize: const Size(1220, 2712),
        ),
        0.96,
      );
    });

    test('does not tighten tablet layouts', () {
      expect(
        resolvePhoneDensityFactor(
          logicalSize: const Size(800, 1280),
          devicePixelRatio: 2,
          physicalSize: const Size(1600, 2560),
        ),
        1.0,
      );
    });
  });

  group('AdaptivePhoneDensity', () {
    testWidgets('applies density scope and text scaler on 1.5k phones', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1220, 2712);
      tester.view.devicePixelRatio = 3;

      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      double? resolvedScale;
      double? scaledFontSize;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              return AdaptivePhoneDensity(
                child: Builder(
                  builder: (context) {
                    resolvedScale = context.phoneDensity.scaleFactor;
                    scaledFontSize = MediaQuery.of(
                      context,
                    ).textScaler.scale(10);
                    return const SizedBox.shrink();
                  },
                ),
              );
            },
          ),
        ),
      );

      expect(resolvedScale, 0.96);
      expect(scaledFontSize, closeTo(9.6, 0.0001));
    });
  });
}
