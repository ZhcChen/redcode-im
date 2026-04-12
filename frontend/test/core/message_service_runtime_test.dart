import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/services/app_config_service.dart';
import 'package:frontend/core/services/message_service.dart';
import 'package:frontend/core/services/settings_service.dart';
import 'package:frontend/core/services/websocket_service.dart';
import 'package:frontend/core/storage/chat_cache.dart';
import 'package:frontend/core/storage/message_storage.dart';
import 'package:frontend/core/storage/token_storage.dart';
import 'package:frontend/features/auth/models/auth_session.dart';
import 'package:frontend/features/auth/models/auth_user.dart';
import 'package:frontend/features/chat/models/chat_model.dart';
import 'package:frontend/features/chat/models/message_model.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeTokenStorage extends TokenStorage {
  const _FakeTokenStorage(this._session);

  final AuthSession? _session;

  @override
  Future<AuthSession?> readSession() async => _session;
}

class _FakeMessageStorage extends MessageStorage {
  _FakeMessageStorage({Map<String, List<Message>>? roomMessages})
    : _roomMessages = roomMessages ?? <String, List<Message>>{};

  final Map<String, List<Message>> _roomMessages;

  @override
  Future<List<Message>> loadMessages(String roomId) async =>
      List<Message>.from(_roomMessages[roomId] ?? const <Message>[]);

  @override
  Future<void> saveMessages(String roomId, List<Message> messages) async {
    _roomMessages[roomId] = List<Message>.from(messages);
  }
}

class _FakeChatCache extends ChatCache {
  const _FakeChatCache({this.chats});

  final List<Chat>? chats;

  @override
  Future<List<Chat>?> loadChats() async => chats;

  @override
  Future<void> saveChats(List<Chat> chats) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const session = AuthSession(
    token: 'token-runtime',
    user: AuthUser(id: 'user-self', username: 'alice', nickname: 'Alice'),
  );

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  test(
    'syncOfflineMessages skips server history fetch in relay_only mode',
    () async {
      var roomHistoryFetchCount = 0;
      final service = MessageService(
        tokenStorage: const _FakeTokenStorage(session),
        messageStorage: _FakeMessageStorage(),
        chatCache: _FakeChatCache(
          chats: <Chat>[
            Chat(
              id: 'room-1',
              roomId: 'room-1',
              name: 'Alice',
              type: ChatType.single,
              lastMessage: '',
              lastMessageTime: DateTime(2026, 4, 12, 12, 0, 0),
              unreadCount: 1,
              extra: const <String, dynamic>{
                'last_read_message_id': 'msg-last-read',
              },
            ),
          ],
        ),
        appConfigService: _FakeAppConfigService(
          runtime: const MessageRuntimeSettings(
            serverStorageMode: 'relay_only',
            contentAuditMode: 'plaintext',
          ),
        ),
        client: MockClient((request) async {
          if (request.url.path == '/chats') {
            return http.Response(
              jsonEncode([
                {
                  'room_id': 'room-1',
                  'name': 'Alice',
                  'room_type': 'single',
                  'unread_count': 1,
                  'last_read_message_id': 'msg-last-read',
                },
              ]),
              200,
              headers: {'content-type': 'application/json'},
            );
          }

          if (request.url.path == '/rooms/room-1/messages') {
            roomHistoryFetchCount += 1;
            return http.Response(
              '[]',
              200,
              headers: {'content-type': 'application/json'},
            );
          }

          return http.Response('not found', 404);
        }),
      );

      await Future<void>.delayed(Duration.zero);
      await service.syncOfflineMessages();

      expect(roomHistoryFetchCount, 0);
    },
  );

  test('relay_only sanitizes cached chat summaries on startup', () async {
    final service = MessageService(
      tokenStorage: const _FakeTokenStorage(session),
      messageStorage: _FakeMessageStorage(),
      chatCache: _FakeChatCache(
        chats: <Chat>[
          Chat(
            id: 'room-1',
            roomId: 'room-1',
            name: 'Alice',
            type: ChatType.single,
            lastMessage: 'stale summary',
            lastMessageTime: DateTime(2026, 4, 12, 10, 0, 0),
            unreadCount: 7,
          ),
        ],
      ),
      appConfigService: _FakeAppConfigService(
        runtime: const MessageRuntimeSettings(
          serverStorageMode: 'relay_only',
          contentAuditMode: 'plaintext',
        ),
      ),
    );

    await Future<void>.delayed(Duration.zero);

    expect(service.chats, hasLength(1));
    expect(service.chats.single.lastMessage, '');
    expect(service.chats.single.unreadCount, 0);
  });

  test(
    'runtime switches to relay_only sanitize in-memory chat summaries',
    () async {
      final appConfigService = _FakeAppConfigService(
        runtime: const MessageRuntimeSettings(
          serverStorageMode: 'persist',
          contentAuditMode: 'plaintext',
        ),
      );
      final service = MessageService(
        tokenStorage: const _FakeTokenStorage(session),
        messageStorage: _FakeMessageStorage(),
        chatCache: _FakeChatCache(
          chats: <Chat>[
            Chat(
              id: 'room-1',
              roomId: 'room-1',
              name: 'Alice',
              type: ChatType.single,
              lastMessage: 'recent summary',
              lastMessageTime: DateTime(2026, 4, 12, 10, 0, 0),
              unreadCount: 3,
              extra: const <String, dynamic>{'last_message_id': 'msg-1'},
            ),
          ],
        ),
        appConfigService: appConfigService,
      );

      await Future<void>.delayed(Duration.zero);
      expect(service.chats.single.lastMessage, 'recent summary');
      expect(service.chats.single.unreadCount, 3);

      appConfigService.updateRuntime(
        const MessageRuntimeSettings(
          serverStorageMode: 'relay_only',
          contentAuditMode: 'plaintext',
        ),
      );
      await Future<void>.delayed(Duration.zero);

      expect(service.chats.single.lastMessage, '');
      expect(service.chats.single.unreadCount, 0);
      expect(service.chats.single.extra, isNull);
    },
  );

  test('relay_only rebuilds local chat summary from cached messages', () async {
    final service = MessageService(
      tokenStorage: const _FakeTokenStorage(session),
      messageStorage: _FakeMessageStorage(
        roomMessages: <String, List<Message>>{
          'room-1': <Message>[
            Message(
              id: 'msg-1',
              roomId: 'room-1',
              senderId: 'user-peer',
              senderUsername: 'bob',
              senderName: 'Bob',
              content: '',
              type: MessageType.image,
              status: MessageStatus.sent,
              timestamp: DateTime(2026, 4, 12, 12, 30, 0),
              isSelf: false,
            ),
          ],
        },
      ),
      chatCache: _FakeChatCache(
        chats: <Chat>[
          Chat(
            id: 'room-1',
            roomId: 'room-1',
            name: 'Alice',
            type: ChatType.single,
            lastMessage: 'stale summary',
            lastMessageTime: DateTime(2026, 4, 12, 10, 0, 0),
            unreadCount: 7,
          ),
        ],
      ),
      appConfigService: _FakeAppConfigService(
        runtime: const MessageRuntimeSettings(
          serverStorageMode: 'relay_only',
          contentAuditMode: 'plaintext',
        ),
      ),
    );

    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(service.chats, hasLength(1));
    expect(service.chats.single.lastMessage, '[图片]');
    expect(service.chats.single.unreadCount, 1);
    expect(service.chats.single.extra?['last_message_id'], 'msg-1');
  });

  test(
    'message update refreshes latest local relay_only chat summary',
    () async {
      final service = MessageService(
        tokenStorage: const _FakeTokenStorage(session),
        messageStorage: _FakeMessageStorage(
          roomMessages: <String, List<Message>>{
            'room-1': <Message>[
              Message(
                id: 'msg-1',
                roomId: 'room-1',
                senderId: 'user-peer',
                senderUsername: 'bob',
                senderName: 'Bob',
                content: 'hello latest',
                type: MessageType.text,
                status: MessageStatus.sent,
                timestamp: DateTime(2026, 4, 12, 12, 30, 0),
                isSelf: false,
              ),
            ],
          },
        ),
        chatCache: _FakeChatCache(
          chats: <Chat>[
            Chat(
              id: 'room-1',
              roomId: 'room-1',
              name: 'Alice',
              type: ChatType.single,
              lastMessage: 'hello latest',
              lastMessageTime: DateTime(2026, 4, 12, 12, 30, 0),
              unreadCount: 1,
              extra: const <String, dynamic>{'last_message_id': 'msg-1'},
            ),
          ],
        ),
        appConfigService: _FakeAppConfigService(
          runtime: const MessageRuntimeSettings(
            serverStorageMode: 'relay_only',
            contentAuditMode: 'plaintext',
          ),
        ),
      );

      await service.loadCachedMessages('room-1');
      await service.handleMessageUpdate(
        roomId: 'room-1',
        messageId: 'msg-1',
        isDeleted: true,
        deletedAt: DateTime(2026, 4, 12, 12, 31, 0),
      );

      expect(service.chats.single.lastMessage, '[消息已删除]');
      expect(service.chats.single.extra?['last_message_id'], 'msg-1');
    },
  );

  test('live websocket image message uses preview summary immediately', () async {
    final service = MessageService(
      tokenStorage: const _FakeTokenStorage(session),
      messageStorage: _FakeMessageStorage(),
      chatCache: _FakeChatCache(
        chats: <Chat>[
          Chat(
            id: 'room-1',
            roomId: 'room-1',
            name: 'Alice',
            type: ChatType.single,
            lastMessage: '',
            lastMessageTime: DateTime(2026, 4, 12, 12, 0, 0),
            unreadCount: 0,
          ),
        ],
      ),
      appConfigService: _FakeAppConfigService(
        runtime: const MessageRuntimeSettings(
          serverStorageMode: 'relay_only',
          contentAuditMode: 'plaintext',
        ),
      ),
    );

    await Future<void>.delayed(Duration.zero);
    await service.handleWebSocketMessage(
      WebSocketMessage(
        id: 'msg-image-1',
        roomId: 'room-1',
        senderId: 'user-peer',
        senderUsername: 'bob',
        senderNickname: 'Bob',
        senderAvatarUrl: null,
        content: '',
        messageType: 'image',
        timestamp: DateTime(2026, 4, 12, 12, 40, 0),
        extra: null,
        quotedMessage: null,
        forwardMessage: null,
        parts: const <WebSocketMessagePart>[],
      ),
    );

    expect(service.chats.single.lastMessage, '[图片]');
    expect(service.chats.single.extra?['last_message_id'], 'msg-image-1');
  });
}

class _FakeAppConfigService extends AppConfigService {
  _FakeAppConfigService({required MessageRuntimeSettings runtime})
    : _runtime = runtime,
      super(settingsService: SettingsService());

  MessageRuntimeSettings _runtime;

  @override
  MessageRuntimeSettings get currentMessageRuntime => _runtime;

  @override
  Future<MessageRuntimeSettings> getMessageRuntime() async => _runtime;

  void updateRuntime(MessageRuntimeSettings runtime) {
    _runtime = runtime;
    notifyListeners();
  }
}
