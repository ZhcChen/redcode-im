import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:frontend/core/theme/app_theme.dart';
import 'package:frontend/features/auth/login_page.dart';
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
    '登录页基础元素可见',
    config: const PatrolTesterConfig(visibleTimeout: Duration(seconds: 15)),
    ($) async {
      await _pumpTestApp($, const LoginPage());

      expect($('你好！'), findsOneWidget);
      expect($('登录账号'), findsOneWidget);
      expect($('手机号'), findsOneWidget);
      expect($('密码'), findsOneWidget);
      expect($('Google 登录'), findsOneWidget);
    },
  );

  patrolTest(
    '登录页可切换注册并返回密码登录',
    config: const PatrolTesterConfig(visibleTimeout: Duration(seconds: 15)),
    ($) async {
      await _pumpTestApp($, const LoginPage());

      await $('立即注册').tap();
      await $('注册账号').waitUntilVisible();

      expect($('设置密码'), findsOneWidget);
      expect($('立即登录'), findsOneWidget);

      await $('立即登录').tap();
      await $('登录账号').waitUntilVisible();

      expect($('其他登录方式'), findsOneWidget);
      expect($('密码登录'), findsOneWidget);
    },
  );

  patrolTest(
    'mock 登录后可进入首页并切到设置页',
    skip: !_useMockData,
    config: const PatrolTesterConfig(
      visibleTimeout: Duration(seconds: 15),
      settleTimeout: Duration(seconds: 15),
    ),
    ($) async {
      await _pumpTestApp($, const LoginPage());

      await $('登录账号').tap();
      await $('聊天').waitUntilVisible();

      expect($('联系人'), findsOneWidget);
      expect($('设置'), findsOneWidget);

      await $('设置').tap();
      await $('账号与安全').waitUntilVisible();
      expect($('退出登录'), findsOneWidget);
    },
  );
}
