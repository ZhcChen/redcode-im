import 'dart:convert';
import 'dart:io';

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
const networkControlUrl = String.fromEnvironment('DUAL_NETWORK_CONTROL_URL');

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

Future<void> _setNetworkEnabled(bool enabled) async {
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 5);
  try {
    final action = enabled ? 'enable' : 'disable';
    final request = await client.getUrl(
      Uri.parse('$networkControlUrl/$action'),
    );
    final response = await request.close().timeout(const Duration(seconds: 5));
    final payload =
        jsonDecode(await response.transform(utf8.decoder).join())
            as Map<String, dynamic>;
    expect(response.statusCode, HttpStatus.ok);
    expect(payload['enabled'], enabled);
  } finally {
    client.close(force: true);
  }
}

Future<void> _waitForSocketState(
  PatrolIntegrationTester $,
  bool Function(ConnectionStatus status) predicate,
  String failure,
) async {
  for (var attempt = 0; attempt < 120; attempt += 1) {
    if (predicate(WebSocketService.instance.status)) return;
    await $.pump(const Duration(milliseconds: 500));
  }
  fail('$failure，当前状态 ${WebSocketService.instance.status}');
}

void main() {
  patrolTest(
    '双 iOS Simulator 真实网络中断与恢复',
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
      expect(networkControlUrl, isNotEmpty);
      $.log(
        'DUAL_IDENTITY role=$role account=$account marker=$marker '
        'prefix=dual-$role- peer=$peerAccount',
      );

      final readyMessage = 'network-ready-$marker';
      final offlineMessage = 'network-offline-$marker';
      await _openPeerChat($);
      $.log('DUAL_READY role=$role account=$account marker=$marker');

      if (role == 'b') {
        await $(readyMessage).waitUntilVisible();
        await $.pump(const Duration(seconds: 4));
        await $(
          const ValueKey('chat-input-text-field'),
        ).enterText(offlineMessage);
        await $(const ValueKey('chat-input-send-button')).tap();
        await $(offlineMessage).waitUntilVisible();
        $.log('DUAL_NETWORK_RECOVERY_COMPLETE role=b marker=$marker');
        return;
      }

      await $(const ValueKey('chat-input-text-field')).enterText(readyMessage);
      await $(const ValueKey('chat-input-send-button')).tap();
      await $(readyMessage).waitUntilVisible();

      await _setNetworkEnabled(false);
      await _waitForSocketState(
        $,
        (status) => status != ConnectionStatus.authenticated,
        '网络中断后 WebSocket 未掉线',
      );
      $.log('DUAL_NETWORK_DISABLED role=a marker=$marker');
      await $.pump(const Duration(seconds: 8));
      expect(find.text(offlineMessage), findsNothing);

      await _setNetworkEnabled(true);
      await _waitForSocketState(
        $,
        (status) => status == ConnectionStatus.authenticated,
        '网络恢复后 WebSocket 未重新认证',
      );
      await $(offlineMessage).waitUntilVisible();
      expect(find.text(offlineMessage), findsOneWidget);
      $.log('DUAL_NETWORK_RECOVERY_COMPLETE role=a marker=$marker');
    },
  );
}
