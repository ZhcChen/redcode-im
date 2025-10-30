import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/core/services/message_service.dart';
import 'package:frontend/features/chat/models/message_model.dart';

void main() {
  group('Message forward & pinned metadata', () {
    test('cache serialization preserves forward info and pinned state', () {
      final forwardInfo = ForwardInfo(
        sourceType: ForwardSourceType.group,
        sourceId: 'room-1',
        sourceName: '产品讨论',
        sourceAvatar: 'https://example.com/group.png',
        originMessageId: 'msg-42',
        originRoomId: 'room-1',
        originSenderId: 'user-1',
        originSenderName: '小王',
      );

      final message = Message(
        id: 'msg-100',
        roomId: 'room-9',
        senderId: 'user-9',
        senderUsername: 'tester',
        senderName: '测试',
        content: '今天的讨论记录',
        type: MessageType.text,
        status: MessageStatus.sent,
        timestamp: DateTime(2025, 1, 15, 12, 30),
        isSelf: true,
        extra: {
          'forward': forwardInfo.toCacheJson(),
          'pinned_at': '2025-01-15T12:35:00.000Z',
        },
        forwardInfo: forwardInfo,
        pinnedAt: DateTime(2025, 1, 15, 12, 35),
      );

      final cache = message.toCacheJson();
      final restored = Message.fromCacheJson(cache);

      expect(restored.id, message.id);
      expect(restored.forwardInfo?.displaySourceName, forwardInfo.displaySourceName);
      expect(restored.forwardInfo?.originSenderName, forwardInfo.originSenderName);
      expect(restored.isPinned, isTrue);
      expect(
        restored.pinnedAt?.toUtc().millisecondsSinceEpoch,
        message.pinnedAt?.toUtc().millisecondsSinceEpoch,
      );
      expect(restored.isDeleted, isFalse);
    });

    test('copyWith can clear optional metadata', () {
      final message = Message(
        id: 'id-1',
        roomId: 'room',
        senderId: 'user',
        senderUsername: 'user',
        senderName: '用户',
        content: '内容',
        type: MessageType.text,
        status: MessageStatus.sent,
        timestamp: DateTime.now(),
        isSelf: true,
        extra: {'foo': 'bar'},
        forwardInfo: ForwardInfo(
          sourceType: ForwardSourceType.user,
          sourceId: 'user-2',
          sourceName: '老王',
        ),
        pinnedAt: DateTime.now(),
        isDeleted: true,
      );

      final updated = message.copyWith(
        extra: null,
        forwardInfo: null,
        pinnedAt: null,
        isDeleted: false,
      );

      expect(updated.extra, isNull);
      expect(updated.forwardInfo, isNull);
      expect(updated.pinnedAt, isNull);
      expect(updated.isDeleted, isFalse);
    });
  });
}
