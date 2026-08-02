import 'package:flutter/foundation.dart';

abstract final class PlatformCapabilities {
  static bool get isDesktopPlatform {
    if (kIsWeb) return false;
    return switch (defaultTargetPlatform) {
      TargetPlatform.macOS ||
      TargetPlatform.windows ||
      TargetPlatform.linux => true,
      _ => false,
    };
  }
}
