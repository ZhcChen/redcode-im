import 'dart:convert';

import 'package:app/core/services/friend_service.dart';
import 'package:app/core/storage/token_storage.dart';
import 'package:app/features/auth/models/auth_session.dart';
import 'package:app/features/auth/models/auth_user.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

class _FakeTokenStorage extends TokenStorage {
  const _FakeTokenStorage();

  @override
  Future<AuthSession?> readSession() async => const AuthSession(
    token: 'test-token',
    user: AuthUser(id: 'self-1', username: 'tester'),
  );
}

void main() {
  group('FriendService.updateFriendRemark', () {
    test('sends normalized remark and parses response', () async {
      final service = FriendService(
        tokenStorage: const _FakeTokenStorage(),
        client: MockClient((request) async {
          expect(request.method, 'PATCH');
          expect(request.url.path, '/friends/user-2/remark');
          expect(request.headers['authorization'], 'Bearer test-token');
          expect(jsonDecode(request.body), {'remark': '项目负责人'});
          return http.Response(
            jsonEncode({'remark': '项目负责人'}),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      );

      expect(await service.updateFriendRemark('user-2', '  项目负责人  '), '项目负责人');
    });

    test('sends null to clear remark', () async {
      final service = FriendService(
        tokenStorage: const _FakeTokenStorage(),
        client: MockClient((request) async {
          expect(jsonDecode(request.body), {'remark': null});
          return http.Response(jsonEncode({'remark': null}), 200);
        }),
      );

      expect(await service.updateFriendRemark('user-2', '  '), isNull);
    });

    test('surfaces server error message', () async {
      final service = FriendService(
        tokenStorage: const _FakeTokenStorage(),
        client: MockClient(
          (_) async => http.Response.bytes(
            utf8.encode(jsonEncode({'message': '好友不存在'})),
            404,
            headers: {'content-type': 'application/json; charset=utf-8'},
          ),
        ),
      );

      expect(
        () => service.updateFriendRemark('missing', '备注'),
        throwsA(
          isA<FriendServiceException>().having(
            (error) => error.message,
            'message',
            '好友不存在',
          ),
        ),
      );
    });
  });
}
