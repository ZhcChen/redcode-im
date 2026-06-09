import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/core/widgets/tip_dialog.dart';

void main() {
  testWidgets('showConfirm returns true on confirm and false on cancel', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: SizedBox())),
    );
    final context = tester.element(find.byType(SizedBox));

    final confirmFuture = TipDialog.showConfirm(
      context,
      title: '提示',
      content: '确认提交吗？',
    );

    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ElevatedButton, '确定'));
    await tester.pumpAndSettle();
    expect(await confirmFuture, isTrue);

    final cancelFuture = TipDialog.showConfirm(
      context,
      title: '提示',
      content: '确认取消吗？',
    );

    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(OutlinedButton, '取消'));
    await tester.pumpAndSettle();
    expect(await cancelFuture, isFalse);
  });

  testWidgets('showConfirm keeps dialog open when onConfirm returns false', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: SizedBox())),
    );
    final context = tester.element(find.byType(SizedBox));

    final future = TipDialog.showConfirm(
      context,
      title: '二次确认',
      content: '需要服务端确认后才能关闭',
      onConfirm: () async => false,
    );

    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ElevatedButton, '确定'));
    await tester.pumpAndSettle();

    expect(find.text('二次确认'), findsOneWidget);

    await tester.tap(find.widgetWithText(OutlinedButton, '取消'));
    await tester.pumpAndSettle();

    expect(await future, isFalse);
  });
}
