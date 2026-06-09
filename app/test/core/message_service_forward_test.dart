import 'dart:convert';
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:app/core/services/message_service.dart';
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
  _FakeMessageStorage();

  final Map<String, List<Message>> _messages = <String, List<Message>>{};

  @override
  Future<List<Message>> loadMessages(String roomId) async {
    return List<Message>.from(_messages[roomId] ?? const <Message>[]);
  }

  @override
  Future<void> saveMessages(String roomId, List<Message> messages) async {
    _messages[roomId] = List<Message>.from(messages);
  }
}

class _FakeChatCache extends ChatCache {
  const _FakeChatCache();

  @override
  Future<List<Chat>?> loadChats() async => null;

  @override
  Future<void> saveChats(List<Chat> chats) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const session = AuthSession(
    token: 'token-forward',
    user: AuthUser(
      id: 'user-self',
      username: 'alice',
      nickname: 'Alice',
    ),
  );

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('MessageService.forwardMessage', () {
    test('keeps original parts on pending forwarded rich message', () async {
      final completer = Completer<http.Response>();
      final service = MessageService(
        tokenStorage: const _FakeTokenStorage(session),
        messageStorage: _FakeMessageStorage(),
        chatCache: const _FakeChatCache(),
        client: MockClient((request) => completer.future),
      );

      final future = service.forwardMessage(
        original: _message(
          id: 'msg-original',
          roomId: 'room-source',
          content: '[图片]',
          type: MessageType.image,
          parts: <MessagePart>[
            MessagePart(
              position: 0,
              type: MessagePartType.image,
              attachment: MessageAttachment(
                key: 'attachments/image-1',
                name: 'cat.png',
                mime: 'image/png',
              ),
            ),
          ],
        ),
        targetRoomId: 'room-target',
        forwardInfo: _forwardInfo(),
      );

      await Future<void>.delayed(Duration.zero);

      final pending = service.getMessages('room-target').single;
      expect(pending.status, MessageStatus.sending);
      expect(pending.type, MessageType.image);
      expect(pending.parts, hasLength(1));
      expect(pending.parts.single.type, MessagePartType.image);
      expect(pending.parts.single.attachment?.key, 'attachments/image-1');

      completer.complete(
        http.Response(
          jsonEncode({
            'message': {
              'id': 'msg-forwarded',
              'room_id': 'room-target',
              'sender_id': 'user-self',
              'sender_username': 'alice',
              'sender_nickname': 'Alice',
              'content': '[图片]',
              'message_type': 'image',
              'created_at': '2026-04-09T12:00:00Z',
            },
          }),
          200,
          headers: {'content-type': 'application/json'},
        ),
      );

      await future;
    });

    test('supports forwarding image messages via API and caches response', () async {
      http.Request? capturedRequest;
      final service = MessageService(
        tokenStorage: const _FakeTokenStorage(session),
        messageStorage: _FakeMessageStorage(),
        chatCache: const _FakeChatCache(),
        client: MockClient((request) async {
          capturedRequest = request;
          return http.Response(
            jsonEncode({
              'message': {
                'id': 'msg-forwarded',
                'room_id': 'room-target',
                'sender_id': 'user-self',
                'sender_username': 'alice',
                'sender_nickname': 'Alice',
                'content': '[图片]',
                'message_type': 'image',
                'created_at': '2026-04-09T12:00:00Z',
                'forward_message': {
                  'message_id': 'msg-original',
                  'room_id': 'room-source',
                  'sender_id': 'user-origin',
                  'sender_username': 'bob',
                  'sender_nickname': 'Bob',
                },
                'parts': [
                  {
                    'position': 0,
                    'part_type': 'image',
                    'attachment': {
                      'key': 'attachments/image-1',
                      'name': 'cat.png',
                      'mime': 'image/png',
                      'size': 1024,
                      'width': 640,
                      'height': 480,
                    },
                  },
                ],
              },
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      );

      await service.forwardMessage(
        original: _message(
          id: 'msg-original',
          roomId: 'room-source',
          content: '[图片]',
          type: MessageType.image,
          parts: <MessagePart>[
            MessagePart(
              position: 0,
              type: MessagePartType.image,
              attachment: MessageAttachment(
                key: 'attachments/image-1',
                name: 'cat.png',
                mime: 'image/png',
              ),
            ),
          ],
        ),
        targetRoomId: 'room-target',
        forwardInfo: _forwardInfo(),
      );

      expect(capturedRequest, isNotNull);
      expect(capturedRequest!.method, 'POST');
      expect(capturedRequest!.url.path, '/rooms/room-target/messages/forward');
      expect(capturedRequest!.headers['Authorization'], 'Bearer token-forward');
      expect(
        jsonDecode(capturedRequest!.body),
        {'original_message_id': 'msg-original'},
      );

      final messages = service.getMessages('room-target');
      expect(messages, hasLength(1));
      final forwarded = messages.single;
      expect(forwarded.id, 'msg-forwarded');
      expect(forwarded.type, MessageType.image);
      expect(forwarded.status, MessageStatus.sent);
      expect(forwarded.forwardInfo?.originMessageId, 'msg-original');
      expect(forwarded.parts, hasLength(1));
      expect(forwarded.parts.single.type, MessagePartType.image);
      expect(forwarded.parts.single.attachment?.key, 'attachments/image-1');
    });

    test('rethrows backend failures after marking forwarded message failed', () async {
      http.Request? capturedRequest;
      final service = MessageService(
        tokenStorage: const _FakeTokenStorage(session),
        messageStorage: _FakeMessageStorage(),
        chatCache: const _FakeChatCache(),
        client: MockClient((request) async {
          capturedRequest = request;
          return http.Response(
            jsonEncode({'message': '系统消息不支持转发'}),
            400,
            headers: {'content-type': 'application/json'},
          );
        }),
      );

      await expectLater(
        service.forwardMessage(
          original: _message(
            id: 'msg-system',
            roomId: 'room-source',
            content: '系统通知',
            type: MessageType.system,
          ),
          targetRoomId: 'room-target',
          forwardInfo: _forwardInfo(),
        ),
        throwsA(isA<Exception>()),
      );

      expect(capturedRequest, isNotNull);
      expect(capturedRequest!.url.path, '/rooms/room-target/messages/forward');
      final messages = service.getMessages('room-target');
      expect(messages, hasLength(1));
      expect(messages.single.type, MessageType.system);
      expect(messages.single.status, MessageStatus.failed);
    });
  });
}

ForwardInfo _forwardInfo() {
  return ForwardInfo(
    sourceType: ForwardSourceType.group,
    sourceId: 'room-source',
    sourceName: '来源群',
    originMessageId: 'msg-original',
    originRoomId: 'room-source',
    originSenderId: 'user-origin',
    originSenderName: 'Bob',
  );
}

Message _message({
  required String id,
  required String roomId,
  required String content,
  required MessageType type,
  List<MessagePart>? parts,
}) {
  return Message(
    id: id,
    roomId: roomId,
    senderId: 'user-origin',
    senderUsername: 'bob',
    senderName: 'Bob',
    content: content,
    type: type,
    status: MessageStatus.sent,
    timestamp: DateTime.parse('2026-04-09T10:00:00Z'),
    isSelf: false,
    parts: parts,
  );
}
