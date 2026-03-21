import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/chat/models/message_reader.dart';

void main() {
  group('MessageReader', () {
    test('fromJson parses fields and converts readAt to local time', () {
      final reader = MessageReader.fromJson({
        'user_id': 'u-1',
        'username': 'alice',
        'nickname': '爱丽丝',
        'avatar_url': 'https://cdn.example.com/a.png',
        'read_at': '2026-03-05T12:00:00Z',
      });

      expect(reader.userId, 'u-1');
      expect(reader.username, 'alice');
      expect(reader.nickname, '爱丽丝');
      expect(reader.avatarUrl, 'https://cdn.example.com/a.png');
      expect(reader.readAt.isUtc, isFalse);
    });

    test('displayName prefers nickname and falls back to username', () {
      final withNickname = MessageReader.fromJson({
        'user_id': 'u-1',
        'username': 'alice',
        'nickname': '  A  ',
        'read_at': '2026-03-05T12:00:00Z',
      });
      final withoutNickname = MessageReader.fromJson({
        'user_id': 'u-2',
        'username': 'bob',
        'nickname': '   ',
        'read_at': '2026-03-05T12:00:00Z',
      });

      expect(withNickname.displayName, 'A');
      expect(withoutNickname.displayName, 'bob');
    });
  });
}
