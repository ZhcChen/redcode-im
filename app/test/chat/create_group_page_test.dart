import 'package:app/core/services/friend_service.dart';
import 'package:app/core/services/friend_store.dart';
import 'package:app/features/auth/models/auth_user.dart';
import 'package:app/features/chat/create_group_page.dart';
import 'package:app/features/contacts/models/friend_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeFriendService extends FriendService {
  _FakeFriendService({
    required this.friends,
    this.throwOnFetch = false,
    this.delay = Duration.zero,
  });

  final List<FriendInfo> friends;
  final bool throwOnFetch;
  final Duration delay;

  @override
  Future<List<FriendInfo>> fetchFriends() async {
    if (delay > Duration.zero) {
      await Future<void>.delayed(delay);
    }
    if (throwOnFetch) {
      throw FriendServiceException('network failed');
    }
    return friends;
  }
}

FriendInfo _friend({
  required String id,
  required String username,
  String? nickname,
}) {
  return FriendInfo(
    id: 'friendship-$id',
    user: AuthUser(id: id, username: username, nickname: nickname),
    createdAt: DateTime(2026, 7, 25, 12),
  );
}

void _clearFriendStoreSnapshot() {
  final snapshot = List<FriendInfo>.from(FriendStore.instance.friends);
  for (final friend in snapshot) {
    FriendStore.instance.removeFriendByUserId(friend.user.id);
  }
}

void main() {
  setUp(() {
    _clearFriendStoreSnapshot();
  });

  tearDown(() {
    _clearFriendStoreSnapshot();
  });

  testWidgets('创建群聊页会复用全局好友快照作为成员候选', (tester) async {
    final cachedFriend = _friend(id: 'u-1', username: 'alice', nickname: '爱丽丝');
    FriendStore.instance.upsertFriend(cachedFriend);

    await tester.pumpWidget(
      MaterialApp(
        home: CreateGroupPage(
          friendService: _FakeFriendService(friends: const <FriendInfo>[]),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    await tester.tap(find.text('添加好友'));
    await tester.pumpAndSettle();

    expect(find.text('选择群成员'), findsOneWidget);
    expect(find.text('爱丽丝'), findsOneWidget);
    expect(find.text('alice'), findsOneWidget);
  });

  testWidgets('已有快照且拉取失败时仍保留候选好友且不提示报错', (tester) async {
    final cachedFriend = _friend(id: 'u-2', username: 'bob', nickname: '鲍勃');
    FriendStore.instance.upsertFriend(cachedFriend);

    await tester.pumpWidget(
      MaterialApp(
        home: CreateGroupPage(
          friendService: _FakeFriendService(
            friends: const <FriendInfo>[],
            throwOnFetch: true,
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.textContaining('获取好友列表失败'), findsNothing);

    await tester.tap(find.text('添加好友'));
    await tester.pumpAndSettle();

    expect(find.text('选择群成员'), findsOneWidget);
    expect(find.text('鲍勃'), findsOneWidget);
    expect(find.textContaining('获取好友列表失败'), findsNothing);
  });

  testWidgets('已有快照时刷新未完成也可以直接打开好友选择器', (tester) async {
    final cachedFriend = _friend(
      id: 'u-3',
      username: 'carol',
      nickname: '缓存好友',
    );
    FriendStore.instance.upsertFriend(cachedFriend);

    await tester.pumpWidget(
      MaterialApp(
        home: CreateGroupPage(
          friendService: _FakeFriendService(
            friends: const <FriendInfo>[],
            delay: const Duration(seconds: 1),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('正在刷新好友列表...'), findsOneWidget);

    await tester.tap(find.text('添加好友'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.text('选择群成员'), findsOneWidget);
    expect(find.text('缓存好友'), findsOneWidget);

    await tester.pump(const Duration(seconds: 1));
    await tester.pump();
  });

  testWidgets('HTTP 返回非空好友列表时会覆盖旧快照', (tester) async {
    final cachedFriend = _friend(id: 'u-4', username: 'carol', nickname: '旧好友');
    final refreshedFriend = _friend(
      id: 'u-5',
      username: 'dave',
      nickname: '新好友',
    );
    FriendStore.instance.upsertFriend(cachedFriend);

    await tester.pumpWidget(
      MaterialApp(
        home: CreateGroupPage(
          friendService: _FakeFriendService(
            friends: <FriendInfo>[refreshedFriend],
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    await tester.tap(find.text('添加好友'));
    await tester.pumpAndSettle();

    expect(find.text('新好友'), findsOneWidget);
    expect(find.text('dave'), findsOneWidget);
    expect(find.text('旧好友'), findsNothing);
    expect(find.text('carol'), findsNothing);
  });

  testWidgets('没有快照且拉取失败时才提示获取好友列表失败', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: CreateGroupPage(
          friendService: _FakeFriendService(
            friends: const <FriendInfo>[],
            throwOnFetch: true,
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.textContaining('获取好友列表失败'), findsOneWidget);
    expect(find.text('点击右上角按钮，选择至少一位好友加入群聊'), findsOneWidget);
  });
}
