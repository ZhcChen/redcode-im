import 'package:app/core/services/friend_service.dart';
import 'package:app/core/services/message_service.dart';
import 'package:app/core/services/websocket_service.dart';
import 'package:app/features/auth/models/auth_user.dart';
import 'package:app/features/chat/models/chat_model.dart';
import 'package:app/features/chat/models/message_model.dart';
import 'package:app/features/contacts/add_friend_page.dart';
import 'package:app/features/contacts/models/friend_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeFriendService extends FriendService {
  _FakeFriendService({
    required this.respondedRequest,
    required this.ensureChatResult,
  });

  final FriendRequestInfo respondedRequest;
  final EnsureChatResult ensureChatResult;
  int respondCalls = 0;
  int ensureChatCalls = 0;

  @override
  Future<FriendRequestInfo> respondFriendRequest(
    String requestId,
    FriendRequestAction action,
  ) async {
    respondCalls += 1;
    return respondedRequest;
  }

  @override
  Future<EnsureChatResult> ensurePrivateChat(String friendUserId) async {
    ensureChatCalls += 1;
    return ensureChatResult;
  }
}

class _FakeMessageService extends MessageService {
  _FakeMessageService();

  int loadMessagesCalls = 0;
  int fetchChatsCalls = 0;
  int handleWebSocketMessageCalls = 0;
  String? lastLoadedRoomId;
  bool lastFetchForce = false;

  @override
  Future<List<Message>> loadMessages(
    String roomId, {
    int limit = 50,
    String? beforeId,
    String? sinceId,
  }) async {
    loadMessagesCalls += 1;
    lastLoadedRoomId = roomId;
    return const <Message>[];
  }

  @override
  Future<List<Chat>> fetchChats({bool force = false}) async {
    fetchChatsCalls += 1;
    lastFetchForce = force;
    return const <Chat>[];
  }

  @override
  Future<void> handleWebSocketMessage(WebSocketMessage wsMessage) async {
    handleWebSocketMessageCalls += 1;
  }
}

class _FakeWebSocketService extends WebSocketService {
  _FakeWebSocketService({required MessageService messageService})
    : super(messageService: messageService) {
    dispose();
  }

  final List<String> joinedRooms = <String>[];

  @override
  Future<void> joinRoom(String roomId) async {
    joinedRooms.add(roomId);
  }
}

AuthUser _buildUser({
  required String id,
  required String username,
  String? email,
  String? nickname,
}) {
  return AuthUser(id: id, username: username, email: email, nickname: nickname);
}

FriendRequestInfo _buildRequest({
  required String id,
  required AuthUser requester,
  required AuthUser addressee,
  required bool isIncoming,
  String? message,
  DateTime? createdAt,
}) {
  return FriendRequestInfo(
    id: id,
    requester: requester,
    addressee: addressee,
    status: FriendRequestStatus.pending,
    createdAt: createdAt ?? DateTime.now(),
    message: message,
    isIncoming: isIncoming,
  );
}

Widget _buildHost(AddFriendPage page) {
  return MaterialApp(home: page);
}

void main() {
  group('AddFriendPage', () {
    setUp(() {
      SharedPreferences.setMockInitialValues(<String, Object>{});
    });

    testWidgets('支持通过注入初始搜索结果渲染优化后的卡片', (tester) async {
      final currentUser = _buildUser(
        id: 'self-1',
        username: 'chen',
        nickname: '测试自己',
      );
      final targetUser = _buildUser(
        id: 'user-1',
        username: 'alice',
        email: 'alice@example.com',
        nickname: 'Alice',
      );

      await tester.pumpWidget(
        _buildHost(
          AddFriendPage(
            skipInitialLoad: true,
            initialCurrentUser: currentUser,
            initialSearchResults: [targetUser],
          ),
        ),
      );

      expect(find.text('搜索结果'), findsOneWidget);
      expect(find.text('Alice'), findsOneWidget);
      expect(find.text('alice@example.com'), findsOneWidget);
      expect(find.text('发送申请时可附上一句打招呼内容，方便对方更快识别你。'), findsOneWidget);
      expect(find.widgetWithText(ElevatedButton, '添加好友'), findsOneWidget);
    });

    testWidgets('点击添加好友会弹出新的附言内容区', (tester) async {
      final currentUser = _buildUser(
        id: 'self-1',
        username: 'chen',
        nickname: '测试自己',
      );
      final targetUser = _buildUser(
        id: 'user-1',
        username: 'alice',
        email: 'alice@example.com',
        nickname: 'Alice',
      );

      await tester.pumpWidget(
        _buildHost(
          AddFriendPage(
            skipInitialLoad: true,
            initialCurrentUser: currentUser,
            initialSearchResults: [targetUser],
          ),
        ),
      );

      await tester.tap(find.widgetWithText(ElevatedButton, '添加好友'));
      await tester.pumpAndSettle();

      expect(find.text('添加好友'), findsNWidgets(2));
      expect(find.text('附言'), findsOneWidget);
      expect(find.text('向对方简单介绍自己，方便更快通过。'), findsOneWidget);
      expect(find.text('Alice'), findsNWidgets(2));

      final fields = tester
          .widgetList<TextField>(find.byType(TextField))
          .toList();
      final dialogField = fields.last;
      expect(dialogField.controller?.text, contains('测试自己'));
    });

    testWidgets('我发出的申请会展示附言和等待确认状态', (tester) async {
      final currentUser = _buildUser(
        id: 'self-1',
        username: 'chen',
        nickname: '测试自己',
      );
      final targetUser = _buildUser(
        id: 'user-2',
        username: 'bob',
        email: 'bob@example.com',
        nickname: 'Bob',
      );
      final outgoing = _buildRequest(
        id: 'req-1',
        requester: currentUser,
        addressee: targetUser,
        isIncoming: false,
        message: '备注一下，我是陈晨',
        createdAt: DateTime.now().subtract(const Duration(hours: 2)),
      );

      await tester.pumpWidget(
        _buildHost(
          AddFriendPage(
            skipInitialLoad: true,
            initialCurrentUser: currentUser,
            initialOutgoingRequests: [outgoing],
          ),
        ),
      );

      expect(find.text('我发出的申请'), findsOneWidget);
      expect(find.text('Bob'), findsOneWidget);
      expect(find.text('我的附言'), findsOneWidget);
      expect(find.text('备注一下，我是陈晨'), findsOneWidget);
      expect(find.text('等待确认'), findsOneWidget);
      expect(find.text('2 小时前'), findsOneWidget);
    });

    testWidgets('同意好友申请后同步真实消息而不是伪造本地打招呼消息', (tester) async {
      final currentUser = _buildUser(
        id: 'self-1',
        username: 'chen',
        nickname: '测试自己',
      );
      final requester = _buildUser(
        id: 'user-3',
        username: 'alice',
        email: 'alice@example.com',
        nickname: 'Alice',
      );
      final incoming = _buildRequest(
        id: 'req-incoming-1',
        requester: requester,
        addressee: currentUser,
        isIncoming: true,
        message: '你好，我想加你',
      );
      final accepted = FriendRequestInfo(
        id: incoming.id,
        requester: requester,
        addressee: currentUser,
        status: FriendRequestStatus.accepted,
        createdAt: incoming.createdAt,
        message: incoming.message,
        isIncoming: true,
      );
      final messageService = _FakeMessageService();
      final websocketService = _FakeWebSocketService(
        messageService: messageService,
      );
      addTearDown(messageService.dispose);
      final friendService = _FakeFriendService(
        respondedRequest: accepted,
        ensureChatResult: const EnsureChatResult(
          roomId: 'room-accept-1',
          roomName: 'Alice',
          roomType: 'private',
          friendId: 'user-3',
          friendName: 'Alice',
        ),
      );

      await tester.pumpWidget(
        _buildHost(
          AddFriendPage(
            skipInitialLoad: true,
            initialCurrentUser: currentUser,
            initialIncomingRequests: [incoming],
            friendService: friendService,
            websocketService: websocketService,
            messageService: messageService,
          ),
        ),
      );

      await tester.tap(find.widgetWithText(ElevatedButton, '同意'));
      await tester.pump();

      expect(friendService.respondCalls, 1);
      expect(friendService.ensureChatCalls, 1);
      expect(websocketService.joinedRooms, <String>['room-accept-1']);
      expect(messageService.loadMessagesCalls, 1);
      expect(messageService.lastLoadedRoomId, 'room-accept-1');
      expect(messageService.fetchChatsCalls, 1);
      expect(messageService.lastFetchForce, isTrue);
      expect(messageService.handleWebSocketMessageCalls, 0);
    });
  });
}
