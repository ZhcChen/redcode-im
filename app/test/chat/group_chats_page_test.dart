import 'package:app/core/services/app_config_service.dart';
import 'package:app/core/services/message_service.dart';
import 'package:app/core/services/settings_service.dart';
import 'package:app/core/services/websocket_service.dart';
import 'package:app/core/storage/app_config_storage.dart';
import 'package:app/features/chat/group_chats_page.dart';
import 'package:app/features/chat/models/chat_model.dart';
import 'package:app/features/chat/providers/chat_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeMessageService extends ChangeNotifier implements MessageService {
  _FakeMessageService({required List<Chat> chats})
    : _chats = List<Chat>.from(chats);

  final List<Chat> _chats;
  int fetchChatsCallCount = 0;

  @override
  List<Chat> get chats => List<Chat>.from(_chats);

  @override
  Future<List<Chat>> fetchChats({bool force = false}) async {
    fetchChatsCallCount += 1;
    return chats;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeAppConfigService extends AppConfigService {
  _FakeAppConfigService({required MessageRuntimeSettings runtime})
    : _runtime = runtime,
      super(
        storage: const AppConfigStorage(),
        settingsService: SettingsService(),
      );

  final MessageRuntimeSettings _runtime;

  @override
  MessageRuntimeSettings get currentMessageRuntime => _runtime;

  @override
  Future<MessageRuntimeSettings> getMessageRuntime() async => _runtime;
}

class _FakeWebSocketService extends ChangeNotifier implements WebSocketService {
  final ConnectionStatus _status = ConnectionStatus.disconnected;

  @override
  ConnectionStatus get status => _status;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Chat _buildChat({
  required String id,
  required String name,
  required ChatType type,
}) {
  return Chat(
    id: id,
    roomId: 'room-$id',
    name: name,
    type: type,
    lastMessage: 'last-$id',
    lastMessageTime: DateTime(2026, 7, 25, 10, 0),
  );
}

ChatProvider _buildProvider(List<Chat> chats) {
  return ChatProvider(
    messageService: _FakeMessageService(chats: chats),
    webSocketService: _FakeWebSocketService(),
    appConfigService: _FakeAppConfigService(
      runtime: MessageRuntimeSettings.defaults,
    ),
  );
}

void main() {
  testWidgets('没有群聊时仍会进入真实群聊页并展示创建入口', (tester) async {
    final provider = _buildProvider(<Chat>[
      _buildChat(id: 'single-1', name: '单聊-张三', type: ChatType.single),
    ]);

    await tester.pumpWidget(
      MaterialApp(home: GroupChatsPage(chatProvider: provider)),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('群聊'), findsOneWidget);
    expect(find.text('还没有加入任何群聊'), findsOneWidget);
    expect(find.text('创建群聊'), findsOneWidget);
  });

  testWidgets('群聊页只展示 group 类型会话', (tester) async {
    final provider = _buildProvider(<Chat>[
      _buildChat(id: 'group-1', name: '项目群', type: ChatType.group),
      _buildChat(id: 'single-1', name: '单聊-李四', type: ChatType.single),
      _buildChat(id: 'group-2', name: '测试群', type: ChatType.group),
    ]);

    await tester.pumpWidget(
      MaterialApp(home: GroupChatsPage(chatProvider: provider)),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('项目群'), findsOneWidget);
    expect(find.text('测试群'), findsOneWidget);
    expect(find.text('单聊-李四'), findsNothing);
  });
}
