import 'package:app/features/auth/models/auth_user.dart';
import 'package:app/features/mine/mine_page.dart';
import 'package:app/features/mine/profile_page.dart';
import 'package:app/features/settings/settings_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _user = AuthUser(
  id: 'user-1',
  username: 'alice',
  nickname: 'Alice',
  email: 'alice@example.com',
  status: 'active',
);

void main() {
  testWidgets('loads identity and opens profile and settings entries', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: MinePage(loadUser: () async => _user)),
    );
    await tester.pumpAndSettle();

    expect(find.text('我的'), findsOneWidget);
    expect(find.text('Alice'), findsOneWidget);
    expect(find.text('@alice'), findsOneWidget);
    expect(find.text('账号与安全'), findsOneWidget);
    expect(find.text('设置'), findsOneWidget);

    await tester.tap(find.byKey(const Key('mine-profile-entry')));
    await tester.pumpAndSettle();
    expect(find.byType(ProfilePage), findsOneWidget);
    expect(find.text('alice@example.com'), findsOneWidget);

    await tester.tap(find.byTooltip('返回'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('mine-settings-entry')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(SettingsPage), findsOneWidget);
  });

  testWidgets('shows retry state after identity loading failure', (
    tester,
  ) async {
    var attempts = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: MinePage(
          loadUser: () async {
            attempts++;
            if (attempts == 1) throw Exception('offline');
            return _user;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('无法加载个人信息'), findsOneWidget);
    await tester.tap(find.text('重新加载'));
    await tester.pumpAndSettle();

    expect(find.text('Alice'), findsOneWidget);
    expect(attempts, 2);
  });
}
