import 'package:app/core/routing/app_router.dart';
import 'package:app/core/theme/app_theme.dart';
import 'package:app/features/auth/login_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';
import 'package:shared_preferences/shared_preferences.dart';

const account = String.fromEnvironment('PERMISSION_ACCOUNT');
const peerAccount = String.fromEnvironment('PERMISSION_PEER_ACCOUNT');
const password = String.fromEnvironment('PERMISSION_PASSWORD');

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
    'iOS 相册与麦克风永久拒绝后提供设置入口',
    config: const PatrolTesterConfig(
      visibleTimeout: Duration(seconds: 60),
      printLogs: true,
    ),
    ($) async {
      expect(account, isNotEmpty);
      expect(peerAccount, isNotEmpty);
      expect(password, isNotEmpty);

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
      await $(const ValueKey('chat-input-text-field')).enterText('');
      await $(const ValueKey('chat-input-more-button')).waitUntilVisible();

      await $(const ValueKey('chat-input-more-button')).tap();
      await $('相册').tap();
      await $('需要相册权限').waitUntilVisible();
      expect($('前往设置'), findsOneWidget);
      await $('取消').tap();

      await $(const ValueKey('chat-input-voice-button')).tap();
      await $(Icons.mic).longPress();
      await $('需要麦克风权限').waitUntilVisible();
      expect($('前往设置'), findsOneWidget);
    },
  );
}
