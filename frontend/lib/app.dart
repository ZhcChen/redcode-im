import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'core/theme/app_theme.dart';
import 'core/theme/no_stretch_scroll_behavior.dart';
import 'core/update/hot_patch_asset_bundle.dart';
import 'core/update/hot_update_manager.dart';
import 'features/startup/splash_page.dart';

class RedcodeApp extends StatelessWidget {
  const RedcodeApp({super.key, this.hotUpdateManager});

  final HotUpdateManager? hotUpdateManager;

  @override
  Widget build(BuildContext context) {
    final bundle = hotUpdateManager == null
        ? rootBundle
        : HotPatchAssetBundle(
            hotUpdateManager: hotUpdateManager!,
            fallback: rootBundle,
          );

    return DefaultAssetBundle(
      bundle: bundle,
      child: MaterialApp(
        title: 'Redcode IM',
        theme: AppTheme.light,
        debugShowCheckedModeBanner: false,
        scrollBehavior: const NoStretchScrollBehavior(),
        home: const SplashPage(),
      ),
    );
  }
}
