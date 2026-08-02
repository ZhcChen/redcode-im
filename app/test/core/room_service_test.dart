import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:app/core/services/room_service.dart';
import 'package:app/core/storage/token_storage.dart';
import 'package:app/features/auth/models/auth_session.dart';
import 'package:app/features/auth/models/auth_user.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

class _FakeTokenStorage extends TokenStorage {
  const _FakeTokenStorage(this._session);

  final AuthSession? _session;

  @override
  Future<AuthSession?> readSession() async => _session;
}

void main() {
  group('RoomService', () {
    const session = AuthSession(
      token: 'token-room',
      user: AuthUser(id: 'u-1', username: 'alice'),
    );

    test('updateRoom sends PATCH and returns updated room', () async {
      http.Request? capturedRequest;
      final service = RoomService(
        tokenStorage: const _FakeTokenStorage(session),
        client: MockClient((request) async {
          capturedRequest = request;
          return http.Response(
            jsonEncode({
              'success': true,
              'message': 'ok',
              'room': {
                'id': 'room-1',
                'name': '新群名称',
                'room_type': 'group',
                'description': '新的群描述',
                'owner_id': 'u-1',
              },
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      );

      final room = await service.updateRoom(
        roomId: 'room-1',
        name: '新群名称',
        description: '新的群描述',
      );

      expect(capturedRequest, isNotNull);
      expect(capturedRequest!.method, 'PATCH');
      expect(capturedRequest!.url.path, '/rooms/room-1');
      expect(capturedRequest!.headers['Authorization'], 'Bearer token-room');
      expect(jsonDecode(capturedRequest!.body), {
        'name': '新群名称',
        'description': '新的群描述',
      });
      expect(room.id, 'room-1');
      expect(room.name, '新群名称');
      expect(room.description, '新的群描述');
    });

    test('addMembers sends user_ids and parses added/skipped ids', () async {
      http.Request? capturedRequest;
      final service = RoomService(
        tokenStorage: const _FakeTokenStorage(session),
        client: MockClient((request) async {
          capturedRequest = request;
          return http.Response(
            jsonEncode({
              'success': true,
              'added_user_ids': ['u-2', 'u-3'],
              'skipped_user_ids': ['u-4'],
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      );

      final result = await service.addMembers(
        roomId: 'room-1',
        userIds: const ['u-2', 'u-3', 'u-4'],
      );

      expect(capturedRequest, isNotNull);
      expect(capturedRequest!.method, 'POST');
      expect(capturedRequest!.url.path, '/rooms/room-1/members/add');
      expect(jsonDecode(capturedRequest!.body), {
        'user_ids': ['u-2', 'u-3', 'u-4'],
      });
      expect(result.addedUserIds, ['u-2', 'u-3']);
      expect(result.skippedUserIds, ['u-4']);
    });

    test('removeMember sends DELETE request to member endpoint', () async {
      http.Request? capturedRequest;
      final service = RoomService(
        tokenStorage: const _FakeTokenStorage(session),
        client: MockClient((request) async {
          capturedRequest = request;
          return http.Response(
            jsonEncode({'success': true}),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      );

      await service.removeMember(roomId: 'room-1', userId: 'u-2');

      expect(capturedRequest, isNotNull);
      expect(capturedRequest!.method, 'DELETE');
      expect(capturedRequest!.url.path, '/rooms/room-1/members/u-2');
      expect(capturedRequest!.headers['Authorization'], 'Bearer token-room');
    });

    test(
      'createInvitations sends normalized users and parses invitations',
      () async {
        http.Request? capturedRequest;
        final service = RoomService(
          tokenStorage: const _FakeTokenStorage(session),
          client: MockClient((request) async {
            capturedRequest = request;
            return http.Response(
              jsonEncode({
                'invitations': [
                  {
                    'id': 'invitation-1',
                    'room_id': 'room-1',
                    'inviter_id': 'u-1',
                    'invitee_id': 'u-2',
                    'message': '一起讨论项目',
                    'status': 0,
                    'invited_at': '2026-08-02T10:00:00Z',
                    'responded_at': null,
                    'expires_at': '2026-08-09T10:00:00Z',
                  },
                ],
              }),
              200,
              headers: {'content-type': 'application/json'},
            );
          }),
        );

        final invitations = await service.createInvitations(
          roomId: 'room-1',
          userIds: const [' u-2 ', 'u-2'],
          message: ' 一起讨论项目 ',
        );

        expect(capturedRequest!.method, 'POST');
        expect(capturedRequest!.url.path, '/rooms/room-1/invitations');
        expect(jsonDecode(capturedRequest!.body), {
          'user_ids': ['u-2'],
          'message': '一起讨论项目',
        });
        expect(invitations, hasLength(1));
        expect(invitations.single.id, 'invitation-1');
        expect(invitations.single.status, 'pending');
        expect(invitations.single.inviteeId, 'u-2');
      },
    );

    test(
      'listReceivedInvitations sends status and parses display fields',
      () async {
        http.Request? capturedRequest;
        final service = RoomService(
          tokenStorage: const _FakeTokenStorage(session),
          client: MockClient((request) async {
            capturedRequest = request;
            return http.Response(
              jsonEncode({
                'invitations': [
                  {
                    'id': 'invitation-1',
                    'room_id': 'room-1',
                    'room_name': '产品群',
                    'room_avatar_url': 'https://example.test/group.png',
                    'inviter_id': 'u-2',
                    'inviter_name': 'Bob',
                    'invitee_id': 'u-1',
                    'message': '欢迎加入',
                    'status': 0,
                    'invited_at': '2026-08-02T10:00:00Z',
                    'responded_at': null,
                    'expires_at': '2026-08-09T10:00:00Z',
                  },
                ],
              }),
              200,
              headers: {'content-type': 'application/json'},
            );
          }),
        );

        final invitations = await service.listReceivedInvitations(
          status: 'all',
        );

        expect(capturedRequest!.method, 'GET');
        expect(capturedRequest!.url.path, '/group-invitations');
        expect(capturedRequest!.url.queryParameters, {'status': 'all'});
        expect(invitations.single.roomName, '产品群');
        expect(
          invitations.single.roomAvatarUrl,
          'https://example.test/group.png',
        );
        expect(invitations.single.inviterName, 'Bob');
        expect(invitations.single.status, 'pending');
      },
    );

    test('respondToInvitation sends PATCH and accepts 204 response', () async {
      http.Request? capturedRequest;
      final service = RoomService(
        tokenStorage: const _FakeTokenStorage(session),
        client: MockClient((request) async {
          capturedRequest = request;
          return http.Response('', 204);
        }),
      );

      await service.respondToInvitation(
        roomId: 'room-1',
        invitationId: 'invitation-1',
        status: 'accepted',
      );

      expect(capturedRequest!.method, 'PATCH');
      expect(
        capturedRequest!.url.path,
        '/rooms/room-1/invitations/invitation-1/respond',
      );
      expect(jsonDecode(capturedRequest!.body), {'status': 'accepted'});
    });

    test(
      'respondToInvitation rejects unsupported status before network',
      () async {
        var requestCount = 0;
        final service = RoomService(
          tokenStorage: const _FakeTokenStorage(session),
          client: MockClient((request) async {
            requestCount += 1;
            return http.Response('', 204);
          }),
        );

        await expectLater(
          service.respondToInvitation(
            roomId: 'room-1',
            invitationId: 'invitation-1',
            status: 'ignored',
          ),
          throwsA(isA<RoomServiceException>()),
        );
        expect(requestCount, 0);
      },
    );

    test('fetchGroupSettings parses top-level my_mute from api', () async {
      final service = RoomService(
        tokenStorage: const _FakeTokenStorage(session),
        client: MockClient((request) async {
          return http.Response(
            jsonEncode({
              'settings': {
                'room_id': 'room-1',
                'global_mute_enabled': false,
                'join_approval_required': true,
                'member_can_invite': false,
                'max_members': 128,
              },
              'my_mute': {
                'is_muted': true,
                'reason': 'spam',
                'muted_at': '2026-07-23T05:00:00Z',
                'mute_until': '2026-07-23T06:00:00Z',
              },
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      );

      final settings = await service.fetchGroupSettings('room-1');

      expect(settings.roomId, 'room-1');
      expect(settings.joinApprovalRequired, isTrue);
      expect(settings.memberCanInvite, isFalse);
      expect(settings.maxMembers, 128);
      expect(settings.myMute, isNotNull);
      expect(settings.myMute!.isMuted, isTrue);
      expect(settings.myMute!.reason, 'spam');
      expect(settings.myMute!.muteUntil, isNotNull);
    });

    test('updateRule sends PATCH to match api route contract', () async {
      http.Request? capturedRequest;
      final service = RoomService(
        tokenStorage: const _FakeTokenStorage(session),
        client: MockClient((request) async {
          capturedRequest = request;
          return http.Response(
            jsonEncode({'success': true}),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      );

      await service.updateRule(
        roomId: 'room-1',
        ruleId: 'rule-1',
        title: '群规标题',
        content: '群规内容',
        orderIndex: 2,
        isActive: true,
      );

      expect(capturedRequest, isNotNull);
      expect(capturedRequest!.method, 'PATCH');
      expect(capturedRequest!.url.path, '/rooms/room-1/rules/rule-1');
      expect(capturedRequest!.headers['Authorization'], 'Bearer token-room');
      expect(jsonDecode(capturedRequest!.body), {
        'title': '群规标题',
        'content': '群规内容',
        'order_index': 2,
        'is_active': true,
      });
    });

    test(
      'updateGroupSettings sends PATCH to match api route contract',
      () async {
        http.Request? capturedRequest;
        final service = RoomService(
          tokenStorage: const _FakeTokenStorage(session),
          client: MockClient((request) async {
            capturedRequest = request;
            return http.Response(
              jsonEncode({'success': true}),
              200,
              headers: {'content-type': 'application/json'},
            );
          }),
        );

        await service.updateGroupSettings(
          roomId: 'room-1',
          joinApprovalRequired: true,
          memberCanInvite: false,
          maxMembers: 128,
        );

        expect(capturedRequest, isNotNull);
        expect(capturedRequest!.method, 'PATCH');
        expect(capturedRequest!.url.path, '/rooms/room-1/settings');
        expect(capturedRequest!.headers['Authorization'], 'Bearer token-room');
        expect(jsonDecode(capturedRequest!.body), {
          'join_approval_required': true,
          'member_can_invite': false,
          'max_members': 128,
        });
      },
    );

    test('removeAdmin accepts 204 no-content success from api', () async {
      http.Request? capturedRequest;
      final service = RoomService(
        tokenStorage: const _FakeTokenStorage(session),
        client: MockClient((request) async {
          capturedRequest = request;
          return http.Response('', 204);
        }),
      );

      await service.removeAdmin(roomId: 'room-1', userId: 'u-2');

      expect(capturedRequest, isNotNull);
      expect(capturedRequest!.method, 'DELETE');
      expect(capturedRequest!.url.path, '/rooms/room-1/admins/u-2');
    });

    test('unmuteUser accepts 204 no-content success from api', () async {
      http.Request? capturedRequest;
      final service = RoomService(
        tokenStorage: const _FakeTokenStorage(session),
        client: MockClient((request) async {
          capturedRequest = request;
          return http.Response('', 204);
        }),
      );

      await service.unmuteUser(roomId: 'room-1', userId: 'u-2');

      expect(capturedRequest, isNotNull);
      expect(capturedRequest!.method, 'DELETE');
      expect(capturedRequest!.url.path, '/rooms/room-1/mutes/u-2');
    });

    test('deleteRule accepts 204 no-content success from api', () async {
      http.Request? capturedRequest;
      final service = RoomService(
        tokenStorage: const _FakeTokenStorage(session),
        client: MockClient((request) async {
          capturedRequest = request;
          return http.Response('', 204);
        }),
      );

      await service.deleteRule(roomId: 'room-1', ruleId: 'rule-1');

      expect(capturedRequest, isNotNull);
      expect(capturedRequest!.method, 'DELETE');
      expect(capturedRequest!.url.path, '/rooms/room-1/rules/rule-1');
    });

    test('void mutations reject non-final 2xx responses', () async {
      final service = RoomService(
        tokenStorage: const _FakeTokenStorage(session),
        client: MockClient((request) async {
          return http.Response(
            jsonEncode({'message': 'accepted but not complete'}),
            202,
            headers: {'content-type': 'application/json'},
          );
        }),
      );

      expect(
        () => service.removeAdmin(roomId: 'room-1', userId: 'u-2'),
        throwsA(isA<RoomServiceException>()),
      );
    });
  });
}
