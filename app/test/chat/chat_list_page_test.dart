import 'dart:convert';

import 'package:app/core/services/message_service.dart';
import 'package:app/core/services/websocket_service.dart';
import 'package:app/core/storage/token_storage.dart';
import 'package:app/features/auth/models/auth_session.dart';
import 'package:app/features/auth/models/auth_user.dart';
import 'package:app/features/chat/chat_list_page.dart';
import 'package:app/features/chat/models/chat_model.dart';
import 'package:app/features/chat/providers/chat_provider.dart';
import 'package:app/features/chat/widgets/chat_list_item.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

class _FakeTokenStorage extends TokenStorage {
  const _FakeTokenStorage();

  @override
  Future<AuthSession?> readSession() async => const AuthSession(
    token: 'test-token',
    user: AuthUser(id: 'user-1', username: 'alice'),
  );
}

class _FakeMessageService extends ChangeNotifier implements MessageService {
  _FakeMessageService(this._chats);

  final List<Chat> _chats;

  @override
  List<Chat> get chats => List<Chat>.from(_chats);

  @override
  TokenStorage get tokenStorage => const _FakeTokenStorage();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeWebSocketService extends ChangeNotifier implements WebSocketService {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets('long press opens conversation menu and updates mentions mode', (
    tester,
  ) async {
    final chat = Chat(
      id: 'chat-1',
      roomId: 'room-1',
      name: '产品讨论群',
      type: ChatType.group,
      lastMessage: '准备发布',
      lastMessageTime: DateTime(2026, 8, 2, 12),
    );
    Map<String, dynamic>? payload;
    final provider = ChatProvider(
      messageService: _FakeMessageService([chat]),
      webSocketService: _FakeWebSocketService(),
      client: MockClient((request) async {
        payload = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response('{}', 200);
      }),
    );
    addTearDown(provider.dispose);

    await tester.pumpWidget(
      MaterialApp(home: ChatListPage(chatProvider: provider)),
    );
    await tester.pump();

    await tester.longPress(find.byType(ChatListItem));
    await tester.pumpAndSettle();
    expect(find.text('归档会话'), findsOneWidget);

    await tester.tap(find.text('仅提及'));
    await tester.pumpAndSettle();

    expect(payload?['notification_settings'], 1);
    expect(
      provider.chats.single.notificationMode,
      ChatNotificationMode.mentions,
    );
  });
}
