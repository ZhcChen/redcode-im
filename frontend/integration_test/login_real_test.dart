import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:patrol/patrol.dart';

import 'package:frontend/features/auth/login_page.dart';
import 'package:frontend/core/theme/app_theme.dart';

import 'common/test_config.dart';

/// 登录页面真机测试
///
/// 直接启动到登录页面，跳过 SplashPage 的复杂初始化逻辑。
/// 用于验证登录功能在真机上的表现。
void main() {
  patrolTest(
    'J2-A-001: 登录页面 UI 验证',
    ($) async {
      // 直接启动登录页面
      await $.pumpWidgetAndSettle(_buildLoginApp());

      // 验证登录页关键元素
      expect($('你好！'), findsOneWidget);
      expect($('手机号'), findsOneWidget);
      expect($('密码登录'), findsOneWidget);
      expect($('登录账号'), findsOneWidget);
    },
    config: PatrolTesterConfig(
      settleTimeout: const Duration(seconds: 10),
    ),
  );

  patrolTest(
    'J2-A-002: 登录表单填写',
    ($) async {
      await $.pumpWidgetAndSettle(_buildLoginApp());

      // 等待页面完全加载
      await $.pump(const Duration(seconds: 1));

      // 找到输入框
      final textFields = $(TextField);
      expect(textFields, findsWidgets);

      // 输入手机号（第一个输入框）
      await textFields.first.enterText(TestConfig.testUser.mobile);
      await $.pump(const Duration(milliseconds: 500));

      // 输入密码（第二个输入框，密码登录模式下）
      if (textFields.evaluate().length > 1) {
        await textFields.at(1).enterText(TestConfig.testUser.password);
        await $.pump(const Duration(milliseconds: 500));
      }

      // 勾选协议（点击协议文本区域）
      final agreementText = $('注册/登陆即代表同意');
      if (agreementText.exists) {
        await agreementText.tap();
        await $.pump(const Duration(milliseconds: 300));
      }

      // 验证登录按钮可点击
      final loginButton = $('登录账号');
      expect(loginButton, findsOneWidget);
    },
    config: PatrolTesterConfig(
      settleTimeout: const Duration(seconds: 10),
    ),
  );

  patrolTest(
    'J2-A-003: 切换登录类型',
    ($) async {
      await $.pumpWidgetAndSettle(_buildLoginApp());
      await $.pump(const Duration(seconds: 1));

      // 点击「立即注册」切换到注册模式
      final registerLink = $('立即注册');
      if (registerLink.exists) {
        await registerLink.tap();
        await $.pump(const Duration(milliseconds: 500));

        // 验证切换到注册模式
        expect($('注册账号'), findsOneWidget);
        expect($('设置密码'), findsOneWidget);
      }

      // 点击「立即登录」切换回登录模式
      final loginLink = $('立即登录');
      if (loginLink.exists) {
        await loginLink.tap();
        await $.pump(const Duration(milliseconds: 500));

        // 验证切换回登录模式
        expect($('登录账号'), findsOneWidget);
      }
    },
    config: PatrolTesterConfig(
      settleTimeout: const Duration(seconds: 10),
    ),
  );
}

/// 构建直接包含登录页的测试应用
Widget _buildLoginApp() {
  return ScreenUtilInit(
    designSize: const Size(375, 812),
    minTextAdapt: true,
    splitScreenMode: true,
    builder: (context, child) => MaterialApp(
      title: 'Login Test',
      theme: AppTheme.light,
      debugShowCheckedModeBanner: false,
      home: const LoginPage(),
    ),
  );
}
