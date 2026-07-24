import 'package:app/features/auth/models/auth_user.dart';
import 'package:app/features/contacts/add_friend_page.dart';
import 'package:app/features/contacts/models/friend_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

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
  });
}
