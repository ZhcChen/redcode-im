import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:app/core/services/app_config_service.dart';
import 'package:app/core/services/message_service.dart';
import 'package:app/core/services/settings_service.dart';
import 'package:app/core/services/websocket_service.dart';
import 'package:app/core/storage/chat_cache.dart';
import 'package:app/core/storage/message_storage.dart';
import 'package:app/core/storage/token_storage.dart';
import 'package:app/features/auth/models/auth_session.dart';
import 'package:app/features/auth/models/auth_user.dart';
import 'package:app/features/chat/models/chat_model.dart';
import 'package:app/features/chat/models/message_model.dart';
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
  _FakeChatCache({this.chats});

  final List<Chat>? chats;
  List<Chat>? savedChats;

  @override
  Future<List<Chat>?> loadChats() async => chats;

  @override
  Future<void> saveChats(List<Chat> chats) async {
    savedChats = List<Chat>.from(chats);
  }
}

Message _pendingImageMessage({
  required String id,
  required String attachmentKey,
  required DateTime timestamp,
}) {
  return Message(
    id: id,
    roomId: 'room-1',
    senderId: 'user-self',
    senderUsername: 'alice',
    senderName: 'Alice',
    content: '[图片]',
    type: MessageType.image,
    status: MessageStatus.sending,
    timestamp: timestamp,
    isSelf: true,
    parts: <MessagePart>[
      MessagePart(
        position: 0,
        type: MessagePartType.image,
        attachment: MessageAttachment(
          key: attachmentKey,
          name: '$id.png',
          mime: 'image/png',
          size: 1,
        ),
      ),
    ],
  );
}

WebSocketMessage _incomingImageMessage({
  required String id,
  required String attachmentKey,
  required DateTime timestamp,
}) {
  return WebSocketMessage(
    id: id,
    roomId: 'room-1',
    senderId: 'user-self',
    senderUsername: 'alice',
    senderNickname: 'Alice',
    senderAvatarUrl: null,
    content: '[图片]',
    messageType: 'image',
    timestamp: timestamp,
    extra: null,
    quotedMessage: null,
    forwardMessage: null,
    parts: <WebSocketMessagePart>[
      WebSocketMessagePart(
        position: 0,
        partType: 'image',
        attachment: WebSocketMessageAttachment(
          key: attachmentKey,
          name: '$id.png',
          mime: 'image/png',
          size: 1,
        ),
      ),
    ],
  );
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
    'websocket echo matches pending image by attachment key instead of summary',
    () async {
      final storage = _FakeMessageStorage(
        roomMessages: <String, List<Message>>{
          'room-1': <Message>[
            _pendingImageMessage(
              id: 'pending-1',
              attachmentKey: 'messages/image-1.png',
              timestamp: DateTime(2026, 4, 12, 12, 0, 0),
            ),
            _pendingImageMessage(
              id: 'pending-2',
              attachmentKey: 'messages/image-2.png',
              timestamp: DateTime(2026, 4, 12, 12, 1, 0),
            ),
          ],
        },
      );
      final service = MessageService(
        tokenStorage: const _FakeTokenStorage(session),
        messageStorage: storage,
        chatCache: _FakeChatCache(),
        appConfigService: _FakeAppConfigService(
          runtime: const MessageRuntimeSettings(
            serverStorageMode: 'persist',
            contentAuditMode: 'plaintext',
          ),
        ),
      );
      addTearDown(() async {
        await service.handleGroupDissolved('room-1');
        service.dispose();
      });

      await service.loadCachedMessages('room-1');
      await service.handleWebSocketMessage(
        _incomingImageMessage(
          id: 'server-msg-2',
          attachmentKey: 'messages/image-2.png',
          timestamp: DateTime(2026, 4, 12, 12, 2, 0),
        ),
      );

      final messages = service.getMessages('room-1');
      expect(messages.map((message) => message.id), <String>[
        'pending-1',
        'server-msg-2',
      ]);
      expect(
        messages.first.parts.single.attachment?.key,
        'messages/image-1.png',
      );
      expect(
        messages.last.parts.single.attachment?.key,
        'messages/image-2.png',
      );
      expect(messages.last.status, MessageStatus.sent);
    },
  );

  test(
    'handleGroupDissolved clears room pending queue before resend',
    () async {
      var requestCount = 0;
      final service = MessageService(
        tokenStorage: const _FakeTokenStorage(session),
        messageStorage: _FakeMessageStorage(
          roomMessages: <String, List<Message>>{
            'room-1': <Message>[
              _pendingImageMessage(
                id: 'pending-1',
                attachmentKey: 'messages/image-1.png',
                timestamp: DateTime(2026, 4, 12, 12, 0, 0),
              ),
            ],
          },
        ),
        chatCache: _FakeChatCache(),
        appConfigService: _FakeAppConfigService(
          runtime: const MessageRuntimeSettings(
            serverStorageMode: 'persist',
            contentAuditMode: 'plaintext',
          ),
        ),
        client: MockClient((request) async {
          requestCount += 1;
          return http.Response('unexpected request', 500);
        }),
      );
      addTearDown(() async {
        await service.handleGroupDissolved('room-1');
        service.dispose();
      });

      await service.loadCachedMessages('room-1');
      await service.handleGroupDissolved('room-1');
      await service.resendMessage('pending-1');

      expect(service.getMessages('room-1'), isEmpty);
      expect(requestCount, 0);
    },
  );

  test('markChatAsRead persists unread reset to chat cache', () async {
    final chatCache = _FakeChatCache(
      chats: <Chat>[
        Chat(
          id: 'room-1',
          roomId: 'room-1',
          name: 'Alice',
          type: ChatType.single,
          lastMessage: 'hello',
          lastMessageTime: DateTime(2026, 4, 12, 12, 30, 0),
          unreadCount: 3,
        ),
      ],
    );
    final service = MessageService(
      tokenStorage: const _FakeTokenStorage(session),
      messageStorage: _FakeMessageStorage(),
      chatCache: chatCache,
      appConfigService: _FakeAppConfigService(
        runtime: const MessageRuntimeSettings(
          serverStorageMode: 'persist',
          contentAuditMode: 'plaintext',
        ),
      ),
    );

    await Future<void>.delayed(Duration.zero);
    service.markChatAsRead('room-1');
    await Future<void>.delayed(Duration.zero);

    expect(service.chats.single.unreadCount, 0);
    expect(chatCache.savedChats?.single.unreadCount, 0);
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

  test(
    'live websocket image message uses preview summary immediately',
    () async {
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
    },
  );

  test('local delete refreshes latest chat summary immediately', () async {
    final service = MessageService(
      tokenStorage: const _FakeTokenStorage(session),
      messageStorage: _FakeMessageStorage(
        roomMessages: <String, List<Message>>{
          'room-1': <Message>[
            Message(
              id: 'msg-1',
              roomId: 'room-1',
              senderId: 'user-self',
              senderUsername: 'alice',
              senderName: 'Alice',
              content: 'hello latest',
              type: MessageType.text,
              status: MessageStatus.sent,
              timestamp: DateTime(2026, 4, 12, 12, 30, 0),
              isSelf: true,
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
            unreadCount: 0,
            extra: const <String, dynamic>{'last_message_id': 'msg-1'},
          ),
        ],
      ),
      appConfigService: _FakeAppConfigService(
        runtime: const MessageRuntimeSettings(
          serverStorageMode: 'persist',
          contentAuditMode: 'plaintext',
        ),
      ),
      client: MockClient((request) async {
        if (request.method == 'DELETE' &&
            request.url.path == '/rooms/room-1/messages/msg-1') {
          return http.Response(
            jsonEncode({
              'id': 'msg-1',
              'room_id': 'room-1',
              'sender_id': 'user-self',
              'sender_username': 'alice',
              'sender_nickname': 'Alice',
              'content': 'hello latest',
              'message_type': 'text',
              'created_at': '2026-04-12T12:30:00.000Z',
              'status': 'sent',
              'is_deleted': true,
              'deleted_at': '2026-04-12T12:31:00.000Z',
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('not found', 404);
      }),
    );

    await Future<void>.delayed(Duration.zero);
    await service.loadCachedMessages('room-1');
    await service.markMessageDeleted('room-1', 'msg-1');

    expect(service.chats.single.lastMessage, '[消息已删除]');
    expect(service.chats.single.extra?['last_message_id'], 'msg-1');
  });

  test('local edit refreshes latest chat summary immediately', () async {
    final service = MessageService(
      tokenStorage: const _FakeTokenStorage(session),
      messageStorage: _FakeMessageStorage(
        roomMessages: <String, List<Message>>{
          'room-1': <Message>[
            Message(
              id: 'msg-1',
              roomId: 'room-1',
              senderId: 'user-self',
              senderUsername: 'alice',
              senderName: 'Alice',
              content: 'hello latest',
              type: MessageType.text,
              status: MessageStatus.sent,
              timestamp: DateTime(2026, 4, 12, 12, 30, 0),
              isSelf: true,
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
            unreadCount: 0,
            extra: const <String, dynamic>{'last_message_id': 'msg-1'},
          ),
        ],
      ),
      appConfigService: _FakeAppConfigService(
        runtime: const MessageRuntimeSettings(
          serverStorageMode: 'persist',
          contentAuditMode: 'plaintext',
        ),
      ),
      client: MockClient((request) async {
        if (request.method == 'PATCH' &&
            request.url.path == '/rooms/room-1/messages/msg-1') {
          return http.Response(
            jsonEncode({
              'id': 'msg-1',
              'room_id': 'room-1',
              'sender_id': 'user-self',
              'sender_username': 'alice',
              'sender_nickname': 'Alice',
              'content': 'hello latest edited',
              'message_type': 'text',
              'created_at': '2026-04-12T12:30:00.000Z',
              'status': 'sent',
              'is_deleted': false,
              'is_edited': true,
              'edited_at': '2026-04-12T12:31:00.000Z',
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('not found', 404);
      }),
    );

    await Future<void>.delayed(Duration.zero);
    await service.loadCachedMessages('room-1');
    await service.editMessage(
      roomId: 'room-1',
      messageId: 'msg-1',
      content: 'hello latest edited',
    );

    expect(service.chats.single.lastMessage, 'hello latest edited');
    expect(service.chats.single.extra?['last_message_id'], 'msg-1');
  });

  test(
    'fetchChats preserves group description and member count in extra',
    () async {
      final service = MessageService(
        tokenStorage: const _FakeTokenStorage(session),
        messageStorage: _FakeMessageStorage(),
        chatCache: _FakeChatCache(),
        appConfigService: _FakeAppConfigService(
          runtime: const MessageRuntimeSettings(
            serverStorageMode: 'persist',
            contentAuditMode: 'plaintext',
          ),
        ),
        client: MockClient((request) async {
          if (request.method == 'GET' && request.url.path == '/chats') {
            return http.Response(
              jsonEncode([
                {
                  'room_id': 'room-group-1',
                  'name': '项目群',
                  'room_type': 'group',
                  'description': '核心项目讨论',
                  'member_count': 12,
                  'unread_count': 0,
                  'last_message': {
                    'id': 'msg-1',
                    'content': 'hello group',
                    'message_type': 'text',
                    'created_at': '2026-07-25T10:00:00.000Z',
                  },
                },
              ]),
              200,
              headers: {'content-type': 'application/json'},
            );
          }
          return http.Response('not found', 404);
        }),
      );

      await Future<void>.delayed(Duration.zero);
      final chats = await service.fetchChats(force: true);

      expect(chats.single.extra?['description'], '核心项目讨论');
      expect(chats.single.extra?['member_count'], 12);
    },
  );

  test(
    'addReaction persists updated message reactions to local cache',
    () async {
      final storage = _FakeMessageStorage(
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
      );
      final service = MessageService(
        tokenStorage: const _FakeTokenStorage(session),
        messageStorage: storage,
        chatCache: _FakeChatCache(),
        client: MockClient((request) async {
          if (request.method == 'POST' &&
              request.url.path == '/rooms/room-1/messages/msg-1/reactions') {
            return http.Response(
              jsonEncode({
                'success': true,
                'message': 'ok',
                'summaries': [
                  {
                    'reaction_key': '👍',
                    'count': 1,
                    'user_ids': ['user-self'],
                    'has_self': true,
                  },
                ],
              }),
              200,
              headers: {'content-type': 'application/json'},
            );
          }
          return http.Response('not found', 404);
        }),
      );

      await service.loadCachedMessages('room-1');
      final summaries = await service.addReaction(
        roomId: 'room-1',
        messageId: 'msg-1',
        reactionKey: '👍',
      );

      expect(summaries.single.reactionKey, '👍');
      expect(
        service.getMessages('room-1').single.reactions?.single.reactionKey,
        '👍',
      );
      expect(
        storage._roomMessages['room-1']?.single.reactions?.single.reactionKey,
        '👍',
      );
    },
  );

  test(
    'removeReaction persists updated message reactions to local cache',
    () async {
      final storage = _FakeMessageStorage(
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
              reactions: <MessageReactionSummary>[
                MessageReactionSummary(
                  reactionKey: '👍',
                  count: 1,
                  userIds: <String>['user-self'],
                  hasSelf: true,
                ),
              ],
            ),
          ],
        },
      );
      final service = MessageService(
        tokenStorage: const _FakeTokenStorage(session),
        messageStorage: storage,
        chatCache: _FakeChatCache(),
        client: MockClient((request) async {
          if (request.method == 'DELETE' &&
              request.url.path == '/rooms/room-1/messages/msg-1/reactions' &&
              request.url.queryParameters['reaction_key'] == '👍') {
            return http.Response(
              jsonEncode({'success': true, 'message': 'ok', 'summaries': []}),
              200,
              headers: {'content-type': 'application/json'},
            );
          }
          return http.Response('not found', 404);
        }),
      );

      await service.loadCachedMessages('room-1');
      final summaries = await service.removeReaction(
        roomId: 'room-1',
        messageId: 'msg-1',
        reactionKey: '👍',
      );

      expect(summaries, isEmpty);
      expect(service.getMessages('room-1').single.reactions, isEmpty);
      expect(storage._roomMessages['room-1']?.single.reactions, isEmpty);
    },
  );

  test(
    'getReactions refreshes cached message reactions for unloaded room',
    () async {
      final storage = _FakeMessageStorage(
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
      );
      final service = MessageService(
        tokenStorage: const _FakeTokenStorage(session),
        messageStorage: storage,
        chatCache: _FakeChatCache(),
        client: MockClient((request) async {
          if (request.method == 'GET' &&
              request.url.path == '/rooms/room-1/messages/msg-1/reactions') {
            return http.Response(
              jsonEncode({
                'success': true,
                'message': 'ok',
                'summaries': [
                  {
                    'reaction_key': '🎉',
                    'count': 2,
                    'user_ids': ['user-a', 'user-b'],
                    'has_self': false,
                  },
                ],
              }),
              200,
              headers: {'content-type': 'application/json'},
            );
          }
          return http.Response('not found', 404);
        }),
      );

      final summaries = await service.getReactions(
        roomId: 'room-1',
        messageId: 'msg-1',
      );
      final persisted = await storage.loadMessages('room-1');

      expect(summaries.single.reactionKey, '🎉');
      expect(persisted.single.reactions?.single.reactionKey, '🎉');
    },
  );

  test(
    'handlePinUpdate persists cached message pin state for unloaded room',
    () async {
      final storage = _FakeMessageStorage(
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
      );
      final service = MessageService(
        tokenStorage: const _FakeTokenStorage(session),
        messageStorage: storage,
        chatCache: _FakeChatCache(),
      );

      await service.handlePinUpdate(
        roomId: 'room-1',
        messageId: 'msg-1',
        isPinned: true,
        pinnedAt: DateTime(2026, 4, 12, 12, 45, 0),
        pinnedBy: 'admin-1',
      );

      final persisted = await storage.loadMessages('room-1');
      expect(persisted.single.pinnedAt, DateTime(2026, 4, 12, 12, 45, 0));
      expect(persisted.single.extra?['pinned_by'], 'admin-1');
    },
  );
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
