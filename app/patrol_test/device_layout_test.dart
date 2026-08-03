import 'package:app/core/routing/app_router.dart';
import 'package:app/core/theme/app_theme.dart';
import 'package:app/core/widgets/im_tab_bar.dart';
import 'package:app/features/auth/login_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter/services.dart';
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

void _expectBelowTopSafeArea(
  PatrolIntegrationTester $,
  Finder finder,
  EdgeInsets padding,
) {
  expect($.tester.getTopLeft(finder).dy, greaterThanOrEqualTo(padding.top));
}

void _expectAboveBottomSafeArea(
  PatrolIntegrationTester $,
  Finder finder,
  Size screenSize,
  EdgeInsets padding,
) {
  expect(
    $.tester.getBottomRight(finder).dy,
    lessThanOrEqualTo(screenSize.height - padding.bottom),
  );
}

Future<MediaQueryData> _waitForOrientation(
  PatrolIntegrationTester $,
  Orientation orientation,
) async {
  for (var attempt = 0; attempt < 30; attempt++) {
    await $.pump(const Duration(milliseconds: 100));
    final context = $.tester.element(find.byType(MaterialApp));
    final mediaQuery = MediaQuery.of(context);
    if (mediaQuery.orientation == orientation) return mediaQuery;
  }
  fail('设备未在 3 秒内切换到 ${orientation.name}');
}

void main() {
  patrolTest(
    '系统安全区、横竖屏恢复、聊天 composer 长内容布局与焦点优先返回',
    config: const PatrolTesterConfig(
      visibleTimeout: Duration(seconds: 60),
      printLogs: true,
    ),
    ($) async {
      addTearDown(() async {
        await SystemChrome.setPreferredOrientations(DeviceOrientation.values);
      });
      expect(account, isNotEmpty);
      expect(peerAccount, isNotEmpty);
      expect(password, isNotEmpty);

      final preferences = await SharedPreferences.getInstance();
      await preferences.setBool('user_agreed_to_terms', true);
      await $.pumpWidget(_buildTestApp());
      await $.pump(const Duration(milliseconds: 800));
      final rootContext = $.tester.element(find.byType(MaterialApp));
      final screenSize = MediaQuery.sizeOf(rootContext);
      final safePadding = MediaQuery.paddingOf(rootContext);
      expect(safePadding.top, greaterThan(0));
      expect(safePadding.bottom, greaterThan(0));
      _expectBelowTopSafeArea($, find.text('你好！'), safePadding);

      await $(TextField).at(0).enterText(account);
      await $(TextField).at(1).enterText(password);
      await $('登录账号').tap();
      await $('联系人').waitUntilVisible();
      expect(find.byType(ImTabBar), findsOneWidget);
      _expectAboveBottomSafeArea(
        $,
        find.descendant(of: find.byType(ImTabBar), matching: find.text('我的')),
        screenSize,
        safePadding,
      );
      await $('联系人').tap();
      await $(peerAccount).waitUntilVisible();
      await $(peerAccount).tap();
      await $('发送消息').waitUntilVisible();
      await $('发送消息').tap();

      final input = find.byKey(const ValueKey('chat-input-text-field'));
      final send = find.byKey(const ValueKey('chat-input-send-button'));
      await $(const ValueKey('chat-input-text-field')).waitUntilVisible();
      _expectBelowTopSafeArea($, find.text(peerAccount).first, safePadding);
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
      _expectAboveBottomSafeArea($, send, screenSize, safePadding);

      await SystemChrome.setPreferredOrientations(const [
        DeviceOrientation.landscapeLeft,
      ]);
      final landscape = await _waitForOrientation($, Orientation.landscape);
      expect(landscape.size.width, greaterThan(landscape.size.height));
      expect(find.text(peerAccount), findsWidgets);
      expect(
        $.tester
            .widget<EditableText>(find.byType(EditableText))
            .controller
            .text,
        contains('聊天布局验收'),
      );
      _expectBelowTopSafeArea(
        $,
        find.text(peerAccount).first,
        landscape.padding,
      );
      _expectAboveBottomSafeArea($, send, landscape.size, landscape.padding);

      await SystemChrome.setPreferredOrientations(const [
        DeviceOrientation.portraitUp,
      ]);
      final restoredPortrait = await _waitForOrientation(
        $,
        Orientation.portrait,
      );
      expect(
        restoredPortrait.size.height,
        greaterThan(restoredPortrait.size.width),
      );
      expect(
        $.tester
            .widget<EditableText>(find.byType(EditableText))
            .controller
            .text,
        contains('聊天布局验收'),
      );

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

      final navigator = $.tester.state<NavigatorState>(
        find.byType(Navigator).first,
      );
      navigator.pop();
      await $.pumpAndSettle();
      await $('我的').tap();
      await $(const Key('mine-settings-entry')).waitUntilVisible();
      await $(const Key('mine-settings-entry')).tap();
      await $('聊天背景、贴纸与本地存储').waitUntilVisible();
      _expectBelowTopSafeArea($, find.text('设置'), safePadding);
      await $.tester.ensureVisible(find.text('关于 RedCode IM'));
      await $.pumpAndSettle();
      _expectAboveBottomSafeArea(
        $,
        find.text('关于 RedCode IM'),
        screenSize,
        safePadding,
      );
    },
  );
}
