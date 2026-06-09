import 'package:flutter_test/flutter_test.dart';
import 'package:app/features/chat/models/chat_model.dart';

void main() {
  Chat buildChat({
    required ChatType type,
    required DateTime time,
    int unread = 0,
    bool pinned = false,
  }) {
    return Chat(
      id: 'c1',
      roomId: 'room-1',
      name: '测试会话',
      type: type,
      lastMessage: 'hello',
      lastMessageTime: time,
      unreadCount: unread,
      isPinned: pinned,
    );
  }

  test('favorite chat displayTime is fixed label', () {
    final chat = buildChat(
      type: ChatType.favorite,
      time: DateTime.now().subtract(const Duration(days: 100)),
    );

    expect(chat.displayTime, '随时可用');
  });

  test('recent chat within 60 seconds returns 刚刚', () {
    final chat = buildChat(
      type: ChatType.single,
      time: DateTime.now().subtract(const Duration(seconds: 30)),
    );

    expect(chat.displayTime, '刚刚');
  });

  test('chat from yesterday returns 昨天', () {
    final now = DateTime.now();
    final yesterday = DateTime(
      now.year,
      now.month,
      now.day,
      12,
      0,
    ).subtract(const Duration(days: 1));
    final chat = buildChat(type: ChatType.group, time: yesterday);

    expect(chat.displayTime, '昨天');
  });

  test('chat older than one week in same year returns 月日', () {
    final now = DateTime.now();
    final older = now.isAfter(DateTime(now.year, 1, 3))
        ? DateTime(now.year, 1, 2, 9, 30)
        : now.subtract(const Duration(days: 8));
    final chat = buildChat(type: ChatType.single, time: older);

    expect(chat.displayTime, contains('月'));
    expect(chat.displayTime, contains('日'));
  });

  test('chat from previous year returns yyyy/MM/dd', () {
    final now = DateTime.now();
    final old = DateTime(now.year - 1, 2, 3, 8, 20);
    final chat = buildChat(type: ChatType.single, time: old);

    expect(chat.displayTime, '${old.year}/02/03');
  });

  test('copyWith updates selected fields only', () {
    final original = buildChat(
      type: ChatType.group,
      time: DateTime.now(),
      unread: 1,
    );

    final updated = original.copyWith(unreadCount: 10, isPinned: true);

    expect(updated.unreadCount, 10);
    expect(updated.isPinned, isTrue);
    expect(updated.roomId, original.roomId);
    expect(updated.name, original.name);
  });
}
