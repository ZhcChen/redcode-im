import 'package:app/features/settings/account_security_page.dart';
import 'package:app/features/settings/settings_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'settings is a secondary navigation page without profile actions',
    (tester) async {
      await tester.pumpWidget(const MaterialApp(home: SettingsPage()));

      expect(find.text('账号与安全'), findsOneWidget);
      expect(find.text('聊天'), findsOneWidget);
      expect(find.text('隐私协议'), findsOneWidget);
      expect(find.text('关于 RedCode IM'), findsOneWidget);
      expect(find.text('修改昵称'), findsNothing);
      expect(find.text('退出登录'), findsNothing);
      expect(find.text('注销账号'), findsNothing);

      await tester.tap(find.text('账号与安全'));
      await tester.pumpAndSettle();
      expect(find.byType(AccountSecurityPage), findsOneWidget);
    },
  );
}
