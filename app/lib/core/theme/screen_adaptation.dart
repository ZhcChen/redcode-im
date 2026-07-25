import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'phone_density.dart';

const Size _phonePortraitDesignSize = Size(375, 812);
const Size _phoneLandscapeDesignSize = Size(812, 375);
const double _tabletShortestSideBreakpoint = 600;

/// 手机端只允许按设计稿缩小，不再因为逻辑宽高更大而整体放大。
///
/// 同时，对逻辑尺寸已不小于设计稿、但物理最短边像素更低的手机，
/// 通过放大 designSize 的方式收紧 `.w/.h/.sp`，让 1.5K / 1080p
/// 手机更接近 2K 机型的视觉密度；窄屏小手机和平板维持原策略。
Size resolveScreenUtilDesignSize(
  Size screenSize, {
  double devicePixelRatio = 1,
  Size? physicalSize,
}) {
  if (_isTabletLike(screenSize)) {
    return _phonePortraitDesignSize;
  }

  final isLandscape = screenSize.width > screenSize.height;
  final baseDesignSize = isLandscape
      ? _phoneLandscapeDesignSize
      : _phonePortraitDesignSize;

  final densityFactor = resolvePhoneDensityFactor(
    logicalSize: screenSize,
    devicePixelRatio: devicePixelRatio,
    physicalSize: physicalSize,
  );
  final canTightenLargePhone =
      densityFactor < 1.0 &&
      screenSize.width >= baseDesignSize.width &&
      screenSize.height >= baseDesignSize.height;

  if (canTightenLargePhone) {
    return Size(
      screenSize.width / densityFactor,
      screenSize.height / densityFactor,
    );
  }

  return Size(
    math.max(screenSize.width, baseDesignSize.width),
    math.max(screenSize.height, baseDesignSize.height),
  );
}

bool _isTabletLike(Size screenSize) {
  return math.min(screenSize.width, screenSize.height) >=
      _tabletShortestSideBreakpoint;
}

class AdaptiveScreenUtilInit extends StatelessWidget {
  const AdaptiveScreenUtilInit({
    super.key,
    required this.builder,
    this.child,
    this.minTextAdapt = true,
    this.splitScreenMode = true,
  });

  final ScreenUtilInitBuilder builder;
  final Widget? child;
  final bool minTextAdapt;
  final bool splitScreenMode;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final view = View.maybeOf(context);
        final designSize = resolveScreenUtilDesignSize(
          Size(constraints.maxWidth, constraints.maxHeight),
          devicePixelRatio: view?.devicePixelRatio ?? 1,
          physicalSize: view?.physicalSize,
        );

        return ScreenUtilInit(
          designSize: designSize,
          minTextAdapt: minTextAdapt,
          splitScreenMode: splitScreenMode,
          builder: builder,
          child: child,
        );
      },
    );
  }
}
