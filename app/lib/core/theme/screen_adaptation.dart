import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

const Size _phonePortraitDesignSize = Size(375, 812);
const Size _phoneLandscapeDesignSize = Size(812, 375);
const double _tabletShortestSideBreakpoint = 600;

/// 手机端只允许按设计稿缩小，不再因为逻辑宽高更大而整体放大。
///
/// 这样 1.5K / 2K 等不同分辨率但物理尺寸接近的手机，会更接近同一套视觉密度。
/// 平板仍保留原有可放大行为，避免大屏上整体过小。
Size resolveScreenUtilDesignSize(Size screenSize) {
  if (_isTabletLike(screenSize)) {
    return _phonePortraitDesignSize;
  }

  final isLandscape = screenSize.width > screenSize.height;
  final baseDesignSize = isLandscape
      ? _phoneLandscapeDesignSize
      : _phonePortraitDesignSize;

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
        final designSize = resolveScreenUtilDesignSize(
          Size(constraints.maxWidth, constraints.maxHeight),
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
