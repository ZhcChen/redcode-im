import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:patrol/patrol.dart';

import 'package:frontend/features/chat/chat_list_page.dart';
import 'package:frontend/core/theme/app_theme.dart';

/// 聊天列表页面测试 (J4 路径)
///
/// 直接启动 ChatListPage，验证 UI 元素和交互。
void main() {
  patrolTest(
    'CHAT-001: 聊天列表页 UI 验证',
    ($) async {
      await $.pumpWidgetAndSettle(_buildChatListApp());
      await $.pump(const Duration(seconds: 1));

      // 验证搜索框存在
      expect($('搜索'), findsOneWidget);

      // 验证页面加载完成（可能显示列表或空状态）
      final hasChats = $(ListTile).exists;
      final isEmpty = $('暂无会话').exists;

      // 应该是其中一种状态
      expect(hasChats || isEmpty, isTrue);
    },
    config: PatrolTesterConfig(
      settleTimeout: const Duration(seconds: 10),
    ),
  );

  patrolTest(
    'CHAT-002: 聊天列表菜单功能',
    ($) async {
      await $.pumpWidgetAndSettle(_buildChatListApp());
      await $.pump(const Duration(seconds: 1));

      // 查找并点击菜单按钮（左上角的图标按钮）
      final menuButtons = $(GestureDetector);
      if (menuButtons.exists) {
        // 点击第一个手势检测器（菜单按钮）
        await menuButtons.first.tap();
        await $.pump(const Duration(milliseconds: 500));

        // 验证菜单选项出现
        expect($('添加好友'), findsOneWidget);
        expect($('创建群聊'), findsOneWidget);
      }
    },
    config: PatrolTesterConfig(
      settleTimeout: const Duration(seconds: 10),
    ),
  );

  patrolTest(
    'CHAT-003: 聊天列表搜索功能',
    ($) async {
      await $.pumpWidgetAndSettle(_buildChatListApp());
      await $.pump(const Duration(seconds: 1));

      // 找到搜索输入框
      final searchField = $(TextField);
      if (searchField.exists) {
        // 输入搜索关键词
        await searchField.first.enterText('测试搜索');
        await $.pump(const Duration(seconds: 1));

        // 验证搜索结果或空状态
        final hasResults = $(ListTile).exists;
        final noResults = $('未找到相关会话').exists;

        // 应该显示结果或空状态
        expect(hasResults || noResults, isTrue);

        // 清除搜索
        final clearButton = $(Icons.clear);
        if (clearButton.exists) {
          await clearButton.tap();
          await $.pump(const Duration(milliseconds: 500));
        }
      }
    },
    config: PatrolTesterConfig(
      settleTimeout: const Duration(seconds: 10),
    ),
  );

  patrolTest(
    'CHAT-004: 空聊天列表状态',
    ($) async {
      await $.pumpWidgetAndSettle(_buildChatListApp());
      await $.pump(const Duration(seconds: 2));

      // 如果没有聊天，应该显示空状态
      final isEmpty = $('暂无会话').exists;
      if (isEmpty) {
        expect($('开始一段新的聊天吧'), findsOneWidget);
      }
    },
    config: PatrolTesterConfig(
      settleTimeout: const Duration(seconds: 10),
    ),
  );
}

/// 构建聊天列表页测试应用
Widget _buildChatListApp() {
  return ScreenUtilInit(
    designSize: const Size(375, 812),
    minTextAdapt: true,
    splitScreenMode: true,
    builder: (context, child) => MaterialApp(
      title: 'ChatList Test',
      theme: AppTheme.light,
      debugShowCheckedModeBanner: false,
      home: const ChatListPage(),
    ),
  );
}
