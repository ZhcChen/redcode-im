import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:patrol/patrol.dart';

import 'package:frontend/features/chat/create_group_page.dart';
import 'package:frontend/core/theme/app_theme.dart';

/// 创建群聊页面测试 (J5 路径)
///
/// 直接启动 CreateGroupPage，验证 UI 元素和交互。
void main() {
  patrolTest(
    'GROUP-001: 创建群聊页面 UI 验证',
    ($) async {
      await $.pumpWidgetAndSettle(_buildCreateGroupApp());

      // 等待页面加载
      for (int i = 0; i < 10; i++) {
        await $.pump(const Duration(seconds: 1));
        if ($('创建群聊').exists) {
          break;
        }
      }

      // 验证页面标题
      expect($('创建群聊'), findsOneWidget);

      // 验证创建按钮
      expect($('创建'), findsOneWidget);

      // 验证群名称输入框
      expect($('群聊名称'), findsOneWidget);
    },
    config: PatrolTesterConfig(
      settleTimeout: const Duration(seconds: 10),
    ),
  );

  patrolTest(
    'GROUP-002: 群名称输入',
    ($) async {
      await $.pumpWidgetAndSettle(_buildCreateGroupApp());
      await $.pump(const Duration(seconds: 1));

      // 找到群名称输入框
      final nameField = $(TextField);
      if (nameField.exists) {
        // 输入群名称
        await nameField.first.enterText('测试群聊');
        await $.pump(const Duration(milliseconds: 500));

        // 验证输入成功
        final textField = nameField.first.evaluate().first.widget as TextField;
        expect(textField.controller?.text, '测试群聊');
      }
    },
    config: PatrolTesterConfig(
      settleTimeout: const Duration(seconds: 10),
    ),
  );

  patrolTest(
    'GROUP-003: 好友选择列表',
    ($) async {
      await $.pumpWidgetAndSettle(_buildCreateGroupApp());

      // 等待好友列表加载
      for (int i = 0; i < 10; i++) {
        await $.pump(const Duration(seconds: 1));
        if (!$(CircularProgressIndicator).exists) {
          break;
        }
      }

      // 验证页面元素
      final hasGroupName = $('群聊名称').exists;
      final hasFriendList = $(ListTile).exists || $(CheckboxListTile).exists;
      final hasEmptyState = $('暂无好友').exists;

      // 应该显示群名称输入和好友列表（或空状态）
      expect(hasGroupName, isTrue);
      expect(hasFriendList || hasEmptyState, isTrue);
    },
    config: PatrolTesterConfig(
      settleTimeout: const Duration(seconds: 10),
    ),
  );

  patrolTest(
    'GROUP-004: 群头像区域',
    ($) async {
      await $.pumpWidgetAndSettle(_buildCreateGroupApp());
      await $.pump(const Duration(seconds: 1));

      // 验证头像上传区域存在（相机图标）
      final cameraIcon = $(Icons.camera_alt_outlined);
      expect(cameraIcon.exists, isTrue);
    },
    config: PatrolTesterConfig(
      settleTimeout: const Duration(seconds: 10),
    ),
  );
}

/// 构建创建群聊页测试应用
Widget _buildCreateGroupApp() {
  return ScreenUtilInit(
    designSize: const Size(375, 812),
    minTextAdapt: true,
    splitScreenMode: true,
    builder: (context, child) => MaterialApp(
      title: 'CreateGroup Test',
      theme: AppTheme.light,
      debugShowCheckedModeBanner: false,
      home: const CreateGroupPage(),
    ),
  );
}
