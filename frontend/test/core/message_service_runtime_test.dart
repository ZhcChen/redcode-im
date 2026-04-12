import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/services/app_config_service.dart';
import 'package:frontend/core/services/message_service.dart';
import 'package:frontend/core/services/settings_service.dart';
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
  @override
  Future<List<Message>> loadMessages(String roomId) async => const <Message>[];
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
    user: AuthUser(
      id: 'user-self',
      username: 'alice',
      nickname: 'Alice',
    ),
  );

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  test('syncOfflineMessages skips server history fetch in relay_only mode', () async {
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
          return http.Response('[]', 200, headers: {'content-type': 'application/json'});
        }

        return http.Response('not found', 404);
      }),
    );

    await Future<void>.delayed(Duration.zero);
    await service.syncOfflineMessages();

    expect(roomHistoryFetchCount, 0);
  });
}

class _FakeAppConfigService extends AppConfigService {
  _FakeAppConfigService({required MessageRuntimeSettings runtime})
    : _runtime = runtime,
      super(
        settingsService: SettingsService(),
      );

  final MessageRuntimeSettings _runtime;

  @override
  MessageRuntimeSettings get currentMessageRuntime => _runtime;

  @override
  Future<MessageRuntimeSettings> getMessageRuntime() async => _runtime;
}
