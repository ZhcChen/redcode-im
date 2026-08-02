import 'package:app/features/settings/account_security_page.dart';
import 'package:app/features/settings/change_password_page.dart';
import 'package:app/features/settings/deactivate_account_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('password validation requires eight characters, letters and digits', () {
    expect(validateNewPassword('abc123'), '新密码至少 8 位');
    expect(validateNewPassword('abcdefgh'), '新密码必须同时包含字母和数字');
    expect(validateNewPassword('12345678'), '新密码必须同时包含字母和数字');
    expect(validateNewPassword('abcd1234'), isNull);
  });

  testWidgets('account security routes to password and deactivation pages', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: AccountSecurityPage()));

    await tester.tap(find.byKey(const Key('change-password-entry')));
    await tester.pumpAndSettle();
    expect(find.byType(ChangePasswordPage), findsOneWidget);

    await tester.tap(find.byTooltip('返回'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('deactivate-account-entry')));
    await tester.pumpAndSettle();
    expect(find.byType(DeactivateAccountPage), findsOneWidget);
  });

  testWidgets('change password submits current and validated new password', (
    tester,
  ) async {
    String? current;
    String? next;
    await tester.pumpWidget(
      MaterialApp(
        home: ChangePasswordPage(
          changePassword: (oldPassword, newPassword) async {
            current = oldPassword;
            next = newPassword;
          },
        ),
      ),
    );

    await tester.enterText(
      find.byKey(const Key('current-password-field')),
      'old-password',
    );
    await tester.enterText(
      find.byKey(const Key('new-password-field')),
      'newpass123',
    );
    await tester.enterText(
      find.byKey(const Key('confirm-password-field')),
      'newpass123',
    );
    await tester.tap(find.byKey(const Key('change-password-submit')));
    await tester.pumpAndSettle();

    expect(current, 'old-password');
    expect(next, 'newpass123');
  });

  testWidgets(
    'deactivation requires acknowledgement before final confirmation',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: DeactivateAccountPage(deactivateAccount: () async {}),
        ),
      );

      final button = tester.widget<FilledButton>(
        find.byKey(const Key('deactivate-account-submit')),
      );
      expect(button.onPressed, isNull);

      await tester.tap(find.byKey(const Key('deactivate-acknowledgement')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('deactivate-account-submit')));
      await tester.pumpAndSettle();

      expect(find.text('最终确认'), findsOneWidget);
      expect(find.textContaining('请输入“注销”'), findsOneWidget);
    },
  );
}
