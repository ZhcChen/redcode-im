import 'package:app/core/services/friend_service.dart';
import 'package:app/features/auth/models/auth_user.dart';
import 'package:app/features/contacts/contact_detail_page.dart';
import 'package:app/features/contacts/models/friend_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeFriendService extends FriendService {
  String? updatedRemark;
  String? updatedUserId;

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
}
