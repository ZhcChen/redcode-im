import 'package:app/shell/app_shell.dart';
import 'package:app/shell/desktop/desktop_app_shell.dart';
import 'package:app/shell/mobile/mobile_app_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'shell dispatcher selects mobile and desktop layouts by capability',
    (tester) async {
      const pages = [Text('聊天'), Text('联系人'), Text('发现'), Text('我的')];

      await tester.pumpWidget(
        const MaterialApp(
          home: AppShell(
            forceDesktop: false,
            mobilePages: pages,
            desktopPages: pages,
          ),
        ),
      );
      expect(find.byType(MobileAppShell), findsOneWidget);

      await tester.pumpWidget(
        const MaterialApp(
          home: AppShell(
            forceDesktop: true,
            mobilePages: pages,
            desktopPages: pages,
          ),
        ),
      );
      expect(find.byType(DesktopAppShell), findsOneWidget);
      expect(find.byType(NavigationRail), findsOneWidget);
    },
  );
}
