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

void main() {
  patrolTest(
    '双设备私聊实时互发',
    config: const PatrolTesterConfig(
      visibleTimeout: Duration(seconds: 300),
      printLogs: true,
    ),
    ($) async {
      expect(role, anyOf('a', 'b'));
      expect(account, isNotEmpty);
      expect(peerAccount, isNotEmpty);
      expect(marker, isNotEmpty);
      final messagePrefix = 'dual-$role-';
      // 编排脚本依赖该行确认运行中的 App 确实使用了本端编译参数。
      $.log(
        'DUAL_IDENTITY role=$role account=$account marker=$marker '
        'prefix=$messagePrefix peer=$peerAccount',
      );

      final preferences = await SharedPreferences.getInstance();
      await preferences.setBool('user_agreed_to_terms', true);
      await $.pumpWidget(_buildTestApp());
      await $.pump(const Duration(milliseconds: 800));
      await $(TextField).at(0).enterText(account);
      await $(TextField).at(1).enterText(password);
      await $('登录账号').tap();
      await $('联系人').waitUntilVisible();
      await $('联系人').tap();
      await $(peerAccount).waitUntilVisible();
      await $(peerAccount).tap();
      await $('发送消息').waitUntilVisible();
      await $('发送消息').tap();
      await $(const ValueKey('chat-input-text-field')).waitUntilVisible();
      $.log('DUAL_READY role=$role account=$account marker=$marker');

      final messageA = 'dual-a-$marker';
      final messageB = 'dual-b-$marker';
      if (role == 'a') {
        await $.pump(const Duration(seconds: 2));
        await $(const ValueKey('chat-input-text-field')).enterText(messageA);
        await $(const ValueKey('chat-input-send-button')).tap();
        await $(messageA).waitUntilVisible();
        await $(messageB).waitUntilVisible();
        await $(
          const ValueKey('message-delivery-status-read'),
        ).waitUntilVisible();
      } else {
        await $(messageA).waitUntilVisible();
        await $(const ValueKey('chat-input-text-field')).enterText(messageB);
        await $(const ValueKey('chat-input-send-button')).tap();
        await $(messageB).waitUntilVisible();
        await $(
          const ValueKey('message-delivery-status-read'),
        ).waitUntilVisible();
      }
    },
  );
}
