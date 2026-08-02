import 'package:app/features/chat/models/chat_model.dart';
import 'package:app/features/chat/widgets/message_forward_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'filters targets, keeps multiple selections and excludes source',
    (tester) async {
      List<Chat>? result;
      final chats = [
        _chat('source', '当前会话'),
        _chat('alice', 'Alice'),
        _chat('bob', 'Bob'),
      ];
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  result = await showModalBottomSheet<List<Chat>>(
                    context: context,
                    isScrollControlled: true,
                    builder: (_) => MessageForwardSheet(
                      chats: chats,
                      previewText: '消息预览',
                      excludedRoomId: 'source',
                    ),
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
      expect(find.text('当前会话'), findsNothing);
      expect(find.text('转发给 0 个会话'), findsOneWidget);
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );

      await tester.tap(find.text('Alice'));
      await tester.pump();
      await tester.enterText(find.byType(TextField), 'bob');
      await tester.pump();
      expect(find.text('Alice'), findsNothing);
      await tester.tap(find.text('Bob'));
      await tester.pump();
      expect(find.text('转发给 2 个会话'), findsOneWidget);

      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();
      expect(result?.map((chat) => chat.name), ['Alice', 'Bob']);
    },
  );

  testWidgets('shows an empty search result for unmatched long query', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MessageForwardSheet(
            chats: [_chat('long', '这是一个非常长但仍需正确显示的会话名称')],
            previewText: '消息预览',
          ),
        ),
      ),
    );
    await tester.enterText(find.byType(TextField), '不存在的会话');
    await tester.pump();
    expect(find.text('未找到匹配的会话'), findsOneWidget);
  });
}

Chat _chat(String id, String name) => Chat(
  id: id,
  roomId: id,
  name: name,
  type: ChatType.single,
  lastMessage: '',
  lastMessageTime: DateTime(2026, 8, 2),
);
