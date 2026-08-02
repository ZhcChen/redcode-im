import 'package:flutter/widgets.dart';

class AppSpacing {
  const AppSpacing._();

  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 20;
  static const double xl = 24;

  static const values = <double>[xxs, xs, sm, md, lg, xl];
}

class AppRadii {
  const AppRadii._();

  static const double control = 14;
  static const double group = 18;
  static const double emphasized = 22;
  static const double pill = 999;

  static const values = <double>[control, group, emphasized];
}

class AppControlSize {
  const AppControlSize._();

  static const double composer = 40;
  static const double toolbarSearch = 44;
  static const double field = 48;
  static const double minTapTarget = 44;
  static const double navigationIcon = 26;
  static const double appBar = 56;
  static const double denseAppBar = 48;
  static const double bottomBar = 64;
}

class AppMotion {
  const AppMotion._();

  static const Duration fast = Duration(milliseconds: 140);
  static const Duration standard = Duration(milliseconds: 220);
  static const Duration emphasized = Duration(milliseconds: 280);

  static Duration resolve(BuildContext context, Duration duration) {
    return MediaQuery.maybeOf(context)?.disableAnimations ?? false
        ? Duration.zero
        : duration;
  }
}

class AppBreakpoints {
  const AppBreakpoints._();

  static const double tablet = 600;
  static const double desktop = 1024;
  static const double wideDesktop = 1440;
}
