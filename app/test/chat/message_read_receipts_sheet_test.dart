import 'package:app/core/services/message_service.dart';
import 'package:app/features/chat/models/message_model.dart';
import 'package:app/features/chat/models/message_reader.dart';
import 'package:app/features/chat/widgets/message_read_receipts_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'read and unread tabs derive member difference excluding sender',
    (tester) async {
      final message = Message(
        id: 'm1',
        roomId: 'r1',
        senderId: 'sender',
        senderUsername: 'sender',
        senderName: '发送者',
        content: 'hello',
        type: MessageType.text,
        status: MessageStatus.read,
        timestamp: DateTime(2026, 8, 2),
        isSelf: true,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MessageReadReceiptsSheet(
              message: message,
              loadReaders: ({required bool forceRefresh}) async => [
                MessageReader(
                  userId: 'read-user',
                  username: 'alice',
                  nickname: 'Alice',
                  readAt: DateTime.now(),
                ),
              ],
              loadMembers: () async => [
                {'user_id': 'sender', 'username': 'sender'},
                {
                  'user_id': 'read-user',
                  'username': 'alice',
                  'nickname': 'Alice',
                },
                {
                  'user_id': 'unread-user',
                  'username': 'bob',
                  'nickname': 'Bob',
                },
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('已读 1'), findsOneWidget);
      expect(find.text('未读 1'), findsOneWidget);
      expect(find.text('Alice'), findsOneWidget);
      expect(find.text('发送者'), findsNothing);

      await tester.tap(find.text('未读 1'));
      await tester.pumpAndSettle();
      expect(find.text('Bob'), findsOneWidget);
      expect(find.text('尚未阅读'), findsOneWidget);
      expect(find.text('Alice'), findsNothing);
    },
  );

  testWidgets('load failure exposes retry action', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MessageReadReceiptsSheet(
            message: Message(
              id: 'm1',
              roomId: 'r1',
              senderId: 'sender',
              senderUsername: 'sender',
              senderName: '发送者',
              content: 'hello',
              type: MessageType.text,
              status: MessageStatus.read,
              timestamp: DateTime(2026, 8, 2),
              isSelf: true,
            ),
            loadReaders: ({required bool forceRefresh}) async =>
                throw Exception('network down'),
            loadMembers: () async => const [],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('阅读状态获取失败'), findsOneWidget);
    expect(find.text('重试'), findsOneWidget);
  });
}
