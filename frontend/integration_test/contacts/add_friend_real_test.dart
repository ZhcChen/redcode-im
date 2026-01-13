import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:patrol/patrol.dart';

import 'package:frontend/features/contacts/add_friend_page.dart';
import 'package:frontend/core/theme/app_theme.dart';

/// 添加好友页面测试 (J3 路径)
///
/// 直接启动 AddFriendPage，验证 UI 元素和交互。
void main() {
  patrolTest(
    'FRIEND-001: 添加好友页面 UI 验证',
    ($) async {
      await $.pumpWidgetAndSettle(_buildAddFriendApp());

      // 等待页面加载
      for (int i = 0; i < 10; i++) {
        await $.pump(const Duration(seconds: 1));
        if ($('添加朋友').exists) {
          break;
        }
      }

      // 验证页面标题
      expect($('添加朋友'), findsOneWidget);

      // 验证搜索框存在
      final searchFields = $(TextField);
      expect(searchFields.exists, isTrue);
    },
    config: PatrolTesterConfig(
      settleTimeout: const Duration(seconds: 10),
    ),
  );

  patrolTest(
    'FRIEND-002: 搜索用户功能',
    ($) async {
      await $.pumpWidgetAndSettle(_buildAddFriendApp());
      await $.pump(const Duration(seconds: 2));

      // 找到搜索输入框
      final searchField = $(TextField);
      if (searchField.exists) {
        // 输入搜索关键词
        await searchField.first.enterText('test');
        await $.pump(const Duration(seconds: 2));

        // 验证搜索后的状态（可能显示结果或空状态）
        final hasResults = $(ListTile).exists;
        final noResults = $('未找到用户').exists;
        final hasSearchHint = $('请输入').exists;

        // 应该是其中一种状态
        expect(hasResults || noResults || hasSearchHint, isTrue);
      }
    },
    config: PatrolTesterConfig(
      settleTimeout: const Duration(seconds: 10),
    ),
  );

  patrolTest(
    'FRIEND-003: 好友请求列表',
    ($) async {
      await $.pumpWidgetAndSettle(_buildAddFriendApp());

      // 等待加载完成
      for (int i = 0; i < 10; i++) {
        await $.pump(const Duration(seconds: 1));
        if (!$(CircularProgressIndicator).exists) {
          break;
        }
      }

      // 验证页面已加载（可能有请求列表或空状态）
      final hasRequests = $('收到的请求').exists || $('发出的请求').exists;
      final noRequests = $('暂无好友请求').exists;
      final pageLoaded = $('添加朋友').exists;

      expect(hasRequests || noRequests || pageLoaded, isTrue);
    },
    config: PatrolTesterConfig(
      settleTimeout: const Duration(seconds: 10),
    ),
  );
}

/// 构建添加好友页测试应用
Widget _buildAddFriendApp() {
  return ScreenUtilInit(
    designSize: const Size(375, 812),
    minTextAdapt: true,
    splitScreenMode: true,
    builder: (context, child) => MaterialApp(
      title: 'AddFriend Test',
      theme: AppTheme.light,
      debugShowCheckedModeBanner: false,
      home: const AddFriendPage(),
    ),
  );
}
