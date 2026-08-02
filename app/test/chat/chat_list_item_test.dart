import 'package:app/core/theme/phone_density.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/core/widgets/app_badge.dart';
import 'package:app/features/chat/models/chat_model.dart';
import 'package:app/features/chat/widgets/chat_list_item.dart';

Widget _buildHarness(Widget child, {bool enableDensity = false}) {
  return MaterialApp(
    home: Builder(
      builder: (context) {
        final body = Scaffold(body: child);
        if (!enableDensity) {
          return body;
        }
        return AdaptivePhoneDensity(child: body);
      },
    ),
  );
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

  testWidgets('1.5k phones tighten avatar box size', (tester) async {
    tester.view.physicalSize = const Size(1220, 2712);
    tester.view.devicePixelRatio = 3;

    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final chat = _buildChat(
      type: ChatType.single,
      name: 'Alice',
      lastMessage: 'hello',
    );

    await tester.pumpWidget(
      _buildHarness(
        ChatListItem(
          chat: chat,
          avatarBuilder: (_) => const SizedBox.expand(key: Key('avatar')),
          onTap: () {},
        ),
        enableDensity: true,
      ),
    );

    expect(
      tester.getSize(find.byKey(const Key('avatar'))).width,
      closeTo(56 * 0.94, 0.01),
    );
  });
}
