import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/chat/models/chat_message.dart';
import 'package:frontend/features/chat/widgets/chat_message_bubble.dart';

Widget _harness(Widget child) {
  return MaterialApp(home: Scaffold(body: child));
}

void main() {
  testWidgets('system message renders center text only', (tester) async {
    final message = ChatMessage(
      id: 'm1',
      senderId: 'sys',
      senderName: 'system',
      content: '系统通知',
      timestamp: DateTime.now(),
      type: ChatMessageType.system,
    );

    await tester.pumpWidget(_harness(ChatMessageBubble(message: message)));

    expect(find.text('系统通知'), findsOneWidget);
    expect(find.text('system'), findsNothing);
  });

  testWidgets('incoming text message renders sender and body', (tester) async {
    final message = ChatMessage(
      id: 'm2',
      senderId: 'u2',
      senderName: 'Alice',
      content: '你好，今天开会吗？',
      timestamp: DateTime.now(),
      type: ChatMessageType.text,
      isSelf: false,
    );

    await tester.pumpWidget(_harness(ChatMessageBubble(message: message)));

    expect(find.text('Alice'), findsOneWidget);
    expect(find.text('你好，今天开会吗？'), findsOneWidget);
  });

  testWidgets('reaction item is tappable and callback receives key', (
    tester,
  ) async {
    String? tappedReaction;
    final message = ChatMessage(
      id: 'm3',
      senderId: 'u3',
      senderName: 'Bob',
      content: 'ok',
      timestamp: DateTime.now(),
      reactions: const [
        MessageReactionSummary(reactionKey: '👍', count: 2, hasSelf: true),
      ],
    );

    await tester.pumpWidget(
      _harness(
        ChatMessageBubble(
          message: message,
          onReactionTap: (msg, reactionKey) {
            tappedReaction = reactionKey;
          },
        ),
      ),
    );

    expect(find.text('👍'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);

    await tester.tap(find.text('👍'));
    await tester.pump();

    expect(tappedReaction, '👍');
  });
}
