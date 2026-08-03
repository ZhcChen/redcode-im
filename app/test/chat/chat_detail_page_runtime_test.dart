import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/core/services/app_config_service.dart';
import 'package:app/core/services/message_service.dart';
import 'package:app/core/services/permission_service.dart';
import 'package:app/core/services/settings_service.dart';
import 'package:app/core/services/upload_policy_service.dart';
import 'package:app/core/services/websocket_service.dart';
import 'package:app/core/storage/app_config_storage.dart';
import 'package:app/core/storage/chat_draft_storage.dart';
import 'package:app/core/storage/token_storage.dart';
import 'package:app/features/auth/models/auth_session.dart';
import 'package:app/features/auth/models/auth_user.dart';
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

  void appendMessage(String roomId, Message message) {
    final messages = roomMessages.putIfAbsent(roomId, () => <Message>[]);
    messages.add(message);
    notifyListeners();
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

class _DeniedPermissionGateway implements PermissionGateway {
  int requestCalls = 0;
  int openSettingsCalls = 0;

  @override
  Future<AppPermissionStatus> status(AppPermission permission) async =>
      AppPermissionStatus.permanentlyDenied;

  @override
  Future<AppPermissionStatus> request(AppPermission permission) async {
    requestCalls += 1;
    return AppPermissionStatus.permanentlyDenied;
  }

  @override
  Future<bool> openSettings() async {
    openSettingsCalls += 1;
    return true;
  }
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

  test('message item key registry reuses stable key instance for same id', () {
    final registry = ChatMessageItemKeyRegistry();

    final first = registry.keyFor('msg-1');
    final second = registry.keyFor('msg-1');
    final third = registry.keyFor('msg-2');

    expect(identical(first, second), isTrue);
    expect(identical(first, third), isFalse);

    registry.retainIds(const <String>['msg-2']);
    final recreated = registry.keyFor('msg-1');
    expect(identical(first, recreated), isFalse);
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

  testWidgets('restores room draft and clears it after successful send', (
    tester,
  ) async {
    await const TokenStorage().saveSession(
      const AuthSession(
        token: 'token',
        user: AuthUser(id: 'user-self', username: 'self'),
      ),
    );
    final draftStorage = ChatDraftStorage();
    await draftStorage.save(
      accountId: 'user-self',
      roomId: 'room-1',
      text: '尚未发送的草稿',
    );
    final websocketService = _FakeWebSocketService();
    final messageService = _FakeMessageService(
      roomMessages: <String, List<Message>>{
        'room-1': <Message>[_message()],
      },
      seedChats: <Chat>[],
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
          draftStorage: draftStorage,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    final inputFinder = find.byKey(const ValueKey('chat-input-text-field'));
    expect(tester.widget<TextField>(inputFinder).controller?.text, '尚未发送的草稿');

    await tester.tap(find.byKey(const ValueKey('chat-input-send-button')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(messageService.lastSentText, '尚未发送的草稿');
    expect(tester.widget<TextField>(inputFinder).controller?.text, isEmpty);
    expect(
      await draftStorage.load(accountId: 'user-self', roomId: 'room-1'),
      isNull,
    );
  });

  testWidgets('emoji and more panels close voice panel before opening', (
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

    await tester.tap(find.byKey(const ValueKey('chat-input-voice-button')));
    await tester.pumpAndSettle();
    expect(find.text('按住录音'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('chat-input-emoji-button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('chat-emoji-panel')), findsOneWidget);
    expect(find.text('按住录音'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('chat-input-more-button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('chat-emoji-panel')), findsNothing);
    expect(find.text('按住录音'), findsNothing);
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

  testWidgets('new appended message enters with slide-up transition', (
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

    final slideTransitionCountBefore = find
        .byType(SlideTransition)
        .evaluate()
        .length;

    messageService.appendMessage(
      'room-1',
      Message(
        id: 'msg-2',
        roomId: 'room-1',
        senderId: 'user-2',
        senderUsername: 'bob',
        senderName: 'Bob',
        content: 'incoming animated message',
        type: MessageType.text,
        status: MessageStatus.sent,
        timestamp: DateTime(2026, 4, 11, 12, 0, 3),
        isSelf: false,
      ),
    );

    await tester.pump();
    await tester.pump();

    expect(find.text('incoming animated message'), findsOneWidget);
    expect(
      find.byType(SlideTransition).evaluate().length,
      slideTransitionCountBefore + 1,
    );
  });

  testWidgets('chat back button dismisses focused composer before route', (
    tester,
  ) async {
    final websocketService = _FakeWebSocketService();
    final provider = _buildProvider(websocketService);
    addTearDown(provider.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(context).push<void>(
                MaterialPageRoute<void>(
                  builder: (_) => ChatDetailPageV2(
                    roomId: 'room-1',
                    chatName: 'Alice',
                    chatProvider: provider,
                    websocketService: websocketService,
                  ),
                ),
              ),
              child: const Text('打开聊天'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('打开聊天'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 50));

    final input = find.byKey(const ValueKey('chat-input-text-field'));
    await tester.tap(input);
    await tester.pump();
    expect(
      tester
          .state<EditableTextState>(find.byType(EditableText))
          .widget
          .focusNode
          .hasFocus,
      isTrue,
    );

    await tester.tap(find.byIcon(Icons.arrow_back_ios_new_rounded).first);
    await tester.pump();
    expect(input, findsOneWidget);
    expect(
      tester
          .state<EditableTextState>(find.byType(EditableText))
          .widget
          .focusNode
          .hasFocus,
      isFalse,
    );

    await tester.tap(find.byIcon(Icons.arrow_back_ios_new_rounded).first);
    await tester.pumpAndSettle();
    expect(input, findsNothing);
    expect(find.text('打开聊天'), findsOneWidget);
  });

  testWidgets('camera action routes permanent denial to app settings', (
    tester,
  ) async {
    final websocketService = _FakeWebSocketService();
    final provider = _buildProvider(websocketService);
    final permissionGateway = _DeniedPermissionGateway();
    addTearDown(provider.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: ChatDetailPageV2(
          roomId: 'room-1',
          chatName: 'Alice',
          chatProvider: provider,
          websocketService: websocketService,
          permissionService: PermissionService(gateway: permissionGateway),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    await tester.tap(find.byKey(const ValueKey('chat-input-more-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('拍摄'));
    await tester.pumpAndSettle();

    expect(find.text('需要相机权限'), findsOneWidget);
    expect(permissionGateway.requestCalls, 0);
    await tester.tap(find.text('前往设置'));
    await tester.pumpAndSettle();
    expect(permissionGateway.openSettingsCalls, 1);
  });
}
