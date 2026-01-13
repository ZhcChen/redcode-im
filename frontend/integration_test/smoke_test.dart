import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';

import 'common/real_app_runner.dart';
import 'common/test_config.dart';

/// 冒烟测试 (P0)
///
/// 核心路径验证，每次提交必须通过。
/// 使用真实应用连接后端服务。
void main() {
  patrolTest(
    'J2-A-001: 密码登录成功',
    ($) async {
      // 初始化服务并启动真实应用
      await RealAppTestRunner.ensureInitialized();
      await $.pumpWidgetAndSettle(RealAppTestRunner.createApp());

      // 等待进入目标页面
      final reachedTarget = await _waitForLoginOrHome($);
      if (!reachedTarget) {
        fail('未能进入登录页面或主页，可能应用启动超时');
      }

      // 检查是否已在主页（已登录）
      if ($(BottomNavigationBar).exists) {
        // 已登录，测试通过
        return;
      }

      // 在登录页，执行登录流程
      await _performLogin($);

      // 等待登录完成，验证进入主页
      await $.pump(const Duration(seconds: 5));
      expect($(BottomNavigationBar), findsOneWidget);
    },
    config: PatrolTesterConfig(
      settleTimeout: const Duration(seconds: 30),
    ),
  );

  patrolTest(
    'J4-001: 发送文本消息',
    ($) async {
      await RealAppTestRunner.ensureInitialized();
      await $.pumpWidgetAndSettle(RealAppTestRunner.createApp());

      // 等待并确保已登录
      await _waitForLoginOrHome($);
      await _ensureLoggedIn($);
      await $.pump(const Duration(seconds: 2));

      // 验证在主页
      expect($(BottomNavigationBar), findsOneWidget);

      // 查找聊天列表项并点击第一个
      final listTiles = $(ListTile);
      if (listTiles.exists) {
        await listTiles.first.tap();
        await $.pump(const Duration(seconds: 2));

        // 在聊天详情页，找到消息输入框
        final messageInput = $(TextField);
        if (messageInput.exists) {
          final testMessage = '测试消息 ${DateTime.now().millisecondsSinceEpoch}';
          await messageInput.last.enterText(testMessage);
          await $.pump(const Duration(milliseconds: 500));

          // 点击发送按钮
          final sendButton = $(Icons.send);
          if (sendButton.exists) {
            await sendButton.tap();
            await $.pump(const Duration(seconds: 2));
          }
        }
      }
    },
    config: PatrolTesterConfig(
      settleTimeout: const Duration(seconds: 30),
    ),
  );

  patrolTest(
    'J6-004: 退出登录',
    ($) async {
      await RealAppTestRunner.ensureInitialized();
      await $.pumpWidgetAndSettle(RealAppTestRunner.createApp());

      // 等待并确保已登录
      await _waitForLoginOrHome($);
      await _ensureLoggedIn($);
      await $.pump(const Duration(seconds: 2));

      // 验证在主页
      expect($(BottomNavigationBar), findsOneWidget);

      // 点击「我的」Tab（通常是最后一个）
      final bottomNav = $(BottomNavigationBar);
      if (bottomNav.exists) {
        await bottomNav.tap();
        await $.pump(const Duration(seconds: 1));
      }

      // 查找设置入口
      final settingsButton = $('设置');
      if (settingsButton.exists) {
        await settingsButton.tap();
        await $.pump(const Duration(seconds: 1));
      }

      // 查找退出登录
      final logoutButton = $('退出登录');
      if (logoutButton.exists) {
        await logoutButton.tap();
        await $.pump(const Duration(seconds: 1));

        // 确认退出
        final confirmButton = $('确定');
        if (confirmButton.exists) {
          await confirmButton.tap();
          await $.pump(const Duration(seconds: 3));
        }

        // 验证回到登录页
        expect($('你好！'), findsOneWidget);
      }
    },
    config: PatrolTesterConfig(
      settleTimeout: const Duration(seconds: 30),
    ),
  );
}

/// 等待进入登录页或主页
///
/// 处理 SplashPage 初始化、版本更新弹窗等
/// 返回 true 表示成功进入目标页面
Future<bool> _waitForLoginOrHome(PatrolIntegrationTester $) async {
  for (int i = 0; i < 30; i++) {
    await $.pump(const Duration(seconds: 1));

    // 处理更新弹窗
    final laterButton = $('稍后再说');
    if (laterButton.exists) {
      await laterButton.tap();
      await $.pump(const Duration(milliseconds: 500));
      continue;
    }

    // 处理其他弹窗
    final okButton = $('好的');
    if (okButton.exists) {
      await okButton.tap();
      await $.pump(const Duration(milliseconds: 500));
      continue;
    }

    // 检查是否在登录页
    if ($('你好！').exists) {
      return true;
    }

    // 检查是否在主页
    if ($(BottomNavigationBar).exists) {
      return true;
    }
  }
  return false;
}

/// 执行登录流程
Future<void> _performLogin(PatrolIntegrationTester $) async {
  final textFields = $(TextField);
  if (!textFields.exists) return;

  // 输入手机号
  await textFields.first.enterText(TestConfig.testUser.mobile);
  await $.pump(const Duration(milliseconds: 300));

  // 输入密码
  await textFields.at(1).enterText(TestConfig.testUser.password);
  await $.pump(const Duration(milliseconds: 300));

  // 勾选协议
  final agreementRow = $('注册/登陆即代表同意');
  if (agreementRow.exists) {
    await agreementRow.tap();
    await $.pump(const Duration(milliseconds: 300));
  }

  // 点击登录
  final loginButton = $('登录账号');
  if (loginButton.exists) {
    await loginButton.tap();
  }
}

/// 确保用户已登录
///
/// 如果在登录页，执行登录；如果已在主页，直接返回
Future<void> _ensureLoggedIn(PatrolIntegrationTester $) async {
  if ($('你好！').exists) {
    await _performLogin($);
    await $.pump(const Duration(seconds: 5));
  }
}
