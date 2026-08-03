import 'package:app/core/routing/app_router.dart';
import 'package:app/core/theme/app_theme.dart';
import 'package:app/features/auth/login_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';
import 'package:shared_preferences/shared_preferences.dart';

const role = String.fromEnvironment('DUAL_ROLE');
const account = String.fromEnvironment('DUAL_ACCOUNT');
const peerAccount = String.fromEnvironment('DUAL_PEER_ACCOUNT');
const password = String.fromEnvironment('DUAL_PASSWORD');
const marker = String.fromEnvironment('DUAL_MARKER');

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

Future<void> _openGroupDirectory(PatrolIntegrationTester $) async {
  await $('联系人').tap();
  await $('群聊').waitUntilVisible();
  await $('群聊').tap();
  await $(const ValueKey('group-search-field')).waitUntilVisible();
}

Future<void> _waitForGroup(PatrolIntegrationTester $, String groupName) async {
  for (var attempt = 0; attempt < 60; attempt += 1) {
    if (find.text(groupName).evaluate().isNotEmpty) return;
    $.tester.state<NavigatorState>(find.byType(Navigator).first).pop();
    await $.pump(const Duration(milliseconds: 250));
    await $('群聊').tap();
    await $(const ValueKey('group-search-field')).waitUntilVisible();
    await $.pump(const Duration(seconds: 1));
  }
  fail('未在限时内发现群聊 $groupName');
}

void main() {
  patrolTest(
    '双 iOS Simulator 群成员移除状态同步',
    config: const PatrolTesterConfig(
      visibleTimeout: Duration(seconds: 300),
      printLogs: true,
    ),
    ($) async {
      expect(role, anyOf('a', 'b'));
      expect(account, isNotEmpty);
      expect(peerAccount, isNotEmpty);
      expect(password, isNotEmpty);
      expect(marker, isNotEmpty);
      $.log(
        'DUAL_IDENTITY role=$role account=$account marker=$marker '
        'prefix=dual-$role- peer=$peerAccount',
      );

      final groupName = 'patrol-remove-$marker';
      final readyMessage = 'remove-ready-$marker';
      await _login($);
      await _openGroupDirectory($);

      if (role == 'b') {
        $.log('DUAL_READY role=b account=$account marker=$marker');
        await Future<void>.delayed(const Duration(seconds: 90));
        await _waitForGroup($, groupName);
        await $(groupName).first.tap();
        await $(const ValueKey('chat-input-text-field')).waitUntilVisible();
        await $(readyMessage).waitUntilVisible();
        await $(const ValueKey('group-kicked-notice')).waitUntilVisible();
        expect(
          find.byKey(const ValueKey('chat-input-text-field')),
          findsNothing,
        );
        $.log('DUAL_GROUP_MEMBER_REMOVAL_COMPLETE role=b marker=$marker');
        return;
      }

      await $('创建').tap();
      await $('创建群聊').waitUntilVisible();
      await $(TextField).at(0).enterText(groupName);
      await $('添加好友').tap();
      await $(peerAccount).waitUntilVisible();
      await $(peerAccount).tap();
      await $('确定（1）').tap();
      await $('创建').tap();
      await $(const ValueKey('chat-input-text-field')).waitUntilVisible();
      await $(const ValueKey('chat-input-text-field')).enterText(readyMessage);
      await $(const ValueKey('chat-input-send-button')).tap();
      await $(readyMessage).waitUntilVisible();

      await $(const ValueKey('chat-info-button')).tap();
      await $(const ValueKey('group-member-remove-entry')).waitUntilVisible();
      await $(const ValueKey('group-member-remove-entry')).tap();
      await $('移除群成员').waitUntilVisible();
      await $(peerAccount).tap();
      await $('移除（1）').tap();
      await $('确认移除成员').waitUntilVisible();
      await $('移除').last.tap();
      await $('已移除 1 名成员').waitUntilVisible();
      expect(find.text(peerAccount), findsNothing);
      $.log('DUAL_GROUP_MEMBER_REMOVAL_COMPLETE role=a marker=$marker');
    },
  );
}
