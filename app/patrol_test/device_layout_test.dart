import 'package:app/core/routing/app_router.dart';
import 'package:app/core/theme/app_theme.dart';
import 'package:app/features/auth/login_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';
import 'package:shared_preferences/shared_preferences.dart';

const account = String.fromEnvironment('LAYOUT_ACCOUNT');
const peerAccount = String.fromEnvironment('LAYOUT_PEER_ACCOUNT');
const password = String.fromEnvironment('LAYOUT_PASSWORD');

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
    '聊天 composer 长内容布局与焦点优先返回',
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

      final input = find.byKey(const ValueKey('chat-input-text-field'));
      final send = find.byKey(const ValueKey('chat-input-send-button'));
      await $(const ValueKey('chat-input-text-field')).waitUntilVisible();
      final inputContext = $.tester.element(input);
      await $.tester.tap(input);
      await $.pump();
      expect(
        $.tester
            .state<EditableTextState>(find.byType(EditableText))
            .widget
            .focusNode
            .hasFocus,
        isTrue,
      );
      await $.tester.enterText(
        input,
        '聊天布局验收：这是一段足够长的输入内容，用于验证多行 composer 和发送按钮保持在设备边界内。',
      );
      await $.pump(const Duration(milliseconds: 300));

      expect(send, findsOneWidget);
      final screenHeight = MediaQuery.sizeOf(inputContext).height;
      expect($.tester.getBottomRight(send).dy, lessThanOrEqualTo(screenHeight));

      await $.tester.tap(find.byIcon(Icons.arrow_back_ios_new_rounded).first);
      await $.pump(const Duration(milliseconds: 300));
      expect(input, findsOneWidget);
      expect(
        $.tester
            .state<EditableTextState>(find.byType(EditableText))
            .widget
            .focusNode
            .hasFocus,
        isFalse,
      );

      await $.tester.tap(find.byIcon(Icons.arrow_back_ios_new_rounded).first);
      await $.pumpAndSettle();
      expect(input, findsNothing);
      expect($(peerAccount), findsWidgets);
    },
  );
}
