import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/widgets/app_badge.dart';
import 'package:frontend/features/chat/models/chat_model.dart';
import 'package:frontend/features/chat/widgets/chat_list_item.dart';

Widget _buildHarness(Widget child) {
  return MaterialApp(home: Scaffold(body: child));
}

Chat _buildChat({
  required ChatType type,
  required String name,
  required String lastMessage,
  int unreadCount = 0,
  Map<String, dynamic>? extra,
}) {
  return Chat(
    id: 'chat-1',
    roomId: 'room-1',
    name: name,
    type: type,
    lastMessage: lastMessage,
    lastMessageTime: DateTime.now(),
    unreadCount: unreadCount,
    extra: extra,
  );
}

void main() {
  testWidgets('single chat title prefers friend remark fields', (tester) async {
    final chat = _buildChat(
      type: ChatType.single,
      name: 'fallback-name',
      lastMessage: 'hello',
      extra: {'friend_remark': '备注名A'},
    );

    await tester.pumpWidget(
      _buildHarness(
        ChatListItem(
          chat: chat,
          avatarBuilder: (_) => const SizedBox(key: Key('avatar')),
          onTap: () {},
        ),
      ),
    );

    expect(find.text('备注名A'), findsOneWidget);
    expect(find.text('fallback-name'), findsNothing);
    expect(find.byKey(const Key('avatar')), findsOneWidget);
  });

  testWidgets('favorite chat shows hint text and hides unread badge', (
    tester,
  ) async {
    final chat = _buildChat(
      type: ChatType.favorite,
      name: '我的收藏',
      lastMessage: '',
      unreadCount: 8,
    );

    await tester.pumpWidget(
      _buildHarness(
        ChatListItem(
          chat: chat,
          avatarBuilder: (_) => const SizedBox(),
          onTap: () {},
        ),
      ),
    );

    expect(find.text('将消息转发到这里即可保存'), findsOneWidget);
    expect(find.byType(AppBadge), findsNothing);
  });

  testWidgets('non-favorite chat with unreadCount shows unread badge', (
    tester,
  ) async {
    final chat = _buildChat(
      type: ChatType.group,
      name: '开发群',
      lastMessage: 'new message',
      unreadCount: 3,
    );

    await tester.pumpWidget(
      _buildHarness(
        ChatListItem(
          chat: chat,
          avatarBuilder: (_) => const SizedBox(),
          onTap: () {},
          showBottomDivider: true,
        ),
      ),
    );

    expect(find.byType(AppBadge), findsOneWidget);
    expect(find.byType(Divider), findsOneWidget);
  });
}
