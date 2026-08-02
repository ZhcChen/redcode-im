import 'package:app/features/chat/widgets/message_action_menu.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('persisted text message exposes complete action set', (
    tester,
  ) async {
    MessageAction? selected;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                selected = await showMessageActionMenu(
                  context: context,
                  anchor: const Offset(780, 580),
                  isSelf: true,
                  isTextMessage: true,
                  isDeleted: false,
                  isPinned: false,
                  isRelayOnlyMode: false,
                );
              },
              child: const Text('打开'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('打开'));
    await tester.pumpAndSettle();

    expect(find.text('复制文本'), findsOneWidget);
    expect(find.text('引用'), findsOneWidget);
    expect(find.text('转发'), findsOneWidget);
    expect(find.text('置顶'), findsOneWidget);
    expect(find.text('添加反应'), findsOneWidget);
    expect(find.text('删除'), findsOneWidget);

    final menuRect = tester.getRect(find.byKey(messageActionMenuKey));
    final screenSize = tester.view.physicalSize / tester.view.devicePixelRatio;
    expect(menuRect.left, greaterThanOrEqualTo(12));
    expect(menuRect.top, greaterThanOrEqualTo(12));
    expect(menuRect.right, lessThanOrEqualTo(screenSize.width - 12));
    expect(menuRect.bottom, lessThanOrEqualTo(screenSize.height - 12));

    await tester.tap(find.text('引用'));
    await tester.pumpAndSettle();
    expect(selected, MessageAction.quote);
  });

  testWidgets('relay-only text message only exposes local copy', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showMessageActionMenu(
                context: context,
                anchor: const Offset(40, 80),
                isSelf: false,
                isTextMessage: true,
                isDeleted: false,
                isPinned: false,
                isRelayOnlyMode: true,
              ),
              child: const Text('打开'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('打开'));
    await tester.pumpAndSettle();

    expect(find.text('复制文本'), findsOneWidget);
    expect(find.text('引用'), findsNothing);
    expect(find.text('删除'), findsNothing);
  });

  testWidgets('escape closes menu and restores trigger focus', (tester) async {
    final triggerFocusNode = FocusNode();
    addTearDown(triggerFocusNode.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              focusNode: triggerFocusNode,
              autofocus: true,
              onPressed: () => showMessageActionMenu(
                context: context,
                anchor: const Offset(40, 80),
                isSelf: false,
                isTextMessage: true,
                isDeleted: false,
                isPinned: false,
                isRelayOnlyMode: false,
              ),
              child: const Text('打开'),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('打开'));
    await tester.pumpAndSettle();
    expect(triggerFocusNode.hasFocus, isFalse);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    expect(find.byKey(messageActionMenuKey), findsNothing);
    expect(triggerFocusNode.hasFocus, isTrue);
  });
}
