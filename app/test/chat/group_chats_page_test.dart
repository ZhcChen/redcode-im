import 'package:app/core/services/app_config_service.dart';
import 'package:app/core/services/message_service.dart';
import 'package:app/core/services/settings_service.dart';
import 'package:app/core/services/websocket_service.dart';
import 'package:app/core/storage/app_config_storage.dart';
import 'package:app/core/theme/screen_adaptation.dart';
import 'package:app/features/chat/group_chats_page.dart';
import 'package:app/features/chat/group_settings_page.dart';
import 'package:app/features/chat/models/chat_model.dart';
import 'package:app/features/chat/providers/chat_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  int? cachedRoomMemberCount(String roomId) {
    final chat = _chats.where((item) => item.roomId == roomId).firstOrNull;
    final extra = chat?.extra;
    final raw = extra?['member_count'] ?? extra?['memberCount'];
    return raw is int ? raw : null;
  }

  @override
  Future<List<Map<String, dynamic>>> fetchRoomMembers(String roomId) async {
    return const <Map<String, dynamic>>[];
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
  bool isPinned = false,
  bool isMuted = false,
  Map<String, dynamic>? extra,
}) {
  return Chat(
    id: id,
    roomId: 'room-$id',
    name: name,
    type: type,
    lastMessage: 'last-$id',
    lastMessageTime: DateTime(2026, 7, 25, 10, 0),
    isPinned: isPinned,
    isMuted: isMuted,
    extra: extra,
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

Widget _buildHost(Widget child) {
  return _buildHostWithObservers(child);
}

Widget _buildHostWithObservers(
  Widget child, {
  List<NavigatorObserver> observers = const <NavigatorObserver>[],
}) {
  return AdaptiveScreenUtilInit(
    builder: (context, _) =>
        MaterialApp(home: child, navigatorObservers: observers),
  );
}

class _TestNavigatorObserver extends NavigatorObserver {
  int pushCount = 0;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    pushCount += 1;
    super.didPush(route, previousRoute);
  }
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('没有群聊时仍会进入真实群聊页并展示创建入口', (tester) async {
    final provider = _buildProvider(<Chat>[
      _buildChat(id: 'single-1', name: '单聊-张三', type: ChatType.single),
    ]);

    await tester.pumpWidget(_buildHost(GroupChatsPage(chatProvider: provider)));
    await tester.pump();
    await tester.pump();

    expect(find.text('群聊'), findsOneWidget);
    expect(find.text('还没有加入任何群聊'), findsOneWidget);
    expect(find.text('创建群聊'), findsOneWidget);
    expect(find.text('共 0 个群聊'), findsOneWidget);
  });

  testWidgets('群聊页只展示 group 类型会话', (tester) async {
    final provider = _buildProvider(<Chat>[
      _buildChat(id: 'group-1', name: '项目群', type: ChatType.group),
      _buildChat(id: 'single-1', name: '单聊-李四', type: ChatType.single),
      _buildChat(id: 'group-2', name: '测试群', type: ChatType.group),
    ]);

    await tester.pumpWidget(_buildHost(GroupChatsPage(chatProvider: provider)));
    await tester.pump();
    await tester.pump();

    expect(find.text('项目群'), findsOneWidget);
    expect(find.text('测试群'), findsOneWidget);
    expect(find.text('单聊-李四'), findsNothing);
    expect(find.text('共 2 个群聊'), findsOneWidget);
  });

  testWidgets('支持按群名搜索并展示空搜索态', (tester) async {
    final provider = _buildProvider(<Chat>[
      _buildChat(
        id: 'group-1',
        name: '项目群',
        type: ChatType.group,
        extra: const <String, dynamic>{'description': '核心项目讨论'},
      ),
      _buildChat(id: 'group-2', name: '测试群', type: ChatType.group),
    ]);

    await tester.pumpWidget(_buildHost(GroupChatsPage(chatProvider: provider)));
    await tester.pump();
    await tester.pump();

    await tester.enterText(find.byType(TextField), '项目');
    await tester.pump();

    expect(find.text('项目群'), findsOneWidget);
    expect(find.text('测试群'), findsNothing);

    await tester.enterText(find.byType(TextField), '不存在');
    await tester.pump();

    expect(find.text('未找到相关群聊'), findsOneWidget);
    expect(find.text('清空搜索'), findsOneWidget);

    await tester.tap(find.text('清空搜索'));
    await tester.pump();

    expect(find.text('项目群'), findsOneWidget);
    expect(find.text('测试群'), findsOneWidget);
  });

  testWidgets('群聊页展示置顶分组与群资料摘要', (tester) async {
    final provider = _buildProvider(<Chat>[
      _buildChat(
        id: 'group-1',
        name: '项目群',
        type: ChatType.group,
        isPinned: true,
        extra: const <String, dynamic>{
          'description': '核心项目讨论',
          'member_count': 12,
        },
      ),
      _buildChat(
        id: 'group-2',
        name: '测试群',
        type: ChatType.group,
        isMuted: true,
        extra: const <String, dynamic>{'description': '联调测试用'},
      ),
    ]);

    await tester.pumpWidget(_buildHost(GroupChatsPage(chatProvider: provider)));
    await tester.pump();
    await tester.pump();

    expect(find.text('置顶群聊'), findsOneWidget);
    expect(find.text('最近活跃'), findsOneWidget);
    expect(find.text('核心项目讨论'), findsOneWidget);
    expect(find.text('联调测试用'), findsOneWidget);
    expect(find.text('12 人'), findsOneWidget);
    expect(find.text('已置顶'), findsOneWidget);
    expect(find.text('免打扰'), findsOneWidget);
  });

  testWidgets('点击群资料摘要会进入群设置页', (tester) async {
    final observer = _TestNavigatorObserver();
    final provider = _buildProvider(<Chat>[
      _buildChat(
        id: 'group-1',
        name: '项目群',
        type: ChatType.group,
        extra: const <String, dynamic>{
          'description': '核心项目讨论',
          'member_count': 12,
        },
      ),
    ]);

    await tester.pumpWidget(
      _buildHostWithObservers(
        GroupChatsPage(chatProvider: provider),
        observers: <NavigatorObserver>[observer],
      ),
    );
    await tester.pump();
    await tester.pump();
    final basePushCount = observer.pushCount;

    await tester.tap(find.text('核心项目讨论'));
    await tester.pumpAndSettle();

    expect(find.byType(GroupSettingsPage), findsOneWidget);
    expect(observer.pushCount, basePushCount + 1);
  });

  testWidgets('长按群聊会打开操作面板', (tester) async {
    final provider = _buildProvider(<Chat>[
      _buildChat(
        id: 'group-1',
        name: '项目群',
        type: ChatType.group,
        isPinned: true,
      ),
    ]);

    await tester.pumpWidget(_buildHost(GroupChatsPage(chatProvider: provider)));
    await tester.pump();
    await tester.pump();

    await tester.longPress(find.text('项目群'));
    await tester.pumpAndSettle();

    expect(find.text('长按操作'), findsOneWidget);
    expect(find.text('查看群资料'), findsOneWidget);
    expect(find.text('取消置顶'), findsOneWidget);
    expect(find.text('设为免打扰'), findsOneWidget);
    expect(find.text('删除会话'), findsOneWidget);
  });

  testWidgets('长按菜单可进入群设置页', (tester) async {
    final observer = _TestNavigatorObserver();
    final provider = _buildProvider(<Chat>[
      _buildChat(id: 'group-1', name: '项目群', type: ChatType.group),
    ]);

    await tester.pumpWidget(
      _buildHostWithObservers(
        GroupChatsPage(chatProvider: provider),
        observers: <NavigatorObserver>[observer],
      ),
    );
    await tester.pump();
    await tester.pump();
    final basePushCount = observer.pushCount;

    await tester.longPress(find.text('项目群'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('查看群资料'));
    await tester.pumpAndSettle();

    expect(find.byType(GroupSettingsPage), findsOneWidget);
    expect(observer.pushCount, basePushCount + 2);
  });
}
