import 'package:app/core/theme/screen_adaptation.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('resolveScreenUtilDesignSize', () {
    test('keeps the base design size for smaller portrait phones', () {
      expect(
        resolveScreenUtilDesignSize(const Size(360, 780)),
        const Size(375, 812),
      );
    });

    test('keeps 2k portrait phones at regular density', () {
      expect(
        resolveScreenUtilDesignSize(
          const Size(412, 915),
          devicePixelRatio: 1440 / 412,
          physicalSize: const Size(1440, 3200),
        ),
        const Size(412, 915),
      );
    });

    test('tightens 1.5k portrait phones through design size', () {
      final designSize = resolveScreenUtilDesignSize(
        const Size(1220 / 3, 2712 / 3),
        devicePixelRatio: 3,
        physicalSize: const Size(1220, 2712),
      );

      expect(designSize.width, closeTo((1220 / 3) / 0.96, 0.0001));
      expect(designSize.height, closeTo((2712 / 3) / 0.96, 0.0001));
    });

    test('keeps narrow portrait phones on the base design size', () {
      expect(
        resolveScreenUtilDesignSize(
          const Size(360, 900),
          devicePixelRatio: 3,
          physicalSize: const Size(1080, 2700),
        ),
        const Size(375, 900),
      );
    });

    test('keeps 2k landscape phones at regular density', () {
      expect(
        resolveScreenUtilDesignSize(
          const Size(915, 412),
          devicePixelRatio: 3200 / 915,
          physicalSize: const Size(3200, 1440),
        ),
        const Size(915, 412),
      );
    });

    test('keeps tablet scaling behavior unchanged', () {
      expect(
        resolveScreenUtilDesignSize(const Size(800, 1280)),
        const Size(375, 812),
      );
    });

    test('keeps landscape tablet scaling behavior unchanged', () {
      expect(
        resolveScreenUtilDesignSize(const Size(1280, 800)),
        const Size(375, 812),
      );
    });

    test('treats the 600 logical-pixel boundary as tablet', () {
      expect(
        resolveScreenUtilDesignSize(const Size(600, 1000)),
        const Size(375, 812),
      );
    });
  });

  group('screen util scaling', () {
    testWidgets('2k phones keep width and height scale at 1', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1440, 3200);
      tester.view.devicePixelRatio = 1440 / 412;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        AdaptiveScreenUtilInit(
          builder: (context, child) => const Directionality(
            textDirection: TextDirection.ltr,
            child: SizedBox.shrink(),
          ),
        ),
      );

      expect(ScreenUtil().scaleWidth, 1);
      expect(ScreenUtil().scaleHeight, 1);
      expect(24.w, 24);
      expect(44.h, 44);
    });

    testWidgets('smaller phones still shrink from the base design', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(360, 780);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        AdaptiveScreenUtilInit(
          builder: (context, child) => const Directionality(
            textDirection: TextDirection.ltr,
            child: SizedBox.shrink(),
          ),
        ),
      );

      expect(ScreenUtil().scaleWidth, closeTo(360 / 375, 0.0001));
      expect(ScreenUtil().scaleHeight, closeTo(780 / 812, 0.0001));
      expect(24.w, lessThan(24));
      expect(44.h, lessThan(44));
    });

    testWidgets('1.5k android phone tightens width and height scale', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1220, 2712);
      tester.view.devicePixelRatio = 3;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        AdaptiveScreenUtilInit(
          builder: (context, child) => Directionality(
            textDirection: TextDirection.ltr,
            child: SizedBox.shrink(),
          ),
        ),
      );

      expect(ScreenUtil().screenWidth, closeTo(1220 / 3, 0.0001));
      expect(ScreenUtil().screenHeight, closeTo(2712 / 3, 0.0001));
      expect(ScreenUtil().scaleWidth, closeTo(0.96, 0.0001));
      expect(ScreenUtil().scaleHeight, closeTo(0.96, 0.0001));
      expect(24.w, closeTo(24 * 0.96, 0.0001));
      expect(14.sp, closeTo(14 * 0.96, 0.0001));
    });
  });
}
