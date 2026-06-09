import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/services/room_service.dart';
import 'package:frontend/core/storage/token_storage.dart';
import 'package:frontend/features/auth/models/auth_session.dart';
import 'package:frontend/features/auth/models/auth_user.dart';
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
      expect(
        jsonDecode(capturedRequest!.body),
        {'name': '新群名称', 'description': '新的群描述'},
      );
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
      expect(
        jsonDecode(capturedRequest!.body),
        {
          'user_ids': ['u-2', 'u-3', 'u-4'],
        },
      );
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
  });
}
