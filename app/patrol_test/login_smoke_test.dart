import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:app/core/theme/app_theme.dart';
import 'package:app/core/routing/app_router.dart';
import 'package:app/features/auth/login_page.dart';
import 'package:patrol/patrol.dart';

const bool _useMockData = bool.fromEnvironment(
  'USE_MOCK_DATA',
  defaultValue: false,
);

Widget _buildTestApp(Widget home) {
  return ScreenUtilInit(
    designSize: const Size(375, 812),
    minTextAdapt: true,
    splitScreenMode: true,
    builder: (context, child) => MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      onGenerateRoute: AppRouter.onGenerateRoute,
      home: home,
    ),
  );
}

Future<void> _pumpTestApp(PatrolIntegrationTester $, Widget home) async {
  await $.pumpWidget(_buildTestApp(home));
  await $.pump(const Duration(milliseconds: 800));
}

void main() {
  patrolTest(
    '登录页 smoke',
    config: const PatrolTesterConfig(visibleTimeout: Duration(seconds: 15)),
    ($) async {
      await _pumpTestApp($, const LoginPage());

      expect($('你好！'), findsOneWidget);
      expect($('登录账号'), findsOneWidget);
      expect($('账号'), findsOneWidget);
      expect($('密码'), findsOneWidget);
      expect($('Google 登录'), findsNothing);
      expect($('Apple 登录'), findsNothing);

      await _pumpTestApp($, const LoginPage());

      await $('立即注册').tap();
      await $('注册账号').waitUntilVisible();

      expect($('设置密码'), findsOneWidget);
      expect($('立即登录'), findsOneWidget);

      await $('立即登录').tap();
      await $('登录账号').waitUntilVisible();

      expect($('密码登录'), findsOneWidget);
      expect($('Google 登录'), findsNothing);
      expect($('Apple 登录'), findsNothing);

      if (!_useMockData) {
        return;
      }

      await _pumpTestApp($, const LoginPage());
      await $(TextField).at(0).enterText('alice');
      await $(TextField).at(1).enterText('pass123456');
      await $('登录账号').tap();
      await $('聊天').waitUntilVisible();

      expect($('联系人'), findsOneWidget);
      expect($('发现'), findsOneWidget);
      expect($('我的'), findsOneWidget);

      await $('我的').tap();
      await $('账号与安全').waitUntilVisible();
      expect($('退出登录'), findsOneWidget);
    },
  );
}
