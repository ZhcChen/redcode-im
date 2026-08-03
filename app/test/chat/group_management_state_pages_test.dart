import 'package:app/core/services/room_service.dart';
import 'package:app/core/theme/screen_adaptation.dart';
import 'package:app/features/chat/group_admin_management_page.dart';
import 'package:app/features/chat/group_join_requests_page.dart';
import 'package:app/features/chat/group_mute_management_page.dart';
import 'package:app/features/chat/group_operation_logs_page.dart';
import 'package:app/features/chat/group_rules_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _RetryRoomService extends RoomService {
  _RetryRoomService({required this.failureTarget});

  final String failureTarget;
  final Map<String, int> calls = <String, int>{};

  bool _shouldFail(String target) {
    final count = (calls[target] ?? 0) + 1;
    calls[target] = count;
    return failureTarget == target && count == 1;
  }

  @override
  Future<List<GroupAdmin>> listAdmins(String roomId) async {
    if (_shouldFail('admins')) throw RoomServiceException('network');
    return <GroupAdmin>[];
  }

  @override
  Future<List<JoinRequest>> listJoinRequests(String roomId) async {
    if (_shouldFail('requests')) throw RoomServiceException('network');
    return <JoinRequest>[];
  }

  @override
  Future<List<GroupMute>> listMutedUsers(String roomId) async {
    if (_shouldFail('mutes')) throw RoomServiceException('network');
    return <GroupMute>[];
  }

  @override
  Future<List<GroupRule>> listRules(String roomId) async {
    if (_shouldFail('rules')) throw RoomServiceException('network');
    return <GroupRule>[];
  }

  @override
  Future<List<GroupOperationLog>> listOperationLogs({
    required String roomId,
    int limit = 20,
    int offset = 0,
  }) async {
    if (_shouldFail('logs')) throw RoomServiceException('network');
    return <GroupOperationLog>[];
  }
}

class _PaginationRoomService extends RoomService {
  int calls = 0;

  @override
  Future<List<GroupOperationLog>> listOperationLogs({
    required String roomId,
    int limit = 20,
    int offset = 0,
  }) async {
    calls += 1;
    if (offset > 0) throw RoomServiceException('network');
    return List<GroupOperationLog>.generate(
      limit,
      (index) => GroupOperationLog(
        id: 'log-$index',
        roomId: roomId,
        operatorId: 'owner',
        operationType: 'update_group_settings',
        createdAt: DateTime(2026, 8, 2, 10, index),
      ),
    );
  }
}

class _MutationRoomService extends RoomService {
  _MutationRoomService({
    this.admins = const <GroupAdmin>[],
    this.requests = const <JoinRequest>[],
    this.mutes = const <GroupMute>[],
    this.rules = const <GroupRule>[],
  });

  List<GroupAdmin> admins;
  List<JoinRequest> requests;
  List<GroupMute> mutes;
  List<GroupRule> rules;
  String? removedAdminId;
  String? reviewedRequestId;
  String? reviewStatus;
  String? unmutedUserId;
  String? deletedRuleId;

  @override
  Future<List<GroupAdmin>> listAdmins(String roomId) async =>
      List<GroupAdmin>.from(admins);

  @override
  Future<void> removeAdmin({
    required String roomId,
    required String userId,
  }) async {
    removedAdminId = userId;
    admins = admins.where((item) => item.adminId != userId).toList();
  }

  @override
  Future<List<JoinRequest>> listJoinRequests(String roomId) async =>
      List<JoinRequest>.from(requests);

  @override
  Future<void> reviewJoinRequest({
    required String roomId,
    required String requestId,
    required String status,
    String? reviewMessage,
  }) async {
    reviewedRequestId = requestId;
    reviewStatus = status;
    requests = requests.where((item) => item.id != requestId).toList();
  }

  @override
  Future<List<GroupMute>> listMutedUsers(String roomId) async =>
      List<GroupMute>.from(mutes);

  @override
  Future<void> unmuteUser({
    required String roomId,
    required String userId,
  }) async {
    unmutedUserId = userId;
    mutes = mutes.where((item) => item.userId != userId).toList();
  }

  @override
  Future<List<GroupRule>> listRules(String roomId) async =>
      List<GroupRule>.from(rules);

  @override
  Future<void> deleteRule({
    required String roomId,
    required String ruleId,
  }) async {
    deletedRuleId = ruleId;
    rules = rules.where((item) => item.id != ruleId).toList();
  }
}

Widget _host(Widget child) {
  return AdaptiveScreenUtilInit(
    builder: (context, _) => MaterialApp(home: child),
  );
}

Future<void> _expectRetryFlow(
  WidgetTester tester, {
  required Widget page,
  required String errorText,
  required String emptyText,
}) async {
  await tester.pumpWidget(_host(page));
  await tester.pumpAndSettle();

  expect(find.text(errorText), findsOneWidget);
  expect(find.text(emptyText), findsNothing);

  await tester.tap(find.text('重新加载'));
  await tester.pumpAndSettle();

  expect(find.text(errorText), findsNothing);
  expect(find.text(emptyText), findsOneWidget);
}

void main() {
  const members = <Map<String, dynamic>>[
    <String, dynamic>{'user_id': 'owner', 'nickname': '群主', 'role': 'owner'},
  ];

  testWidgets('管理员列表加载失败后可重试', (tester) async {
    final service = _RetryRoomService(failureTarget: 'admins');
    await _expectRetryFlow(
      tester,
      page: GroupAdminManagementPage(
        roomId: 'room-1',
        members: members,
        roomService: service,
      ),
      errorText: '无法加载管理员列表',
      emptyText: '暂无管理员',
    );
  });

  testWidgets('入群申请加载失败后可重试', (tester) async {
    final service = _RetryRoomService(failureTarget: 'requests');
    await _expectRetryFlow(
      tester,
      page: GroupJoinRequestsPage(roomId: 'room-1', roomService: service),
      errorText: '无法加载入群申请',
      emptyText: '暂无入群申请',
    );
  });

  testWidgets('禁言列表加载失败后可重试', (tester) async {
    final service = _RetryRoomService(failureTarget: 'mutes');
    await _expectRetryFlow(
      tester,
      page: GroupMuteManagementPage(
        roomId: 'room-1',
        members: members,
        roomService: service,
      ),
      errorText: '无法加载禁言列表',
      emptyText: '暂无被禁言的成员',
    );
  });

  testWidgets('群规加载失败后可重试', (tester) async {
    final service = _RetryRoomService(failureTarget: 'rules');
    await _expectRetryFlow(
      tester,
      page: GroupRulesPage(roomId: 'room-1', roomService: service),
      errorText: '无法加载群规',
      emptyText: '暂无群规',
    );
  });

  testWidgets('操作日志首次加载失败后可重试', (tester) async {
    final service = _RetryRoomService(failureTarget: 'logs');
    await _expectRetryFlow(
      tester,
      page: GroupOperationLogsPage(
        roomId: 'room-1',
        members: members,
        roomService: service,
      ),
      errorText: '无法加载操作日志',
      emptyText: '暂无操作日志',
    );
  });

  testWidgets('操作日志加载更多失败时保留已有内容', (tester) async {
    final service = _PaginationRoomService();
    await tester.pumpWidget(
      _host(
        GroupOperationLogsPage(
          roomId: 'room-1',
          members: members,
          roomService: service,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('群主', findRichText: true), findsWidgets);
    await tester.scrollUntilVisible(
      find.text('加载更多'),
      500,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('加载更多'));
    await tester.pumpAndSettle();

    expect(service.calls, 2);
    expect(find.text('加载更多失败，请重试'), findsOneWidget);
    expect(find.textContaining('群主', findRichText: true), findsWidgets);
    expect(find.text('加载更多'), findsOneWidget);
  });

  testWidgets('移除管理员后刷新管理员列表', (tester) async {
    final service = _MutationRoomService(
      admins: <GroupAdmin>[
        GroupAdmin(
          id: 'admin-record-1',
          roomId: 'room-1',
          adminId: 'admin-1',
          appointedBy: 'owner',
          role: 'admin',
          appointedAt: DateTime(2026, 8, 2),
        ),
      ],
    );
    await tester.pumpWidget(
      _host(
        GroupAdminManagementPage(
          roomId: 'room-1',
          members: const <Map<String, dynamic>>[
            <String, dynamic>{
              'user_id': 'admin-1',
              'nickname': '管理员甲',
              'role': 'admin',
            },
          ],
          roomService: service,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('移除'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('确定'));
    await tester.pumpAndSettle();

    expect(service.removedAdminId, 'admin-1');
    expect(find.text('暂无管理员'), findsOneWidget);
  });

  testWidgets('通过入群申请后刷新申请列表', (tester) async {
    final service = _MutationRoomService(
      requests: <JoinRequest>[
        JoinRequest(
          id: 'request-1',
          roomId: 'room-1',
          applicantId: 'applicant-12345678',
          status: 'pending',
          createdAt: DateTime(2026, 8, 2),
        ),
      ],
    );
    await tester.pumpWidget(
      _host(GroupJoinRequestsPage(roomId: 'room-1', roomService: service)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('通过'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('确定'));
    await tester.pumpAndSettle();

    expect(service.reviewedRequestId, 'request-1');
    expect(service.reviewStatus, 'approved');
    expect(find.text('暂无入群申请'), findsOneWidget);
  });

  testWidgets('解除成员禁言后刷新禁言列表', (tester) async {
    final service = _MutationRoomService(
      mutes: <GroupMute>[
        GroupMute(
          id: 'mute-1',
          roomId: 'room-1',
          userId: 'member-1',
          mutedBy: 'owner',
          muteDurationHours: 24,
          mutedAt: DateTime.now(),
          isActive: true,
          muteUntil: DateTime.now().add(const Duration(hours: 24)),
        ),
      ],
    );
    await tester.pumpWidget(
      _host(
        GroupMuteManagementPage(
          roomId: 'room-1',
          members: const <Map<String, dynamic>>[
            <String, dynamic>{
              'user_id': 'member-1',
              'nickname': '成员甲',
              'role': 'member',
            },
          ],
          roomService: service,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('group-mute-add-button')), findsOneWidget);
    expect(find.byKey(const ValueKey('group-mute-record-成员甲')), findsOneWidget);
    expect(find.byKey(const ValueKey('group-mute-unmute-成员甲')), findsOneWidget);

    await tester.tap(find.text('解除'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('确定'));
    await tester.pumpAndSettle();

    expect(service.unmutedUserId, 'member-1');
    expect(find.text('暂无被禁言的成员'), findsOneWidget);
  });

  testWidgets('删除群规后刷新群规列表', (tester) async {
    final now = DateTime(2026, 8, 2);
    final service = _MutationRoomService(
      rules: <GroupRule>[
        GroupRule(
          id: 'rule-1',
          roomId: 'room-1',
          title: '禁止刷屏',
          content: '请勿连续发送重复内容',
          creatorId: 'owner',
          orderIndex: 0,
          isActive: true,
          createdAt: now,
          updatedAt: now,
        ),
      ],
    );
    await tester.pumpWidget(
      _host(
        GroupRulesPage(roomId: 'room-1', canManage: true, roomService: service),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('删除'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('确定'));
    await tester.pumpAndSettle();

    expect(service.deletedRuleId, 'rule-1');
    expect(find.text('暂无群规，点击右上角添加'), findsOneWidget);
  });
}
