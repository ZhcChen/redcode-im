import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/auth/models/auth_session.dart';
import 'package:frontend/features/auth/models/auth_user.dart';

void main() {
  group('auth models', () {
    test('AuthUser fromJson/toJson keeps optional fields', () {
      final user = AuthUser.fromJson({
        'id': 'u-1',
        'username': 'alice',
        'email': 'alice@example.com',
        'nickname': 'Alice',
        'avatar_url': 'https://cdn.example.com/a.png',
        'avatar_object_key': 'avatars/a.png',
        'local_avatar_path': '/tmp/a.png',
        'status': 'active',
      });

      final json = user.toJson();

      expect(json['id'], 'u-1');
      expect(json['username'], 'alice');
      expect(json['email'], 'alice@example.com');
      expect(json['nickname'], 'Alice');
      expect(json['avatar_url'], 'https://cdn.example.com/a.png');
      expect(json['avatar_object_key'], 'avatars/a.png');
      expect(json['local_avatar_path'], '/tmp/a.png');
      expect(json['status'], 'active');
    });

    test(
      'AuthUser displayName prefers nickname and falls back to username',
      () {
        const withNickname = AuthUser(
          id: 'u-1',
          username: 'alice',
          nickname: '爱丽丝',
        );
        const withoutNickname = AuthUser(id: 'u-2', username: 'bob');

        expect(withNickname.displayName, '爱丽丝');
        expect(withoutNickname.displayName, 'bob');
      },
    );

    test('AuthUser copyWith supports clearing local avatar path', () {
      const user = AuthUser(
        id: 'u-1',
        username: 'alice',
        localAvatarPath: '/tmp/local.png',
        avatarObjectKey: 'avatars/old.png',
      );

      final updated = user.copyWith(
        avatarObjectKey: 'avatars/new.png',
        clearLocalAvatarPath: true,
      );

      expect(updated.avatarObjectKey, 'avatars/new.png');
      expect(updated.localAvatarPath, isNull);
      expect(updated.username, 'alice');
    });

    test('AuthSession stores token, user and optional refresh token', () {
      const user = AuthUser(id: 'u-3', username: 'charlie');
      const session = AuthSession(
        token: 'token-3',
        user: user,
        refreshToken: 'refresh-3',
      );

      expect(session.token, 'token-3');
      expect(session.user.username, 'charlie');
      expect(session.refreshToken, 'refresh-3');
    });
  });
}
