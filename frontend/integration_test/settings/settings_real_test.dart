import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:patrol/patrol.dart';

import 'package:frontend/features/settings/settings_page.dart';
import 'package:frontend/core/theme/app_theme.dart';

/// 设置页面测试 (J6 路径)
///
/// 直接启动 SettingsPage，验证 UI 元素和交互。
void main() {
  patrolTest(
    'SET-001: 设置页面 UI 验证',
    ($) async {
      await $.pumpWidgetAndSettle(_buildSettingsApp());
      await $.pump(const Duration(seconds: 1));

      // 验证页面标题
      expect($('设置'), findsOneWidget);

      // 验证设置项存在
      expect($('账号与安全'), findsOneWidget);
      expect($('隐私协议'), findsOneWidget);
      expect($('聊天'), findsOneWidget);
      expect($('关于Chatly'), findsOneWidget);
    },
    config: PatrolTesterConfig(
      settleTimeout: const Duration(seconds: 10),
    ),
  );

  patrolTest(
    'SET-002: 设置页面按钮验证',
    ($) async {
      await $.pumpWidgetAndSettle(_buildSettingsApp());
      await $.pump(const Duration(seconds: 1));

      // 验证注销账号按钮
      expect($('注销账号'), findsOneWidget);

      // 验证退出登录按钮
      expect($('退出登录'), findsOneWidget);
    },
    config: PatrolTesterConfig(
      settleTimeout: const Duration(seconds: 10),
    ),
  );

  patrolTest(
    'SET-003: 用户信息显示',
    ($) async {
      await $.pumpWidgetAndSettle(_buildSettingsApp());
      await $.pump(const Duration(seconds: 2));

      // 验证手机号标签存在（可能显示 "手机号：未绑定" 或实际手机号）
      final phoneLabel = $('手机号：');
      // 使用 Text widget 查找包含 "手机号" 的文本
      final phoneTexts = $(Text).evaluate().where((element) {
        final widget = element.widget as Text;
        final data = widget.data ?? '';
        return data.contains('手机号');
      });
      expect(phoneTexts.isNotEmpty, isTrue);
    },
    config: PatrolTesterConfig(
      settleTimeout: const Duration(seconds: 10),
    ),
  );

  patrolTest(
    'SET-004: 设置项可点击',
    ($) async {
      await $.pumpWidgetAndSettle(_buildSettingsApp());
      await $.pump(const Duration(seconds: 1));

      // 验证设置项有箭头图标（表示可点击）
      final chevronIcons = $(Icons.chevron_right);
      expect(chevronIcons.exists, isTrue);

      // 设置项应该有4个（账号与安全、隐私协议、聊天、关于）
      // 每个设置项都应该可点击
      expect($('账号与安全'), findsOneWidget);
      expect($('隐私协议'), findsOneWidget);
      expect($('聊天'), findsOneWidget);
      expect($('关于Chatly'), findsOneWidget);
    },
    config: PatrolTesterConfig(
      settleTimeout: const Duration(seconds: 10),
    ),
  );
}

/// 构建设置页测试应用
Widget _buildSettingsApp() {
  return ScreenUtilInit(
    designSize: const Size(375, 812),
    minTextAdapt: true,
    splitScreenMode: true,
    builder: (context, child) => MaterialApp(
      title: 'Settings Test',
      theme: AppTheme.light,
      debugShowCheckedModeBanner: false,
      home: const SettingsPage(),
    ),
  );
}
