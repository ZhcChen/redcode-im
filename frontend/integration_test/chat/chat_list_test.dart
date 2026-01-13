import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';

import 'package:frontend/app.dart';
import '../common/test_config.dart';

void main() {
  patrolTest('聊天列表 - 已登录用户可查看聊天列表', ($) async {
    await $.pumpWidgetAndSettle(const RedcodeApp());

    // 首先需要登录
    await _performLogin($);

    // 等待进入主页
    await $.pump(const Duration(seconds: 3));

    // 验证底部导航栏存在
    expect($(BottomNavigationBar), findsOneWidget);
  });

  patrolTest('聊天列表 - 点击聊天项进入聊天详情', ($) async {
    await $.pumpWidgetAndSettle(const RedcodeApp());
    await _performLogin($);
    await $.pump(const Duration(seconds: 3));

    // 查找聊天列表项
    final listTiles = $(ListTile);
    if (listTiles.exists) {
      await listTiles.first.tap();
      await $.pump(const Duration(seconds: 2));

      // 验证进入聊天详情页
      expect($(TextField), findsOneWidget); // 消息输入框
    }
  });

  patrolTest('聊天详情 - 发送文本消息', ($) async {
    await $.pumpWidgetAndSettle(const RedcodeApp());
    await _performLogin($);
    await $.pump(const Duration(seconds: 3));

    // 进入聊天详情
    final listTiles = $(ListTile);
    if (listTiles.exists) {
      await listTiles.first.tap();
      await $.pump(const Duration(seconds: 2));

      // 输入消息
      final messageInput = $(TextField).last;
      await messageInput.enterText('测试消息 - ${DateTime.now()}');

      // 点击发送按钮
      final sendButton = $(IconButton).last;
      await sendButton.tap();
      await $.pump(const Duration(seconds: 2));
    }
  });

  patrolTest('聊天详情 - 权限请求处理（发送图片）', ($) async {
    await $.pumpWidgetAndSettle(const RedcodeApp());
    await _performLogin($);
    await $.pump(const Duration(seconds: 3));

    // 进入聊天详情
    final listTiles = $(ListTile);
    if (listTiles.exists) {
      await listTiles.first.tap();
      await $.pump(const Duration(seconds: 2));

      // 点击附件按钮（通常是 + 图标）
      final attachButton = $(Icons.add);
      if (attachButton.exists) {
        await attachButton.tap();
        await $.pump(const Duration(seconds: 1));

        // 点击图片选项
        final photoOption = $('图片');
        if (photoOption.exists) {
          await photoOption.tap();

          // Patrol 可以处理原生权限弹窗
          await $.native.grantPermissionWhenInUse();
          await $.pump(const Duration(seconds: 2));
        }
      }
    }
  });
}

/// 执行登录流程
Future<void> _performLogin(PatrolIntegrationTester $) async {
  await $.pump(const Duration(seconds: 3));

  // 勾选用户协议
  final checkbox = $(Checkbox);
  if (checkbox.exists) {
    final checkboxWidget = checkbox.evaluate().first.widget as Checkbox;
    if (checkboxWidget.value != true) {
      await checkbox.tap();
      await $.pump();
    }
  }

  // 输入账号密码
  final textFields = $(TextField);
  if (textFields.exists) {
    await textFields.at(0).enterText(TestConfig.testUser.mobile);
    await textFields.at(1).enterText(TestConfig.testUser.password);
  }

  // 点击登录
  final loginButton = $('登录账号');
  if (loginButton.exists) {
    await loginButton.tap();
  }
}
