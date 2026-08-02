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
}
