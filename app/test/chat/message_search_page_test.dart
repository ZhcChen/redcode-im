import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/core/services/app_config_service.dart';
import 'package:app/core/services/message_service.dart';
import 'package:app/core/services/settings_service.dart';
import 'package:app/core/storage/app_config_storage.dart';
import 'package:app/core/storage/message_search_storage.dart';
import 'package:app/core/storage/message_storage.dart';
import 'package:app/features/chat/message_search_page.dart';
import 'package:app/features/chat/models/chat_model.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeAppConfigService extends AppConfigService {
  _FakeAppConfigService({required MessageRuntimeSettings runtime})
    : _runtime = runtime,
      super(
        storage: const AppConfigStorage(),
        settingsService: SettingsService(),
      );

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

class _FakeMessageSearchStorage extends MessageSearchStorage {
  _FakeMessageSearchStorage({required this.response});

  final MessageSearchResponse response;
  int searchCalls = 0;

  @override
  Future<MessageSearchResponse> searchMessages({
    required String query,
    String? roomId,
    String? senderId,
    String? messageType,
    int? dateFromMs,
    int? dateToMs,
    int limit = 50,
    int offset = 0,
  }) async {
    searchCalls += 1;
    return response;
  }

  @override
  Future<void> replaceRoomIndex({
    required String roomId,
    required String roomName,
    required List<dynamic> messages,
    int maxMessages = 200,
  }) async {}
}

class _FakeMessageStorage extends MessageStorage {
  const _FakeMessageStorage();

  @override
  Future<List<String>> listRoomIds() async => const <String>[];
}

class _FakeSearchMessageService extends ChangeNotifier
    implements MessageService {
  _FakeSearchMessageService({required this.seedChats});

  final List<Chat> seedChats;

  @override
  List<Chat> get chats => List<Chat>.from(seedChats);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('search input keeps text vertically centered', (tester) async {
    final searchStorage = _FakeMessageSearchStorage(
      response: MessageSearchResponse(
        results: const <MessageSearchResult>[],
        stats: const MessageSearchStats(
          totalResults: 0,
          searchTimeMs: 1,
          query: '',
        ),
        hasMore: false,
      ),
    );
    const messageStorage = _FakeMessageStorage();
    final messageService = _FakeSearchMessageService(seedChats: const <Chat>[]);

    await tester.pumpWidget(
      MaterialApp(
        home: MessageSearchPage(
          searchStorage: searchStorage,
          messageStorage: messageStorage,
          messageService: messageService,
          appConfigService: _FakeAppConfigService(
            runtime: const MessageRuntimeSettings(
              serverStorageMode: 'relay_only',
              contentAuditMode: 'plaintext',
            ),
          ),
          httpClient: MockClient((request) async {
            return http.Response('unexpected', 500);
          }),
        ),
      ),
    );
    await tester.pump();

    final field = tester.widget<TextField>(find.byType(TextField).first);
    expect(field.textAlignVertical, TextAlignVertical.center);
  });

  testWidgets('relay_only shows local cache hint and skips server search', (
    tester,
  ) async {
    final searchStorage = _FakeMessageSearchStorage(
      response: MessageSearchResponse(
        results: const <MessageSearchResult>[
          MessageSearchResult(
            id: 'msg-1',
            roomId: 'room-1',
            roomName: '缓存会话',
            senderId: 'user-1',
            senderName: 'Alice',
            content: 'hello relay only',
            messageType: 'text',
            timestampMs: 1712812800000,
            relevanceScore: 0.9,
          ),
        ],
        stats: const MessageSearchStats(
          totalResults: 1,
          searchTimeMs: 1,
          query: 'hello',
        ),
        hasMore: false,
      ),
    );
    const messageStorage = _FakeMessageStorage();
    final messageService = _FakeSearchMessageService(
      seedChats: <Chat>[
        Chat(
          id: 'chat-1',
          roomId: 'room-1',
          name: '缓存会话',
          type: ChatType.single,
          lastMessage: 'hello',
          lastMessageTime: DateTime(2026, 4, 11, 12, 0, 0),
        ),
      ],
    );
    var httpCalls = 0;
    final httpClient = MockClient((request) async {
      httpCalls += 1;
      return http.Response('unexpected', 500);
    });

    await tester.pumpWidget(
      MaterialApp(
        home: MessageSearchPage(
          initialRoomId: 'room-1',
          searchStorage: searchStorage,
          messageStorage: messageStorage,
          messageService: messageService,
          appConfigService: _FakeAppConfigService(
            runtime: const MessageRuntimeSettings(
              serverStorageMode: 'relay_only',
              contentAuditMode: 'plaintext',
            ),
          ),
          httpClient: httpClient,
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), 'hello');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();

    expect(find.text('当前仅搜索本地缓存消息'), findsOneWidget);
    expect(find.text('共 1 条'), findsOneWidget);
    expect(searchStorage.searchCalls, 1);
    expect(httpCalls, 0);
  });

  testWidgets(
    'runtime change to relay_only refreshes search to local-only mode',
    (tester) async {
      final searchStorage = _FakeMessageSearchStorage(
        response: MessageSearchResponse(
          results: const <MessageSearchResult>[
            MessageSearchResult(
              id: 'msg-1',
              roomId: 'room-1',
              roomName: '缓存会话',
              senderId: 'user-1',
              senderName: 'Alice',
              content: 'hello relay only',
              messageType: 'text',
              timestampMs: 1712812800000,
              relevanceScore: 0.9,
            ),
          ],
          stats: const MessageSearchStats(
            totalResults: 1,
            searchTimeMs: 1,
            query: 'hello',
          ),
          hasMore: false,
        ),
      );
      const messageStorage = _FakeMessageStorage();
      final messageService = _FakeSearchMessageService(
        seedChats: <Chat>[
          Chat(
            id: 'chat-1',
            roomId: 'room-1',
            name: '缓存会话',
            type: ChatType.single,
            lastMessage: 'hello',
            lastMessageTime: DateTime(2026, 4, 11, 12, 0, 0),
          ),
        ],
      );
      final httpClient = MockClient((request) async {
        return http.Response(
          jsonEncode(<String, Object?>{
            'results': <Object?>[],
            'stats': <String, Object?>{
              'total_results': 0,
              'search_time_ms': 1,
              'query': 'hello',
            },
            'has_more': false,
          }),
          200,
          headers: <String, String>{'content-type': 'application/json'},
        );
      });
      final appConfigService = _FakeAppConfigService(
        runtime: const MessageRuntimeSettings(
          serverStorageMode: 'persist',
          contentAuditMode: 'plaintext',
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: MessageSearchPage(
            initialRoomId: 'room-1',
            searchStorage: searchStorage,
            messageStorage: messageStorage,
            messageService: messageService,
            appConfigService: appConfigService,
            httpClient: httpClient,
          ),
        ),
      );

      await tester.enterText(find.byType(TextField), 'hello');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();

      expect(find.text('当前仅搜索本地缓存消息'), findsNothing);

      appConfigService.updateRuntime(
        const MessageRuntimeSettings(
          serverStorageMode: 'relay_only',
          contentAuditMode: 'plaintext',
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();

      expect(find.text('当前仅搜索本地缓存消息'), findsOneWidget);
      expect(searchStorage.searchCalls, 2);
    },
  );

  testWidgets('tapping a deduplicated result returns the target message', (
    tester,
  ) async {
    const result = MessageSearchResult(
      id: 'msg-target',
      roomId: 'room-1',
      roomName: '目标会话',
      senderId: 'user-1',
      senderName: 'Alice',
      content: '需要定位的消息',
      messageType: 'text',
      timestampMs: 1712812800000,
      relevanceScore: 1,
    );
    final searchStorage = _FakeMessageSearchStorage(
      response: const MessageSearchResponse(
        results: <MessageSearchResult>[result, result],
        stats: MessageSearchStats(
          totalResults: 1,
          searchTimeMs: 1,
          query: '定位',
        ),
        hasMore: false,
      ),
    );
    MessageSearchResult? selected;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                selected = await Navigator.of(context).push(
                  MaterialPageRoute<MessageSearchResult>(
                    builder: (_) => MessageSearchPage(
                      searchStorage: searchStorage,
                      messageStorage: const _FakeMessageStorage(),
                      messageService: _FakeSearchMessageService(
                        seedChats: const <Chat>[],
                      ),
                      appConfigService: _FakeAppConfigService(
                        runtime: const MessageRuntimeSettings(
                          serverStorageMode: 'relay_only',
                          contentAuditMode: 'plaintext',
                        ),
                      ),
                      httpClient: MockClient(
                        (_) async => http.Response('unexpected', 500),
                      ),
                    ),
                  ),
                );
              },
              child: const Text('打开搜索'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('打开搜索'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '定位');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();

    final resultText = find.text('需要定位的消息', findRichText: true);
    expect(resultText, findsOneWidget);
    await tester.tap(resultText);
    await tester.pumpAndSettle();
    expect(selected?.id, 'msg-target');
  });
}
