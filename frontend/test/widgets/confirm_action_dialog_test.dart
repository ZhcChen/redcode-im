import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/settings/widgets/confirm_action_dialog.dart';

void main() {
  testWidgets('confirm button stays disabled until keyword matches exactly', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: SizedBox())),
    );

    final context = tester.element(find.byType(SizedBox));
    final future = showConfirmActionDialog(
      context,
      title: '删除账号',
      message: '请输入 DELETE 继续',
      confirmationKeyword: 'DELETE',
    );

    await tester.pumpAndSettle();

    ElevatedButton confirmButton() =>
        tester.widget<ElevatedButton>(find.byType(ElevatedButton));

    expect(confirmButton().onPressed, isNull);

    await tester.enterText(find.byType(TextField), 'delete');
    await tester.pump();
    expect(confirmButton().onPressed, isNull);

    await tester.enterText(find.byType(TextField), 'DELETE');
    await tester.pump();
    expect(confirmButton().onPressed, isNotNull);

    await tester.tap(find.widgetWithText(ElevatedButton, '确认'));
    await tester.pumpAndSettle();

    expect(await future, isTrue);
  });

  testWidgets('cancel button returns false', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: SizedBox())),
    );

    final context = tester.element(find.byType(SizedBox));
    final future = showConfirmActionDialog(
      context,
      title: '退出登录',
      message: '确认退出？',
    );

    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(TextButton, '取消'));
    await tester.pumpAndSettle();

    expect(await future, isFalse);
  });
}
