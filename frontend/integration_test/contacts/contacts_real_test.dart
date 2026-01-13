import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:patrol/patrol.dart';

import 'package:frontend/features/contacts/contacts_page.dart';
import 'package:frontend/core/theme/app_theme.dart';

/// 联系人页面测试 (J3 路径)
///
/// 直接启动 ContactsPage，验证 UI 元素和交互。
void main() {
  patrolTest(
    'CONT-001: 联系人页面 UI 验证',
    ($) async {
      await $.pumpWidgetAndSettle(_buildContactsApp());

      // 等待页面加载完成（可能有网络请求）
      for (int i = 0; i < 10; i++) {
        await $.pump(const Duration(seconds: 1));
        // 检查是否加载完成（不再显示 loading）
        if ($('联系人').exists && !$(CircularProgressIndicator).exists) {
          break;
        }
      }

      // 验证页面标题
      expect($('联系人'), findsOneWidget);

      // 验证搜索栏
      expect($('搜索添加好友'), findsOneWidget);
      expect($('去添加'), findsOneWidget);

      // 验证功能入口（等待加载完成后才会显示）
      final hasNewFriends = $('新的朋友').exists;
      final hasGroups = $('群聊').exists;

      // 至少应该显示其中一个，或者显示空状态/错误状态
      final hasEmptyState = $('还没有好友').exists;
      final hasErrorState = $('联系人加载失败').exists;

      expect(hasNewFriends || hasGroups || hasEmptyState || hasErrorState, isTrue);
    },
    config: PatrolTesterConfig(
      settleTimeout: const Duration(seconds: 10),
    ),
  );

  patrolTest(
    'CONT-002: 联系人页面添加按钮',
    ($) async {
      await $.pumpWidgetAndSettle(_buildContactsApp());
      await $.pump(const Duration(seconds: 1));

      // 验证添加按钮存在
      final addButton = $(Icons.add_circle_outline);
      expect(addButton, findsOneWidget);

      // 验证「去添加」按钮
      final goAddButton = $('去添加');
      expect(goAddButton, findsOneWidget);
    },
    config: PatrolTesterConfig(
      settleTimeout: const Duration(seconds: 10),
    ),
  );

  patrolTest(
    'CONT-003: 新的朋友入口',
    ($) async {
      await $.pumpWidgetAndSettle(_buildContactsApp());
      await $.pump(const Duration(seconds: 1));

      // 找到「新的朋友」入口
      final newFriendsEntry = $('新的朋友');
      expect(newFriendsEntry, findsOneWidget);

      // 验证有箭头图标（表示可点击进入）
      final chevronIcons = $(Icons.chevron_right);
      expect(chevronIcons.exists, isTrue);
    },
    config: PatrolTesterConfig(
      settleTimeout: const Duration(seconds: 10),
    ),
  );

  patrolTest(
    'CONT-004: 群聊入口',
    ($) async {
      await $.pumpWidgetAndSettle(_buildContactsApp());
      await $.pump(const Duration(seconds: 1));

      // 找到「群聊」入口
      final groupEntry = $('群聊');
      expect(groupEntry, findsOneWidget);
    },
    config: PatrolTesterConfig(
      settleTimeout: const Duration(seconds: 10),
    ),
  );

  patrolTest(
    'CONT-005: 空联系人状态',
    ($) async {
      await $.pumpWidgetAndSettle(_buildContactsApp());
      await $.pump(const Duration(seconds: 2));

      // 检查是否显示空状态（没有好友时）
      final hasEmptyState = $('还没有好友').exists;
      final hasFriends = $(ListTile).evaluate().length > 2; // 排除固定的两个入口

      // 应该是其中一种状态
      expect(hasEmptyState || hasFriends, isTrue);

      if (hasEmptyState) {
        expect($('点击右上角添加好友，开始聊天吧'), findsOneWidget);
      }
    },
    config: PatrolTesterConfig(
      settleTimeout: const Duration(seconds: 10),
    ),
  );
}

/// 构建联系人页测试应用
Widget _buildContactsApp() {
  return ScreenUtilInit(
    designSize: const Size(375, 812),
    minTextAdapt: true,
    splitScreenMode: true,
    builder: (context, child) => MaterialApp(
      title: 'Contacts Test',
      theme: AppTheme.light,
      debugShowCheckedModeBanner: false,
      home: const ContactsPage(),
    ),
  );
}
