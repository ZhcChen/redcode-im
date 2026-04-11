import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/services/app_config_service.dart';
import 'package:frontend/core/services/message_service.dart';
import 'package:frontend/core/services/settings_service.dart';
import 'package:frontend/core/services/websocket_service.dart';
import 'package:frontend/core/storage/app_config_storage.dart';
import 'package:frontend/features/chat/models/chat_model.dart';
import 'package:frontend/features/chat/models/message_model.dart';
import 'package:frontend/features/chat/providers/chat_provider.dart';

class _SendRichCall {
  _SendRichCall({
    required this.roomId,
    required this.text,
    required this.attachments,
    required this.quotedMessage,
  });

  final String roomId;
  final String? text;
  final List<MessageAttachmentDraft> attachments;
  final Message? quotedMessage;
}

class _ForwardCall {
  _ForwardCall({
    required this.original,
    required this.targetRoomId,
    required this.forwardInfo,
  });

  final Message original;
  final String targetRoomId;
  final ForwardInfo forwardInfo;
}

class _FakeMessageService extends ChangeNotifier implements MessageService {
  _FakeMessageService({List<Chat>? chats}) : _chats = chats ?? <Chat>[];

  List<Chat> _chats;
  final List<_SendRichCall> sendRichCalls = <_SendRichCall>[];
  final List<_ForwardCall> forwardCalls = <_ForwardCall>[];
  final List<String> pinnedCalls = <String>[];
  final List<String> unpinnedCalls = <String>[];
  final List<String> markedDeleted = <String>[];
  final List<String> markedReadCalls = <String>[];
  final List<String> addedReactionCalls = <String>[];
  final List<String> removedReactionCalls = <String>[];
  final Map<String, List<Message>> roomMessages = <String, List<Message>>{};
  int fetchChatsCallCount = 0;
  Future<void> Function()? onFetchChats;

  @override
  List<Chat> get chats => List<Chat>.from(_chats);

  void setChats(List<Chat> chats) {
    _chats = List<Chat>.from(chats);
    notifyListeners();
  }

  @override
  Future<List<Chat>> fetchChats({bool force = false}) async {
    fetchChatsCallCount += 1;
    if (onFetchChats != null) {
      await onFetchChats!();
    }
    return chats;
  }

  @override
  Future<void> sendRichMessage({
    required String roomId,
    String? text,
    List<MessageAttachmentDraft> attachments = const <MessageAttachmentDraft>[],
    Message? quotedMessage,
  }) async {
    sendRichCalls.add(
      _SendRichCall(
        roomId: roomId,
        text: text,
        attachments: List<MessageAttachmentDraft>.from(attachments),
        quotedMessage: quotedMessage,
      ),
    );
  }

  @override
  Future<void> forwardMessage({
    required Message original,
    required String targetRoomId,
    required ForwardInfo forwardInfo,
  }) async {
    forwardCalls.add(
      _ForwardCall(
        original: original,
        targetRoomId: targetRoomId,
        forwardInfo: forwardInfo,
      ),
    );
  }

  @override
  Future<void> pinMessage(String roomId, String messageId) async {
    pinnedCalls.add('$roomId::$messageId');
  }

  @override
  Future<void> unpinMessage(String roomId, String messageId) async {
    unpinnedCalls.add('$roomId::$messageId');
  }

  @override
  Future<void> markMessageDeleted(String roomId, String messageId) async {
    markedDeleted.add('$roomId::$messageId');
  }

  @override
  Future<List<MessageReactionSummary>> addReaction({
    required String roomId,
    required String messageId,
    required String reactionKey,
  }) async {
    addedReactionCalls.add('$roomId::$messageId::$reactionKey');
    return const <MessageReactionSummary>[];
  }

  @override
  Future<List<MessageReactionSummary>> removeReaction({
    required String roomId,
    required String messageId,
    required String reactionKey,
  }) async {
    removedReactionCalls.add('$roomId::$messageId::$reactionKey');
    return const <MessageReactionSummary>[];
  }

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
  Future<void> markMessagesAsRead(String roomId, String lastMessageId) async {
    markedReadCalls.add('$roomId::$lastMessageId');
  }

  @override
  List<Message> getMessages(String roomId) =>
      List<Message>.from(roomMessages[roomId] ?? const <Message>[]);

  @override
  Future<void> updateChatInfo(String roomId, ChatType chatType) async {}

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
  ConnectionStatus _status = ConnectionStatus.disconnected;

  @override
  ConnectionStatus get status => _status;

  void setStatus(ConnectionStatus status) {
    _status = status;
    notifyListeners();
  }

  @override
  Future<void> joinRoom(String roomId) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Chat _chat({
  required String id,
  required String roomId,
  required String name,
  required String lastMessage,
  ChatType type = ChatType.single,
  Map<String, dynamic>? extra,
}) {
  return Chat(
    id: id,
    roomId: roomId,
    name: name,
    type: type,
    lastMessage: lastMessage,
    lastMessageTime: DateTime(2026, 3, 5, 12, 0, 0),
    extra: extra,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ChatProvider', () {
    test('search keyword filters by name / extra / last message', () {
      final fakeMessageService = _FakeMessageService(
        chats: <Chat>[
          _chat(
            id: '1',
            roomId: 'r1',
            name: 'Alice',
            lastMessage: 'hello',
            extra: <String, dynamic>{'friend_remark': '老板'},
          ),
          _chat(
            id: '2',
            roomId: 'r2',
            name: 'Work Group',
            lastMessage: '今晚聚餐确认',
          ),
        ],
      );
      final fakeWs = _FakeWebSocketService();
      final provider = ChatProvider(
        messageService: fakeMessageService,
        webSocketService: fakeWs,
      );
      addTearDown(provider.dispose);

      expect(provider.filteredChats.length, 2);

      provider.setSearchKeyword('老板');
      expect(provider.filteredChats.map((chat) => chat.roomId), <String>['r1']);

      provider.setSearchKeyword('聚餐');
      expect(provider.filteredChats.map((chat) => chat.roomId), <String>['r2']);

      provider.setSearchKeyword('alice');
      expect(provider.filteredChats.map((chat) => chat.roomId), <String>['r1']);

      provider.clearSearch();
      expect(provider.filteredChats.length, 2);
    });

    test('message service notify updates provider chats snapshot', () async {
      final fakeMessageService = _FakeMessageService(
        chats: <Chat>[
          _chat(id: '1', roomId: 'r1', name: 'A', lastMessage: 'm1'),
        ],
      );
      final fakeWs = _FakeWebSocketService();
      final provider = ChatProvider(
        messageService: fakeMessageService,
        webSocketService: fakeWs,
      );
      addTearDown(provider.dispose);

      expect(provider.chats.length, 1);

      fakeMessageService.setChats(<Chat>[
        _chat(id: '1', roomId: 'r1', name: 'A', lastMessage: 'm1'),
        _chat(id: '2', roomId: 'r2', name: 'B', lastMessage: 'm2'),
      ]);
      await Future<void>.delayed(Duration.zero);

      expect(provider.chats.length, 2);
      expect(provider.chats.map((chat) => chat.roomId), <String>['r1', 'r2']);
    });

    test('loadChats delegates to messageService.fetchChats', () async {
      final fakeMessageService = _FakeMessageService(
        chats: <Chat>[
          _chat(id: '1', roomId: 'r1', name: 'A', lastMessage: 'm1'),
        ],
      );
      fakeMessageService.onFetchChats = () async {
        fakeMessageService.setChats(<Chat>[
          _chat(id: '1', roomId: 'r1', name: 'A', lastMessage: 'm1'),
          _chat(id: '2', roomId: 'r2', name: 'C', lastMessage: 'm3'),
        ]);
      };
      final fakeWs = _FakeWebSocketService();
      final provider = ChatProvider(
        messageService: fakeMessageService,
        webSocketService: fakeWs,
      );
      addTearDown(provider.dispose);

      await provider.loadChats();

      expect(fakeMessageService.fetchChatsCallCount, 1);
      expect(provider.chats.length, 2);
    });

    test(
      'sendRichMessage trims text and delegates after entering room',
      () async {
        final fakeMessageService = _FakeMessageService();
        final fakeWs = _FakeWebSocketService();
        final provider = ChatProvider(
          messageService: fakeMessageService,
          webSocketService: fakeWs,
        );
        addTearDown(provider.dispose);

        final quoted = _message(id: 'q1', roomId: 'r1', content: 'quoted');

        await provider.enterChatRoom(
          'r1',
          _chat(id: '1', roomId: 'r1', name: 'Alice', lastMessage: 'x'),
          delayHistoryLoad: true,
        );
        await provider.sendRichMessage(
          text: '  hello world  ',
          quotedMessage: quoted,
        );

        expect(fakeMessageService.sendRichCalls.length, 1);
        expect(fakeMessageService.sendRichCalls.first.roomId, 'r1');
        expect(fakeMessageService.sendRichCalls.first.text, 'hello world');
        expect(fakeMessageService.sendRichCalls.first.quotedMessage, quoted);
      },
    );

    test('sendRichMessage ignores blank payload when no attachment', () async {
      final fakeMessageService = _FakeMessageService();
      final fakeWs = _FakeWebSocketService();
      final provider = ChatProvider(
        messageService: fakeMessageService,
        webSocketService: fakeWs,
      );
      addTearDown(provider.dispose);

      await provider.enterChatRoom(
        'r1',
        _chat(id: '1', roomId: 'r1', name: 'Alice', lastMessage: 'x'),
        delayHistoryLoad: true,
      );
      await provider.sendRichMessage(text: '   ');

      expect(fakeMessageService.sendRichCalls, isEmpty);
    });

    test('forwardMessage keeps existing forward info', () async {
      final fakeMessageService = _FakeMessageService();
      final fakeWs = _FakeWebSocketService();
      final provider = ChatProvider(
        messageService: fakeMessageService,
        webSocketService: fakeWs,
      );
      addTearDown(provider.dispose);

      final forwardInfo = ForwardInfo(
        sourceType: ForwardSourceType.group,
        sourceId: 'source-room',
        sourceName: '来源群',
        originMessageId: 'origin-msg',
        originRoomId: 'origin-room',
        originSenderId: 'origin-user',
        originSenderName: '张三',
      );
      final original = _message(
        id: 'm1',
        roomId: 'r1',
        content: 'hello',
        forwardInfo: forwardInfo,
      );
      final target = _chat(
        id: '2',
        roomId: 'r2',
        name: 'Target',
        lastMessage: '',
      );

      await provider.forwardMessage(original, target);

      expect(fakeMessageService.forwardCalls.length, 1);
      expect(fakeMessageService.forwardCalls.first.targetRoomId, 'r2');
      expect(fakeMessageService.forwardCalls.first.forwardInfo, forwardInfo);
      expect(fakeMessageService.forwardCalls.first.original.id, 'm1');
    });

    test('deleteMessage delegates to markMessageDeleted', () async {
      final fakeMessageService = _FakeMessageService();
      final fakeWs = _FakeWebSocketService();
      final provider = ChatProvider(
        messageService: fakeMessageService,
        webSocketService: fakeWs,
      );
      addTearDown(provider.dispose);

      final message = _message(id: 'm-del', roomId: 'room-del', content: 'x');
      await provider.deleteMessage(message);

      expect(fakeMessageService.markedDeleted, <String>['room-del::m-del']);
    });

    test(
      'relay_only drops quoted message and skips unsupported message mutations',
      () async {
        final fakeMessageService = _FakeMessageService();
        fakeMessageService.roomMessages['r1'] = <Message>[
          _message(
            id: 'incoming-1',
            roomId: 'r1',
            content: 'hello',
            isSelf: false,
            status: MessageStatus.sent,
          ),
        ];
        final fakeWs = _FakeWebSocketService();
        final appConfigService = _FakeAppConfigService(
          runtime: const MessageRuntimeSettings(
            serverStorageMode: 'relay_only',
            contentAuditMode: 'plaintext',
          ),
        );
        final provider = ChatProvider(
          messageService: fakeMessageService,
          webSocketService: fakeWs,
          appConfigService: appConfigService,
        );
        addTearDown(provider.dispose);

        await provider.enterChatRoom(
          'r1',
          _chat(id: '1', roomId: 'r1', name: 'Alice', lastMessage: 'x'),
        );

        final quoted = _message(id: 'q1', roomId: 'r1', content: 'quoted');
        await provider.sendRichMessage(
          text: '  hello world  ',
          quotedMessage: quoted,
        );

        final message = _message(id: 'm1', roomId: 'r1', content: 'hello');
        final target = _chat(
          id: '2',
          roomId: 'r2',
          name: 'Target',
          lastMessage: '',
        );

        await provider.forwardMessage(message, target);
        await provider.pinMessage(message);
        await provider.unpinMessage(message);
        await provider.deleteMessage(message);
        await provider.toggleReaction(message, '👍');

        expect(fakeMessageService.markedReadCalls, isEmpty);
        expect(fakeMessageService.sendRichCalls, hasLength(1));
        expect(fakeMessageService.sendRichCalls.first.quotedMessage, isNull);
        expect(fakeMessageService.forwardCalls, isEmpty);
        expect(fakeMessageService.pinnedCalls, isEmpty);
        expect(fakeMessageService.unpinnedCalls, isEmpty);
        expect(fakeMessageService.markedDeleted, isEmpty);
        expect(fakeMessageService.addedReactionCalls, isEmpty);
        expect(fakeMessageService.removedReactionCalls, isEmpty);
      },
    );
  });
}

Message _message({
  required String id,
  required String roomId,
  required String content,
  ForwardInfo? forwardInfo,
  bool isSelf = true,
  MessageStatus status = MessageStatus.sent,
}) {
  return Message(
    id: id,
    roomId: roomId,
    senderId: 'u1',
    senderUsername: 'alice',
    senderName: 'Alice',
    content: content,
    type: MessageType.text,
    status: status,
    timestamp: DateTime(2026, 3, 5, 12, 0, 0),
    isSelf: isSelf,
    forwardInfo: forwardInfo,
  );
}
