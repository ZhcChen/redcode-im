import 'package:app/core/routing/app_router.dart';
import 'package:app/core/theme/app_theme.dart';
import 'package:app/features/auth/login_page.dart';
import 'package:app/features/chat/group_invitations_page.dart';
import 'package:app/features/contacts/add_friend_page.dart';
import 'package:app/features/settings/deactivate_account_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';
import 'package:shared_preferences/shared_preferences.dart';

const account = String.fromEnvironment('PAGE_ACCOUNT');
const password = String.fromEnvironment('PAGE_PASSWORD');

Widget _buildTestApp() {
  return ScreenUtilInit(
    designSize: const Size(375, 812),
    minTextAdapt: true,
    splitScreenMode: true,
    builder: (context, child) => MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      onGenerateRoute: AppRouter.onGenerateRoute,
      home: const LoginPage(),
    ),
  );
}

Future<void> _login(PatrolIntegrationTester $) async {
  final preferences = await SharedPreferences.getInstance();
  await preferences.setBool('user_agreed_to_terms', true);
  await $.pumpWidget(_buildTestApp());
  await $.pump(const Duration(milliseconds: 800));
  await $(TextField).at(0).enterText(account);
  await $(TextField).at(1).enterText(password);
  await $('登录账号').tap();
  await $('联系人').waitUntilVisible();
}

Future<void> _back(PatrolIntegrationTester $) async {
  final navigator = $.tester.state<NavigatorState>(
    find.byType(Navigator).first,
  );
  expect(navigator.canPop(), isTrue);
  navigator.pop();
  await $.pumpAndSettle();
}

Future<void> _openAndBack(
  PatrolIntegrationTester $,
  Finder entry,
  Finder destination,
) async {
  await $(entry).tap();
  await $(destination).waitUntilVisible();
  await _back($);
}

void main() {
  patrolTest(
    '真实账号 P0 页面导航与滚动巡检',
    config: const PatrolTesterConfig(
      visibleTimeout: Duration(seconds: 60),
      printLogs: true,
    ),
    ($) async {
      expect(account, isNotEmpty);
      expect(password, isNotEmpty);
      await _login($);

      await $('联系人').tap();
      await $('新的朋友').waitUntilVisible();
      await _openAndBack($, find.text('新的朋友'), find.byType(AddFriendPage));
      await _openAndBack(
        $,
        find.text('群聊'),
        find.byKey(const ValueKey('group-search-field')),
      );
      await _openAndBack(
        $,
        find.text('群通知'),
        find.byType(GroupInvitationsPage),
      );

      await $('我的').tap();
      await $(const Key('mine-profile-entry')).waitUntilVisible();
      await $(const Key('mine-profile-entry')).tap();
      await $('个人资料').waitUntilVisible();
      await $(const Key('profile-edit-entry')).tap();
      await $('编辑资料').waitUntilVisible();
      await _back($);
      await $('个人资料').waitUntilVisible();
      await _back($);

      await $('账号与安全').tap();
      await $('修改密码').waitUntilVisible();
      await _openAndBack($, find.text('修改密码'), find.text('确认修改'));
      await _openAndBack(
        $,
        find.text('注销账号'),
        find.byType(DeactivateAccountPage),
      );
      await _back($);

      await $(const Key('mine-settings-entry')).tap();
      await $('聊天背景、贴纸与本地存储').waitUntilVisible();
      await $('聊天').tap();
      await $('清空聊天记录').waitUntilVisible();
      await _openAndBack($, find.text('聊天背景'), find.text('从相册选择'));
      await _openAndBack($, find.text('表情管理'), find.text('表情商店'));
      await _back($);

      await $('隐私协议').tap();
      await $('隐私政策').waitUntilVisible();
      await _back($);

      await $('关于 RedCode IM').tap();
      await $('检查').waitUntilVisible();
      await $.tester.dragUntilVisible(
        find.text('反馈'),
        find.byType(Scrollable).last,
        const Offset(0, -240),
      );
      await $('反馈').tap();
      await $('意见反馈').waitUntilVisible();
      await $.tester.dragUntilVisible(
        find.text('提交反馈'),
        find.byType(Scrollable).last,
        const Offset(0, -240),
      );
      expect(find.text('提交反馈'), findsOneWidget);
      await _back($);
      await $('检查').waitUntilVisible();
      await _back($);
      await _back($);

      await $(const Key('mine-profile-entry')).waitUntilVisible();
      $.log('PAGE_NAVIGATION_COMPLETE account=$account');
    },
  );
}
