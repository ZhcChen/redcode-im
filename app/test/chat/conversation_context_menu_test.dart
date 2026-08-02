import 'package:app/features/chat/models/chat_model.dart';
import 'package:app/features/chat/widgets/conversation_context_menu.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('menu exposes named actions and returns selected action', (
    tester,
  ) async {
    ConversationMenuAction? selected;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                selected = await showConversationContextMenu(
                  context: context,
                  chatName: '产品讨论群',
                  anchor: const Offset(790, 590),
                  isPinned: false,
                  notificationMode: ChatNotificationMode.all,
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

    expect(find.bySemanticsLabel('产品讨论群 会话操作'), findsOneWidget);
    expect(find.text('置顶会话'), findsOneWidget);
    expect(find.text('仅提及'), findsOneWidget);
    expect(find.text('静音'), findsOneWidget);
    expect(find.text('归档会话'), findsOneWidget);

    final menuRect = tester.getRect(find.byKey(conversationContextMenuKey));
    final screenSize = tester.view.physicalSize / tester.view.devicePixelRatio;
    expect(menuRect.left, greaterThanOrEqualTo(12));
    expect(menuRect.top, greaterThanOrEqualTo(12));
    expect(menuRect.right, lessThanOrEqualTo(screenSize.width - 12));
    expect(menuRect.bottom, lessThanOrEqualTo(screenSize.height - 12));

    await tester.tap(find.text('仅提及'));
    await tester.pumpAndSettle();
    expect(selected, ConversationMenuAction.mentions);
  });

  testWidgets('active notification mode is marked selected', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showConversationContextMenu(
                context: context,
                chatName: 'Alice',
                anchor: const Offset(40, 80),
                isPinned: true,
                notificationMode: ChatNotificationMode.muted,
              ),
              child: const Text('打开'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('打开'));
    await tester.pumpAndSettle();

    expect(find.text('取消置顶'), findsOneWidget);
    final mutedButton = tester.widget<TextButton>(
      find.widgetWithText(TextButton, '静音'),
    );
    expect(mutedButton.style?.backgroundColor?.resolve({}), isNotNull);
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
              onPressed: () => showConversationContextMenu(
                context: context,
                chatName: 'Alice',
                anchor: const Offset(40, 80),
                isPinned: false,
                notificationMode: ChatNotificationMode.all,
              ),
              child: const Text('打开'),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(triggerFocusNode.hasFocus, isTrue);

    await tester.tap(find.text('打开'));
    await tester.pumpAndSettle();
    expect(find.byKey(conversationContextMenuKey), findsOneWidget);
    expect(triggerFocusNode.hasFocus, isFalse);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    expect(find.byKey(conversationContextMenuKey), findsNothing);
    expect(triggerFocusNode.hasFocus, isTrue);
  });
}
