import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:app/core/e2ee/device_lifecycle.dart';
import 'package:app/core/e2ee/direct_message_coordinator.dart';
import 'package:app/core/e2ee/identity_service.dart';
import 'package:app/core/e2ee/mls_api_service.dart';
import 'package:app/core/e2ee/secure_state_storage.dart';
import 'package:app/core/services/app_config_service.dart';
import 'package:app/core/services/message_service.dart';
import 'package:app/core/services/settings_service.dart';
import 'package:app/core/storage/app_config_storage.dart';
import 'package:app/core/storage/chat_cache.dart';
import 'package:app/core/storage/message_storage.dart';
import 'package:app/core/storage/token_storage.dart';
import 'package:app/features/auth/models/auth_session.dart';
import 'package:app/features/auth/models/auth_user.dart';
import 'package:app/features/chat/models/chat_model.dart';
import 'package:app/features/chat/models/message_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

const _enabled = bool.fromEnvironment('ENABLE_E2EE_CROSS_CLIENT_LIVE');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Flutter 与 H5 通过正式消息链双向互解', () async {
    if (!_enabled) return;
    SharedPreferences.setMockInitialValues({});
    HttpOverrides.global = _RealHttpOverrides();

    final coordinationUrl = Platform.environment['E2EE_COORDINATION_URL'];
    final coordinationSecret = Platform.environment['E2EE_COORDINATION_SECRET'];
    if (coordinationUrl == null || coordinationSecret == null) {
      fail('缺少跨端联调协调服务配置');
    }

    final coordination = _CoordinationClient(
      baseUrl: coordinationUrl,
      secret: coordinationSecret,
    );
    final fixture = await coordination.get('/fixture');
    final session = AuthSession(
      token: fixture.string('token'),
      user: AuthUser(
        id: fixture.string('account_id'),
        username: fixture.string('username'),
        nickname: fixture.string('username'),
      ),
    );
    final tokenStorage = _StaticTokenStorage(session);
    final protocolStorage = E2eeSecureStateStorage(
      wrappingKeys: _MemoryWrappingKeys(),
      encryptedStates: _MemoryEncryptedStates(),
    );
    final protocolApi = E2eeMlsApiService(tokenStorage: tokenStorage);
    final identityApi = E2eeIdentityService(tokenStorage: tokenStorage);
    final lifecycle = E2eeDeviceLifecycle(
      storage: protocolStorage,
      identityService: identityApi,
      api: protocolApi,
    );
    final coordinator = E2eeDirectMessageCoordinator(
      storage: protocolStorage,
      lifecycle: lifecycle,
      identityService: identityApi,
      api: protocolApi,
    );
    final config = AppConfigService(
      storage: _MemoryAppConfigStorage(),
      settingsService: SettingsService(),
    );
    final messages = MessageService(
      tokenStorage: tokenStorage,
      messageStorage: _MemoryMessageStorage(),
      chatCache: _MemoryChatCache(),
      appConfigService: config,
      e2eeDirectMessages: coordinator,
    );

    try {
      final runtime = await config.refreshMessageRuntime();
      expect(runtime.isE2ee, isTrue);
      await messages.fetchChats(force: true);

      final roomId = fixture.string('room_id');
      final outgoingMarker = fixture.string('flutter_marker');
      await messages.sendTextMessage(roomId, outgoingMarker);
      final outgoing = messages
          .getMessages(roomId)
          .where((message) => message.content == outgoingMarker)
          .single;
      await coordination.post('/flutter-sent', {'message_id': outgoing.id});

      final h5Sent = await coordination.poll('/h5-sent');
      final incomingId = h5Sent.string('message_id');
      final incomingMarker = fixture.string('h5_marker');
      final history = await messages.loadMessages(roomId, limit: 20);
      expect(
        history.any(
          (message) =>
              message.id == incomingId && message.content == incomingMarker,
        ),
        isTrue,
      );
      await coordination.post('/flutter-received', {'message_id': incomingId});
    } finally {
      messages.dispose();
      coordination.close();
      HttpOverrides.global = null;
    }
  }, timeout: const Timeout(Duration(seconds: 45)));
}

class _RealHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) =>
      super.createHttpClient(context);
}

class _CoordinationClient {
  _CoordinationClient({required this.baseUrl, required this.secret});

  final String baseUrl;
  final String secret;
  final http.Client _client = http.Client();

  void close() => _client.close();

  Future<Map<String, dynamic>> get(String path) => _request('GET', path);

  Future<Map<String, dynamic>> post(
    String path,
    Map<String, dynamic> payload,
  ) => _request('POST', path, payload);

  Future<Map<String, dynamic>> poll(String path) async {
    final deadline = DateTime.now().add(const Duration(seconds: 30));
    while (DateTime.now().isBefore(deadline)) {
      final response = await _client.get(
        Uri.parse('$baseUrl$path'),
        headers: {'Authorization': 'Bearer $secret'},
      );
      if (response.statusCode == 200) {
        return _decode(response.body);
      }
      if (response.statusCode != 204) {
        throw StateError('跨端联调协调服务返回 ${response.statusCode}');
      }
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    throw TimeoutException('等待跨端联调步骤超时');
  }

  Future<Map<String, dynamic>> _request(
    String method,
    String path, [
    Map<String, dynamic>? payload,
  ]) async {
    final uri = Uri.parse('$baseUrl$path');
    final headers = {
      'Authorization': 'Bearer $secret',
      if (payload != null) 'Content-Type': 'application/json',
    };
    final response = method == 'POST'
        ? await _client.post(uri, headers: headers, body: jsonEncode(payload))
        : await _client.get(uri, headers: headers);
    if (response.statusCode != 200) {
      throw StateError('跨端联调协调服务返回 ${response.statusCode}');
    }
    return _decode(response.body);
  }

  Map<String, dynamic> _decode(String body) =>
      jsonDecode(body) as Map<String, dynamic>;
}

extension on Map<String, dynamic> {
  String string(String key) {
    final value = this[key];
    if (value is! String || value.isEmpty) {
      throw StateError('跨端联调夹具缺少字段: $key');
    }
    return value;
  }
}

class _StaticTokenStorage extends TokenStorage {
  const _StaticTokenStorage(this.session);
  final AuthSession session;

  @override
  Future<AuthSession?> readSession() async => session;

  @override
  Future<String?> readToken() async => session.token;
}

class _MemoryWrappingKeys implements E2eeWrappingKeyStore {
  final Map<String, List<int>> values = {};

  @override
  Future<void> delete(String key) async => values.remove(key);

  @override
  Future<List<int>?> read(String key) async => values[key];

  @override
  Future<void> write(String key, List<int> value) async {
    values[key] = List<int>.from(value);
  }
}

class _MemoryEncryptedStates implements E2eeEncryptedStateStore {
  final Map<String, List<int>> values = {};

  @override
  Future<void> delete(String accountNamespace) async =>
      values.remove(accountNamespace);

  @override
  Future<List<int>?> read(String accountNamespace) async =>
      values[accountNamespace];

  @override
  Future<void> write(String accountNamespace, List<int> value) async {
    values[accountNamespace] = List<int>.from(value);
  }
}

class _MemoryAppConfigStorage extends AppConfigStorage {
  MessageRuntimeSettings? runtime;

  @override
  Future<String?> getAppName() async => null;

  @override
  Future<MessageRuntimeSettings?> getMessageRuntime() async => runtime;

  @override
  Future<void> saveAppName(String appName) async {}

  @override
  Future<void> saveMessageRuntime(MessageRuntimeSettings value) async {
    runtime = value;
  }
}

class _MemoryMessageStorage extends MessageStorage {
  final Map<String, List<Message>> values = {};

  @override
  Future<List<Message>> loadMessages(String roomId) async =>
      List<Message>.from(values[roomId] ?? const []);

  @override
  Future<void> saveMessages(String roomId, List<Message> messages) async {
    values[roomId] = List<Message>.from(messages);
  }
}

class _MemoryChatCache extends ChatCache {
  @override
  Future<List<Chat>?> loadChats() async => const [];

  @override
  Future<void> saveChats(List<Chat> chats) async {}
}
