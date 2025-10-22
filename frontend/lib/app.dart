import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'core/theme/no_stretch_scroll_behavior.dart';
import 'features/startup/splash_page.dart';

class RedcodeApp extends StatelessWidget {
  const RedcodeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Redcode IM',
      theme: AppTheme.light,
      debugShowCheckedModeBanner: false,
      scrollBehavior: const NoStretchScrollBehavior(),
      home: const SplashPage(),
    );
  }
}
