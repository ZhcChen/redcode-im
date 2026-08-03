import 'package:app/core/routing/app_router.dart';
import 'package:app/core/theme/app_theme.dart';
import 'package:app/features/auth/login_page.dart';
import 'package:app/features/contacts/contacts_page.dart';
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

Future<void> _loginAndOpenContacts(PatrolIntegrationTester $) async {
  final preferences = await SharedPreferences.getInstance();
  await preferences.setBool('user_agreed_to_terms', true);
  await $.pumpWidget(_buildTestApp());
  await $.pump(const Duration(milliseconds: 800));
  await $(TextField).at(0).enterText(account);
  await $(TextField).at(1).enterText(password);
  await $('登录账号').tap();
  await $('联系人').waitUntilVisible();
  await $('联系人').tap();
  await $('新的朋友').waitUntilVisible();
}

Future<void> _openRequests(PatrolIntegrationTester $) async {
  await $('新的朋友').tap();
  await $('新的好友请求').waitUntilVisible();
}

Future<void> _waitForIncomingRequest(PatrolIntegrationTester $) async {
  final requestKey = ValueKey('friend-request-incoming-$peerAccount');
  for (var attempt = 0; attempt < 60; attempt += 1) {
    if (find.byKey(requestKey).evaluate().isNotEmpty) return;
    $.tester.state<NavigatorState>(find.byType(Navigator).first).pop();
    await $.pumpAndSettle();
    await _openRequests($);
    await $.pump(const Duration(seconds: 1));
  }
  fail('未在限时内收到 $peerAccount 的好友申请');
}

Future<void> _waitForContact(PatrolIntegrationTester $) async {
  for (var attempt = 0; attempt < 60; attempt += 1) {
    if (find.textContaining(peerAccount).evaluate().isNotEmpty) return;
    final state = $.tester.state<ContactsPageState>(find.byType(ContactsPage));
    await state.refreshContacts(force: true);
    await $.pump(const Duration(seconds: 1));
  }
  fail('未在限时内恢复联系人 $peerAccount');
}

void main() {
  patrolTest(
    '双 iOS Simulator 联系人申请备注删除闭环',
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
        'prefix=contact-$role- peer=$peerAccount',
      );

      await _loginAndOpenContacts($);

      if (role == 'b') {
        await _openRequests($);
        $.log('DUAL_READY role=b account=$account marker=$marker');
        await Future<void>.delayed(const Duration(seconds: 90));
        await _waitForIncomingRequest($);
        await $(
          ValueKey('friend-request-accept-$peerAccount'),
        ).waitUntilVisible();
        await $(ValueKey('friend-request-accept-$peerAccount')).tap();
        await $('已添加好友').waitUntilVisible();
        $.tester.state<NavigatorState>(find.byType(Navigator).first).pop();
        await $.pumpAndSettle();
        await _waitForContact($);
        $.log('DUAL_CONTACT_COMPLETE role=b marker=$marker');
        return;
      }

      await _waitForContact($);
      await $.tester.tap(find.textContaining(peerAccount).first);
      await $.pumpAndSettle();
      await $('联系人名片').waitUntilVisible();
      final remark = 'remark-${marker.split('-').first}';
      await $(const ValueKey('contact-detail-remark')).tap();
      await $(TextFormField).enterText(remark);
      await $('保存').tap();
      await $('备注已更新').waitUntilVisible();
      $.tester.state<NavigatorState>(find.byType(Navigator).first).pop();
      await $.pumpAndSettle();
      await $(remark).waitUntilVisible();

      await $(remark).tap();
      await $(const ValueKey('contact-detail-delete')).waitUntilVisible();
      await $(const ValueKey('contact-detail-delete')).tap();
      await $('删除好友').waitUntilVisible();
      await $('删除').last.tap();
      await $('新的朋友').waitUntilVisible();
      expect(find.text(remark), findsNothing);

      await $(const ValueKey('contacts-add-button')).tap();
      await $(const ValueKey('friend-search-field')).enterText(peerAccount);
      await $(const ValueKey('friend-search-button')).tap();
      await $(ValueKey('friend-request-send-$peerAccount')).waitUntilVisible();
      await $(ValueKey('friend-request-send-$peerAccount')).tap();
      await $('添加好友').waitUntilVisible();
      await $('发送').tap();
      await $('等待确认').waitUntilVisible();

      $.tester.state<NavigatorState>(find.byType(Navigator).first).pop();
      await $.pumpAndSettle();
      await _waitForContact($);
      $.log('DUAL_CONTACT_COMPLETE role=a marker=$marker');
    },
  );
}
