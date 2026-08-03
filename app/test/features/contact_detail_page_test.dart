import 'package:app/core/services/friend_service.dart';
import 'package:app/features/auth/models/auth_user.dart';
import 'package:app/features/contacts/contact_detail_page.dart';
import 'package:app/features/contacts/models/friend_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeFriendService extends FriendService {
  _FakeFriendService({this.deleteError});

  String? updatedRemark;
  String? updatedUserId;
  String? deletedUserId;
  final FriendServiceException? deleteError;

  @override
  Future<void> deleteFriend(String friendUserId) async {
    deletedUserId = friendUserId;
    if (deleteError != null) throw deleteError!;
  }

  @override
  Future<String?> updateFriendRemark(
    String friendUserId,
    String? remark,
  ) async {
    updatedUserId = friendUserId;
    updatedRemark = remark?.trim();
    return updatedRemark;
  }
}

void main() {
  testWidgets('联系人名片可设置好友备注并即时更新展示', (tester) async {
    final service = _FakeFriendService();
    final friend = FriendInfo(
      id: 'friendship-1',
      user: const AuthUser(id: 'user-2', username: 'bob', nickname: 'Bob'),
      createdAt: DateTime(2026, 8, 1),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: ContactDetailPage(friend: friend, friendService: service),
      ),
    );

    expect(find.text('未设置'), findsOneWidget);
    await tester.tap(find.byKey(const Key('contact-detail-remark')));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField), '项目负责人');
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    expect(service.updatedUserId, 'user-2');
    expect(service.updatedRemark, '项目负责人');
    expect(find.text('项目负责人'), findsOneWidget);
    expect(find.text('备注已更新'), findsOneWidget);
  });

  testWidgets('联系人名片提供举报入口并阻止空内容提交', (tester) async {
    final friend = FriendInfo(
      id: 'friendship-1',
      user: const AuthUser(id: 'user-2', username: 'bob'),
      createdAt: DateTime(2026, 8, 1),
    );
    await tester.pumpWidget(
      MaterialApp(home: ContactDetailPage(friend: friend)),
    );

    await tester.scrollUntilVisible(find.text('举报该用户'), 200);
    await tester.tap(find.text('举报该用户'));
    await tester.pumpAndSettle();

    expect(find.text('举报该用户'), findsWidgets);
    expect(find.text('选择截图'), findsOneWidget);
    await tester.tap(find.text('提交举报'));
    await tester.pumpAndSettle();

    expect(find.text('请输入举报内容'), findsOneWidget);
    expect(find.byKey(const Key('report-content')), findsOneWidget);
  });

  testWidgets('删除好友确认后调用服务并返回刷新标记', (tester) async {
    final service = _FakeFriendService();
    final friend = FriendInfo(
      id: 'friendship-1',
      user: const AuthUser(id: 'user-2', username: 'bob', nickname: 'Bob'),
      createdAt: DateTime(2026, 8, 1),
    );
    bool? deleted;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: ElevatedButton(
              onPressed: () async {
                deleted = await Navigator.of(context).push<bool>(
                  MaterialPageRoute(
                    builder: (_) => ContactDetailPage(
                      friend: friend,
                      friendService: service,
                    ),
                  ),
                );
              },
              child: const Text('打开名片'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('打开名片'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const Key('contact-detail-delete')),
      200,
    );
    await tester.tap(find.byKey(const Key('contact-detail-delete')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('删除').last);
    await tester.pumpAndSettle();

    expect(service.deletedUserId, 'user-2');
    expect(deleted, isTrue);
    expect(find.text('打开名片'), findsOneWidget);
  });

  testWidgets('删除好友失败时保留名片并展示服务错误', (tester) async {
    final service = _FakeFriendService(
      deleteError: FriendServiceException('好友关系已变更'),
    );
    final friend = FriendInfo(
      id: 'friendship-1',
      user: const AuthUser(id: 'user-2', username: 'bob', nickname: 'Bob'),
      createdAt: DateTime(2026, 8, 1),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: ContactDetailPage(friend: friend, friendService: service),
      ),
    );
    await tester.scrollUntilVisible(
      find.byKey(const Key('contact-detail-delete')),
      200,
    );
    await tester.tap(find.byKey(const Key('contact-detail-delete')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('删除').last);
    await tester.pumpAndSettle();

    expect(service.deletedUserId, 'user-2');
    expect(find.text('联系人名片'), findsOneWidget);
    expect(find.text('好友关系已变更'), findsOneWidget);
  });
}
