import 'package:app/features/auth/reset_password_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('验证码输入行保持纵向居中', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: ResetPasswordPage()));
    await tester.pump();

    final row = tester.widget<Row>(
      find.byKey(const Key('reset-password-code-row')),
    );

    expect(row.crossAxisAlignment, CrossAxisAlignment.center);
  });
}
