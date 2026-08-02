import 'package:flutter/material.dart';

import '../core/theme/design_tokens.dart';
import '../platform/platform_capabilities.dart';
import 'desktop/desktop_app_shell.dart';
import 'mobile/mobile_app_shell.dart';

class AppShell extends StatelessWidget {
  const AppShell({
    super.key,
    required this.mobilePages,
    required this.desktopPages,
    this.forceDesktop,
    this.badgeCounts = const [0, 0, 0, 0],
    this.onMobileSelected,
    this.onMobileReselect,
  });

  final List<Widget> mobilePages;
  final List<Widget> desktopPages;
  final bool? forceDesktop;
  final List<int> badgeCounts;
  final ValueChanged<int>? onMobileSelected;
  final ValueChanged<int>? onMobileReselect;

  @override
  Widget build(BuildContext context) {
    final desktop =
        forceDesktop ??
        (PlatformCapabilities.isDesktopPlatform &&
            MediaQuery.sizeOf(context).width >= AppBreakpoints.desktop);
    if (desktop) {
      return DesktopAppShell(pages: desktopPages);
    }
    return MobileAppShell(
      pages: mobilePages,
      badgeCounts: badgeCounts,
      onSelected: onMobileSelected,
      onReselect: onMobileReselect,
    );
  }
}
