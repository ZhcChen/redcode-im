import 'package:app/core/routing/app_router.dart';
import 'package:app/core/services/websocket_service.dart';
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

Future<void> _openPeerChat(PatrolIntegrationTester $) async {
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
}

Future<void> _waitForAuthenticated(PatrolIntegrationTester $) async {
  for (var attempt = 0; attempt < 60; attempt += 1) {
    if (WebSocketService.instance.status == ConnectionStatus.authenticated) {
      return;
    }
    await $.pump(const Duration(milliseconds: 500));
  }
  fail('App 回到前台后 WebSocket 未重新认证');
}

void main() {
  patrolTest(
    '双设备前后台重连与离线消息恢复',
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

      final messageA = 'offline-ready-$marker';
      final messageB = 'offline-message-$marker';
      await _openPeerChat($);
      $.log('DUAL_READY role=$role account=$account marker=$marker');

      if (role == 'b') {
        await $(messageA).waitUntilVisible();
        await $.pump(const Duration(seconds: 3));
        await $(const ValueKey('chat-input-text-field')).enterText(messageB);
        await $(const ValueKey('chat-input-send-button')).tap();
        await $(messageB).waitUntilVisible();
        return;
      }

      await $.pump(const Duration(seconds: 2));
      await $(const ValueKey('chat-input-text-field')).enterText(messageA);
      await $(const ValueKey('chat-input-send-button')).tap();
      await $(messageA).waitUntilVisible();
      await WebSocketService.instance.disconnect();
      expect(WebSocketService.instance.status, ConnectionStatus.disconnected);

      await $.platform.mobile.pressHome();
      await Future<void>.delayed(const Duration(seconds: 8));
      await $.platform.mobile.openApp();
      await _waitForAuthenticated($);
      await $(const ValueKey('chat-input-text-field')).waitUntilVisible();
      await $(messageB).waitUntilVisible();
      expect(find.text(messageB), findsOneWidget);
    },
  );
}
