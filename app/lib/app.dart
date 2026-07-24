import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'core/services/settings_service.dart';
import 'core/services/push_navigation.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/no_stretch_scroll_behavior.dart';
import 'core/theme/screen_adaptation.dart';
import 'core/update/hot_patch_asset_bundle.dart';
import 'core/update/hot_update_manager.dart';
import 'features/startup/splash_page.dart';

class RedcodeApp extends StatefulWidget {
  const RedcodeApp({super.key, this.hotUpdateManager});

  final HotUpdateManager? hotUpdateManager;

  @override
  State<RedcodeApp> createState() => _RedcodeAppState();
}

class _RedcodeAppState extends State<RedcodeApp> {
  String _appName = '';
  final SettingsService _settingsService = SettingsService();

  @override
  void initState() {
    super.initState();
    _loadAppName();
  }

  Future<void> _loadAppName() async {
    try {
      final appName = await _settingsService.fetchAppName();
      if (mounted) {
        setState(() {
          _appName = appName;
        });
      }
    } catch (_) {
      // 静默失败，使用默认值
    }
  }

  @override
  Widget build(BuildContext context) {
    final bundle = widget.hotUpdateManager == null
        ? rootBundle
        : HotPatchAssetBundle(
            hotUpdateManager: widget.hotUpdateManager!,
            fallback: rootBundle,
          );

    return DefaultAssetBundle(
      bundle: bundle,
      child: AdaptiveScreenUtilInit(
        builder: (context, child) => MaterialApp(
          title: _appName,
          theme: AppTheme.light,
          debugShowCheckedModeBanner: false,
          navigatorKey: pushNavigatorKey,
          scrollBehavior: const NoStretchScrollBehavior(),
          home: const SplashPage(),
        ),
      ),
    );
  }
}
