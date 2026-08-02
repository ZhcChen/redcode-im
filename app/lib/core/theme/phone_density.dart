import 'dart:math' as math;

import 'package:flutter/widgets.dart';

const double _tabletShortestSideBreakpoint = 600;
const double _qhdPhoneShortestSidePx = 1400;
const double _midResolutionPhoneShortestSidePx = 1200;

/// 基于手机物理最短边像素做轻量分档，收紧 1.5K / 1080p 手机的视觉密度。
double resolvePhoneDensityFactor({
  required Size logicalSize,
  required double devicePixelRatio,
  Size? physicalSize,
}) {
  final shortestLogicalSide = math.min(logicalSize.width, logicalSize.height);
  if (shortestLogicalSide >= _tabletShortestSideBreakpoint) {
    return 1.0;
  }

  final shortestPhysicalSide =
      physicalSize != null && physicalSize.width > 0 && physicalSize.height > 0
      ? math.min(physicalSize.width, physicalSize.height)
      : shortestLogicalSide * devicePixelRatio;

  if (shortestPhysicalSide >= _qhdPhoneShortestSidePx) {
    return 1.0;
  }
  if (shortestPhysicalSide >= _midResolutionPhoneShortestSidePx) {
    return 0.94;
  }
  return 0.88;
}

PhoneDensityData resolvePhoneDensity({
  required Size logicalSize,
  required double devicePixelRatio,
  Size? physicalSize,
}) {
  final shortestPhysicalSide =
      physicalSize != null && physicalSize.width > 0 && physicalSize.height > 0
      ? math.min(physicalSize.width, physicalSize.height)
      : math.min(logicalSize.width, logicalSize.height) * devicePixelRatio;

  return PhoneDensityData._(
    scaleFactor: resolvePhoneDensityFactor(
      logicalSize: logicalSize,
      devicePixelRatio: devicePixelRatio,
      physicalSize: physicalSize,
    ),
    shortestPhysicalSide: shortestPhysicalSide,
  );
}

@immutable
class PhoneDensityData {
  const PhoneDensityData._({
    required this.scaleFactor,
    required this.shortestPhysicalSide,
  });

  static const regular = PhoneDensityData._(
    scaleFactor: 1.0,
    shortestPhysicalSide: 0,
  );

  final double scaleFactor;
  final double shortestPhysicalSide;

  bool get isRegular => scaleFactor == 1.0;

  double scale(double value) => value * scaleFactor;

  TextScaler applyToTextScaler(TextScaler base) {
    if (isRegular) {
      return base;
    }
    return _MultiplicativeTextScaler(base, scaleFactor);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is PhoneDensityData &&
        other.scaleFactor == scaleFactor &&
        other.shortestPhysicalSide == shortestPhysicalSide;
  }

  @override
  int get hashCode => Object.hash(scaleFactor, shortestPhysicalSide);
}

class AdaptivePhoneDensity extends StatelessWidget {
  const AdaptivePhoneDensity({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.maybeOf(context);
    if (mediaQuery == null) {
      return PhoneDensityScope(data: PhoneDensityData.regular, child: child);
    }

    final density = resolvePhoneDensity(
      logicalSize: mediaQuery.size,
      devicePixelRatio: mediaQuery.devicePixelRatio,
    );

    return PhoneDensityScope(
      data: density,
      child: MediaQuery(
        data: mediaQuery.copyWith(
          textScaler: density.applyToTextScaler(mediaQuery.textScaler),
        ),
        child: child,
      ),
    );
  }
}

class PhoneDensityScope extends InheritedWidget {
  const PhoneDensityScope({
    super.key,
    required this.data,
    required super.child,
  });

  final PhoneDensityData data;

  static PhoneDensityData of(BuildContext context) {
    return context
            .dependOnInheritedWidgetOfExactType<PhoneDensityScope>()
            ?.data ??
        PhoneDensityData.regular;
  }

  @override
  bool updateShouldNotify(PhoneDensityScope oldWidget) {
    return data != oldWidget.data;
  }
}

extension PhoneDensityContext on BuildContext {
  PhoneDensityData get phoneDensity => PhoneDensityScope.of(this);
}

@immutable
class _MultiplicativeTextScaler extends TextScaler {
  const _MultiplicativeTextScaler(this.base, this.factor);

  final TextScaler base;
  final double factor;

  @override
  double get textScaleFactor => base.scale(1.0) * factor;

  @override
  double scale(double fontSize) => base.scale(fontSize) * factor;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is _MultiplicativeTextScaler &&
        other.base == base &&
        other.factor == factor;
  }

  @override
  int get hashCode => Object.hash(base, factor);
}
