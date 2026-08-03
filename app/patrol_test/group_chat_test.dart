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
    await $.pumpAndSettle();
    await $('群聊').tap();
    await $(const ValueKey('group-search-field')).waitUntilVisible();
    await $.pump(const Duration(seconds: 1));
  }
  fail('未在限时内发现群聊 $groupName');
}

void main() {
  patrolTest(
    '双 iOS Simulator 群聊实时互发',
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

      final groupName = 'patrol-group-$marker';
      final messageA = 'group-a-$marker';
      final messageB = 'group-b-$marker';
      final personalMuteAck = 'group-personal-unmute-$marker';
      final globalMuteAck = 'group-global-unmute-$marker';
      await _login($);
      await _openGroupDirectory($);

      if (role == 'b') {
        $.log('DUAL_READY role=b account=$account marker=$marker');
        // A 端首次隔离构建期间保持 B 端静默，避免 Patrol 的全局日志读取器
        // 在两个 Simulator 高频交错输出时崩溃。
        await Future<void>.delayed(const Duration(seconds: 90));
        await _waitForGroup($, groupName);
        await $(groupName).first.tap();
        await $(const ValueKey('chat-input-text-field')).waitUntilVisible();
        await $(messageA).waitUntilVisible();
        await $(const ValueKey('chat-input-text-field')).enterText(messageB);
        await $(const ValueKey('chat-input-send-button')).tap();
        await $(messageB).waitUntilVisible();

        await $(const ValueKey('chat-input-disabled')).waitUntilVisible();
        expect(
          $.tester
              .widget<TextField>(
                find.byKey(const ValueKey('chat-input-text-field')),
              )
              .decoration
              ?.hintText,
          '你已被管理员禁言',
        );
        await $(const ValueKey('chat-input-enabled')).waitUntilVisible();
        await $(
          const ValueKey('chat-input-text-field'),
        ).enterText(personalMuteAck);
        await $(const ValueKey('chat-input-send-button')).tap();
        await $(personalMuteAck).waitUntilVisible();

        await $(const ValueKey('chat-input-disabled')).waitUntilVisible();
        expect(
          $.tester
              .widget<TextField>(
                find.byKey(const ValueKey('chat-input-text-field')),
              )
              .decoration
              ?.hintText,
          '当前群聊已开启全体禁言',
        );
        await $(const ValueKey('chat-input-enabled')).waitUntilVisible();
        await $(
          const ValueKey('chat-input-text-field'),
        ).enterText(globalMuteAck);
        await $(const ValueKey('chat-input-send-button')).tap();
        await $(globalMuteAck).waitUntilVisible();

        await $(const ValueKey('chat-info-button')).tap();
        await $('退出群聊').waitUntilVisible();
        $.log('DUAL_GOVERNANCE_READY role=b marker=$marker');
        await $('禁言管理').waitUntilVisible();
        $.log('DUAL_GROUP_COMPLETE role=b marker=$marker');
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
      await $(const ValueKey('chat-input-text-field')).enterText(messageA);
      await $(const ValueKey('chat-input-send-button')).tap();
      await $(messageA).waitUntilVisible();
      await $(messageB).waitUntilVisible();
      await $.pump(const Duration(seconds: 2));
      await $(
        const ValueKey('message-delivery-action-read'),
      ).waitUntilVisible();
      await $(const ValueKey('message-delivery-action-read')).last.tap();
      await $(const ValueKey('message-read-details-title')).waitUntilVisible();
      await $('已读 1').waitUntilVisible();
      await $('未读 0').waitUntilVisible();
      await $(peerAccount).waitUntilVisible();
      await $(const ValueKey('message-read-details-close')).tap();

      await $(const ValueKey('chat-info-button')).tap();
      await $(const ValueKey('group-mute-settings-entry')).waitUntilVisible();
      await $(const ValueKey('group-mute-settings-entry')).tap();
      await $(const ValueKey('group-mute-add-button')).waitUntilVisible();
      await $(const ValueKey('group-mute-add-button')).tap();
      await $(ValueKey('group-mute-candidate-$peerAccount')).waitUntilVisible();
      await $(ValueKey('group-mute-candidate-$peerAccount')).tap();
      await $(const ValueKey('group-mute-confirm-button')).waitUntilVisible();
      await $(const ValueKey('group-mute-confirm-button')).tap();
      await $(ValueKey('group-mute-record-$peerAccount')).waitUntilVisible();
      await Future<void>.delayed(const Duration(seconds: 3));
      await $(ValueKey('group-mute-unmute-$peerAccount')).tap();
      await $('确定').waitUntilVisible();
      await $('确定').tap();
      await $('暂无被禁言的成员').waitUntilVisible();
      $.tester.state<NavigatorState>(find.byType(Navigator).first).pop();
      await $.pump(const Duration(milliseconds: 350));
      $.tester.state<NavigatorState>(find.byType(Navigator).first).pop();
      await $.pump(const Duration(milliseconds: 350));
      await $(personalMuteAck).waitUntilVisible();

      await $(const ValueKey('chat-info-button')).tap();
      await $(const ValueKey('group-global-mute-switch')).waitUntilVisible();
      await $(const ValueKey('group-global-mute-switch')).tap();
      await Future<void>.delayed(const Duration(seconds: 3));
      await $(const ValueKey('group-global-mute-switch')).tap();
      await Future<void>.delayed(const Duration(seconds: 1));
      $.tester.state<NavigatorState>(find.byType(Navigator).first).pop();
      await $.pump(const Duration(milliseconds: 350));
      await $(globalMuteAck).waitUntilVisible();

      await $(const ValueKey('chat-info-button')).tap();
      await $(const ValueKey('group-admin-settings-entry')).waitUntilVisible();
      await $(const ValueKey('group-admin-settings-entry')).tap();
      await $(const ValueKey('group-admin-add-button')).waitUntilVisible();
      await $(const ValueKey('group-admin-add-button')).tap();
      await $(ValueKey('admin-candidate-$peerAccount')).waitUntilVisible();
      await $(ValueKey('admin-candidate-$peerAccount')).tap();
      await $('任命管理员').waitUntilVisible();
      await $('确定').tap();
      await $('移除').waitUntilVisible();
      $.log('DUAL_GROUP_COMPLETE role=a marker=$marker');
    },
  );
}
