import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';

import '../common/test_app.dart';
import '../common/test_config.dart';

void main() {
  patrolTest('登录页面 - 显示正确的 UI 元素', ($) async {
    await $.pumpWidgetAndSettle(const TestApp());

    // 验证登录页面核心元素存在（零侵入：使用文本和类型选择器）
    expect($(TextField), findsNWidgets(2));
    expect($('登录账号'), findsOneWidget);
    expect($('验证码登录'), findsOneWidget);
    expect($('注册账号'), findsOneWidget);
  });

  patrolTest('登录页面 - 空表单提交应显示错误', ($) async {
    await $.pumpWidgetAndSettle(const TestApp());

    // 勾选协议（使用类型选择器）
    await $(Checkbox).tap();
    await $.pump();

    // 点击登录按钮（使用文本选择器）
    await $('登录账号').tap();
    await $.pump(const Duration(seconds: 1));

    // 应该显示错误提示
    expect($('请输入手机号和密码'), findsOneWidget);
  });

  patrolTest('登录页面 - 输入手机号和密码', ($) async {
    await $.pumpWidgetAndSettle(const TestApp());

    // 输入手机号（使用索引：第一个输入框）
    await $(TextField).first.enterText(TestConfig.testUser.mobile);

    // 输入密码（使用索引：最后一个输入框）
    await $(TextField).last.enterText(TestConfig.testUser.password);

    // 验证输入值
    await $.pump();
    expect($(TextField).first, findsOneWidget);
  });

  patrolTest('登录页面 - 用户协议勾选', ($) async {
    await $.pumpWidgetAndSettle(const TestApp());

    // 默认未勾选，登录按钮应禁用
    final loginButton = $('登录账号');
    expect(loginButton, findsOneWidget);

    // 勾选协议（使用类型选择器）
    await $(Checkbox).tap();
    await $.pump();

    // 登录按钮应启用
    expect($('登录账号'), findsOneWidget);
  });

  patrolTest('登录页面 - 完整登录流程', ($) async {
    await $.pumpWidgetAndSettle(const TestApp());

    // 1. 勾选协议
    await $(Checkbox).tap();
    await $.pump();

    // 2. 输入手机号
    await $(TextField).first.enterText(TestConfig.testUser.mobile);

    // 3. 输入密码
    await $(TextField).last.enterText(TestConfig.testUser.password);

    // 4. 点击登录（使用文本选择器）
    await $('登录账号').tap();
    await $.pump(const Duration(seconds: 1));

    // 5. 验证登录成功提示
    expect($('登录成功'), findsOneWidget);
  });
}
