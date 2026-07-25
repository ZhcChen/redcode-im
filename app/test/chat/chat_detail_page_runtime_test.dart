import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/core/services/app_config_service.dart';
import 'package:app/core/services/message_service.dart';
import 'package:app/core/services/settings_service.dart';
import 'package:app/core/services/upload_policy_service.dart';
import 'package:app/core/services/websocket_service.dart';
import 'package:app/core/storage/app_config_storage.dart';
import 'package:app/features/chat/chat_detail_page_v2.dart';
import 'package:app/features/chat/models/chat_model.dart';
import 'package:app/features/chat/models/message_model.dart';
import 'package:app/features/chat/providers/chat_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

class _FakeMessageService extends ChangeNotifier implements MessageService {
  _FakeMessageService({required this.roomMessages, required this.seedChats});

  final Map<String, List<Message>> roomMessages;
  final List<Chat> seedChats;
  int sendRichMessageCalls = 0;
  String? lastSentRoomId;
  String? lastSentText;

  @override
  List<Chat> get chats => List<Chat>.from(seedChats);

  @override
  Future<List<Message>> loadCachedMessages(String roomId) async =>
      List<Message>.from(roomMessages[roomId] ?? const <Message>[]);

  @override
  Future<List<Message>> loadMessages(
    String roomId, {
    int limit = 50,
    String? beforeId,
    String? sinceId,
  }) async => List<Message>.from(roomMessages[roomId] ?? const <Message>[]);

  @override
  List<Message> getMessages(String roomId) =>
      List<Message>.from(roomMessages[roomId] ?? const <Message>[]);

  @override
  Future<void> updateChatInfo(String roomId, ChatType chatType) async {}

  @override
  Message? getPinnedMessage(String roomId) => null;

  @override
  List<Message> getPinnedMessages(String roomId) => const <Message>[];

  @override
  bool isMessagePinned(String roomId, String messageId) => false;

  @override
  int? cachedRoomMemberCount(String roomId) => null;

  @override
  Future<void> markMessagesAsRead(String roomId, String lastMessageId) async {}

  @override
  void markChatAsRead(String roomId) {}

  @override
  Future<void> sendRichMessage({
    required String roomId,
    String? text,
    List<MessageAttachmentDraft> attachments = const [],
    Message? quotedMessage,
  }) async {
    sendRichMessageCalls += 1;
    lastSentRoomId = roomId;
    lastSentText = text;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeWebSocketService extends ChangeNotifier implements WebSocketService {
  @override
  ConnectionStatus get status => ConnectionStatus.authenticated;

  @override
  Stream<TypingUpdateEvent> get onTypingUpdate =>
      const Stream<TypingUpdateEvent>.empty();

  @override
  Stream<GroupSettingsUpdatedEvent> get onGroupSettingsUpdated =>
      const Stream<GroupSettingsUpdatedEvent>.empty();

  @override
  Stream<GroupMemberChangedEvent> get onGroupMemberChanged =>
      const Stream<GroupMemberChangedEvent>.empty();

  @override
  Future<void> joinRoom(String roomId) async {}

  @override
  void setTyping(String roomId, bool isTyping) {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Message _message() {
  return Message(
    id: 'msg-1',
    roomId: 'room-1',
    senderId: 'user-1',
    senderUsername: 'alice',
    senderName: 'Alice',
    content: 'hello relay only',
    type: MessageType.text,
    status: MessageStatus.sent,
    timestamp: DateTime(2026, 4, 11, 12, 0, 0),
    isSelf: false,
  );
}

Message _messageWithQuoted({required QuotedMessage quotedMessage}) {
  return Message(
    id: 'msg-quoted',
    roomId: 'room-1',
    senderId: 'user-1',
    senderUsername: 'alice',
    senderName: 'Alice',
    content: 'reply with quote',
    type: MessageType.text,
    status: MessageStatus.sent,
    timestamp: DateTime(2026, 4, 11, 12, 0, 0),
    isSelf: false,
    quotedMessage: quotedMessage,
  );
}

ChatProvider _buildProvider(
  _FakeWebSocketService websocketService, {
  MessageRuntimeSettings runtime = const MessageRuntimeSettings(
    serverStorageMode: 'relay_only',
    contentAuditMode: 'plaintext',
  ),
  List<Message>? roomMessages,
  _FakeMessageService? messageService,
}) {
  final seedMessages = roomMessages ?? <Message>[_message()];
  final message = seedMessages.first;
  final resolvedMessageService =
      messageService ??
      _FakeMessageService(
        roomMessages: <String, List<Message>>{'room-1': seedMessages},
        seedChats: <Chat>[
          Chat(
            id: 'chat-1',
            roomId: 'room-1',
            name: 'Alice',
            type: ChatType.single,
            lastMessage: message.content,
            lastMessageTime: message.timestamp,
          ),
        ],
      );
  return ChatProvider(
    messageService: resolvedMessageService,
    webSocketService: websocketService,
    appConfigService: _FakeAppConfigService(runtime: runtime),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('file picker treats image mime as image attachment', () {
    final policy = UploadPolicy.builtinV1();

    expect(
      resolveAttachmentDraftTypeForFileMime('image/png', policy),
      MessagePartType.image,
    );
  });

  test('file picker keeps generic document mime as file attachment', () {
    final policy = UploadPolicy.builtinV1();

    expect(
      resolveAttachmentDraftTypeForFileMime('application/pdf', policy),
      MessagePartType.file,
    );
  });

  test('file picker rejects unsupported mime types', () {
    final policy = UploadPolicy.builtinV1();

    expect(
      () => resolveAttachmentDraftTypeForFileMime(
        'application/x-msdownload',
        policy,
      ),
      throwsA(isA<StateError>()),
    );
  });

  testWidgets('relay_only action menu hides unsupported message actions', (
    tester,
  ) async {
    final websocketService = _FakeWebSocketService();
    final provider = _buildProvider(websocketService);
    addTearDown(provider.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: ChatDetailPageV2(
          roomId: 'room-1',
          chatName: 'Alice',
          chatProvider: provider,
          websocketService: websocketService,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    await tester.tap(find.text('hello relay only'));
    await tester.pumpAndSettle();

    expect(find.text('复制文本'), findsOneWidget);
    expect(find.text('引用'), findsNothing);
    expect(find.text('转发'), findsNothing);
    expect(find.text('置顶'), findsNothing);
    expect(find.text('添加反应'), findsNothing);
    expect(find.text('删除'), findsNothing);
  });

  testWidgets('relay_only multi select bar hides unsupported bulk actions', (
    tester,
  ) async {
    final websocketService = _FakeWebSocketService();
    final provider = _buildProvider(websocketService);
    addTearDown(provider.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: ChatDetailPageV2(
          roomId: 'room-1',
          chatName: 'Alice',
          chatProvider: provider,
          websocketService: websocketService,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    await tester.longPress(find.text('hello relay only'));
    await tester.pumpAndSettle();

    expect(find.text('已选 1 条'), findsOneWidget);
    expect(find.text('转发'), findsNothing);
    expect(find.text('删除'), findsNothing);
  });

  testWidgets('chat input area does not show runtime notice block', (
    tester,
  ) async {
    final websocketService = _FakeWebSocketService();
    final provider = _buildProvider(
      websocketService,
      runtime: const MessageRuntimeSettings(
        serverStorageMode: 'persist',
        contentAuditMode: 'e2ee',
      ),
    );
    addTearDown(provider.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: ChatDetailPageV2(
          roomId: 'room-1',
          chatName: 'Alice',
          chatProvider: provider,
          websocketService: websocketService,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('当前配置目标：端到端加密'), findsNothing);
    expect(find.text('消息会保存在服务器，按当前配置目标不应被服务端审计。'), findsNothing);
  });

  testWidgets('sending while emoji panel is open keeps emoji panel mode', (
    tester,
  ) async {
    final websocketService = _FakeWebSocketService();
    final messageService = _FakeMessageService(
      roomMessages: <String, List<Message>>{
        'room-1': <Message>[_message()],
      },
      seedChats: <Chat>[
        Chat(
          id: 'chat-1',
          roomId: 'room-1',
          name: 'Alice',
          type: ChatType.single,
          lastMessage: 'hello relay only',
          lastMessageTime: DateTime(2026, 4, 11, 12, 0, 0),
        ),
      ],
    );
    final provider = _buildProvider(
      websocketService,
      messageService: messageService,
    );
    addTearDown(provider.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: ChatDetailPageV2(
          roomId: 'room-1',
          chatName: 'Alice',
          chatProvider: provider,
          websocketService: websocketService,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    await tester.enterText(
      find.byKey(const ValueKey('chat-input-text-field')),
      '继续发表情',
    );
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('chat-input-emoji-button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('chat-emoji-panel')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('chat-input-send-button')));
    await tester.pump();
    await tester.pump();

    expect(messageService.sendRichMessageCalls, 1);
    expect(messageService.lastSentRoomId, 'room-1');
    expect(messageService.lastSentText, '继续发表情');
    expect(find.byKey(const ValueKey('chat-emoji-panel')), findsOneWidget);

    final editableState = tester.state<EditableTextState>(
      find.byType(EditableText),
    );
    expect(editableState.widget.focusNode.hasFocus, isFalse);
  });

  testWidgets(
    'relay_only quoted jump shows local-cache-only hint when target missing',
    (tester) async {
      final websocketService = _FakeWebSocketService();
      final provider = _buildProvider(
        websocketService,
        roomMessages: <Message>[
          _messageWithQuoted(
            quotedMessage: QuotedMessage(
              id: 'missing-quoted',
              roomId: 'room-1',
              senderId: 'user-2',
              senderUsername: 'bob',
              senderName: 'Bob',
              content: 'history not cached',
              type: MessageType.text,
              isDeleted: false,
            ),
          ),
        ],
      );
      addTearDown(provider.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: ChatDetailPageV2(
            roomId: 'room-1',
            chatName: 'Alice',
            chatProvider: provider,
            websocketService: websocketService,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      await tester.tap(find.text('history not cached'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('当前模式不保存聊天记录，只能定位本地缓存中的消息'), findsOneWidget);
      await tester.pump(const Duration(seconds: 5));
    },
  );
}
