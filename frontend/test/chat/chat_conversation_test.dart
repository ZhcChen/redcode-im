import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/chat/models/chat_conversation.dart';

void main() {
  group('ChatConversation', () {
    test('copyWith updates selected fields only', () {
      final base = ChatConversation(
        id: 'c1',
        name: '原会话',
        lastMessage: 'hello',
        lastMessageTime: DateTime(2026, 3, 5, 10, 0),
        unreadCount: 1,
        isPinned: false,
      );

      final updated = base.copyWith(
        name: '新会话',
        unreadCount: 8,
        isPinned: true,
      );

      expect(updated.id, 'c1');
      expect(updated.name, '新会话');
      expect(updated.unreadCount, 8);
      expect(updated.isPinned, isTrue);
      expect(updated.lastMessage, 'hello');
    });

    test('timeLabel returns HH:mm for same-day message', () {
      final now = DateTime.now();
      final conversation = ChatConversation(
        id: 'c2',
        name: '当日会话',
        lastMessage: 'same day',
        lastMessageTime: now.subtract(const Duration(hours: 1)),
      );

      expect(conversation.timeLabel, matches(RegExp(r'^\d{2}:\d{2}$')));
    });

    test('timeLabel returns MM-dd for old message', () {
      final conversation = ChatConversation(
        id: 'c3',
        name: '历史会话',
        lastMessage: 'old',
        lastMessageTime: DateTime.now().subtract(const Duration(days: 2)),
      );

      expect(conversation.timeLabel, matches(RegExp(r'^\d{2}-\d{2}$')));
    });
  });
}
