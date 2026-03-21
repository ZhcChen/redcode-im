import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/contacts/models/friend_models.dart';

Map<String, dynamic> _userJson(String id, String username) => {
      'id': id,
      'username': username,
      'nickname': username,
    };

void main() {
  group('friend models', () {
    test('status conversion is case-insensitive and has fallback', () {
      expect(
        friendRequestStatusFromString('ACCEPTED'),
        FriendRequestStatus.accepted,
      );
      expect(
        friendRequestStatusFromString('declined'),
        FriendRequestStatus.declined,
      );
      expect(
        friendRequestStatusFromString('unknown'),
        FriendRequestStatus.pending,
      );
      expect(
        friendRequestStatusToString(FriendRequestStatus.pending),
        'pending',
      );
    });

    test('parses ensure chat result with defaults', () {
      final result = EnsureChatResult.fromJson({
        'room_id': 'room-1',
        'friend_id': 'u-2',
        'friend_name': 'bob',
      });

      expect(result.roomId, 'room-1');
      expect(result.roomType, 'private');
      expect(result.friendName, 'bob');
    });

    test('resolves incoming counterparty correctly', () {
      final request = FriendRequestInfo.fromJson({
        'id': 'req-1',
        'requester': _userJson('u-1', 'alice'),
        'addressee': _userJson('u-2', 'bob'),
        'status': 'pending',
        'is_incoming': true,
        'created_at': '2026-03-01T00:00:00Z',
      });

      expect(request.counterparty.id, 'u-1');
      expect(request.counterparty.username, 'alice');
    });
  });
}
