import 'package:flutter_test/flutter_test.dart';
import 'package:app/core/services/message_service.dart';
import 'package:app/features/chat/models/message_model.dart';

Message _buildMessage({
  required String id,
  required DateTime timestamp,
  String senderId = 'u-1',
  String senderUsername = 'alice',
  String senderName = 'Alice',
  Map<String, dynamic>? extra,
}) {
  return Message(
    id: id,
    roomId: 'room-1',
    senderId: senderId,
    senderUsername: senderUsername,
    senderName: senderName,
    content: 'hello',
    type: MessageType.text,
    status: MessageStatus.sent,
    timestamp: timestamp,
    isSelf: false,
    extra: extra,
  );
}

void main() {
  group('message model', () {
    test('ForwardInfo parses source type aliases and display source name', () {
      final fromSingle = ForwardInfo.fromCacheJson({
        'sourceType': 'single',
        'sourceId': 'u-2',
        'sourceName': '',
      });
      final fallback = ForwardInfo.fromCacheJson({
        'sourceType': 'unknown_value',
        'sourceId': '',
        'sourceName': '',
      });

      expect(fromSingle.sourceType, ForwardSourceType.user);
      expect(fromSingle.displaySourceName, 'u-2');
      expect(fallback.sourceType, ForwardSourceType.unknown);
      expect(fallback.displaySourceName, '未知来源');
    });

    test('QuotedMessage previewText handles deleted/text/media cases', () {
      final deleted = QuotedMessage(
        id: 'q-1',
        roomId: 'room-1',
        senderId: 'u-1',
        senderUsername: 'alice',
        senderName: 'Alice',
        type: MessageType.text,
        isDeleted: true,
      );
      final text = QuotedMessage(
        id: 'q-2',
        roomId: 'room-1',
        senderId: 'u-1',
        senderUsername: 'alice',
        senderName: 'Alice',
        content: '  多行   文本 \n 合并 ',
        type: MessageType.text,
        isDeleted: false,
      );
      final image = QuotedMessage(
        id: 'q-3',
        roomId: 'room-1',
        senderId: 'u-1',
        senderUsername: 'alice',
        senderName: 'Alice',
        type: MessageType.image,
        isDeleted: false,
      );

      expect(deleted.previewText, '引用的消息已删除');
      expect(text.previewText, '多行 文本 合并');
      expect(image.previewText, '[图片]');
    });

    test('displaySenderName prefers remark in extra fields', () {
      final message = _buildMessage(
        id: 'm-1',
        timestamp: DateTime.now(),
        senderName: '',
        senderUsername: '',
        extra: {'friend_remark': '备注名优先'},
      );

      expect(message.displaySenderName, '备注名优先');
    });

    test('timestamp and avatar display rules use 5-minute window', () {
      final base = DateTime(2026, 3, 5, 12, 0);
      final current = _buildMessage(id: 'm-1', timestamp: base);
      final nearPrevious = _buildMessage(
        id: 'm-0',
        timestamp: base.subtract(const Duration(minutes: 3)),
      );
      final farPrevious = _buildMessage(
        id: 'm--1',
        timestamp: base.subtract(const Duration(minutes: 6)),
      );
      final nearNext = _buildMessage(
        id: 'm-2',
        timestamp: base.add(const Duration(minutes: 3)),
      );
      final farNext = _buildMessage(
        id: 'm-3',
        timestamp: base.add(const Duration(minutes: 6)),
      );

      expect(current.shouldShowTimestamp(nearPrevious), isFalse);
      expect(current.shouldShowTimestamp(farPrevious), isTrue);
      expect(current.shouldShowAvatar(nearNext), isFalse);
      expect(current.shouldShowAvatar(farNext), isTrue);
    });

    test('fromCacheJson restores nested parts, forward and reactions', () {
      final restored = Message.fromCacheJson({
        'id': 'm-cache-1',
        'roomId': 'room-1',
        'senderId': 'u-1',
        'senderUsername': 'alice',
        'senderName': 'Alice',
        'content': 'cached',
        'type': 'mixed',
        'status': 'sent',
        'timestamp': '2026-03-05T12:00:00Z',
        'isSelf': false,
        'quoted': {
          'id': 'q-1',
          'roomId': 'room-1',
          'senderId': 'u-2',
          'senderUsername': 'bob',
          'senderName': 'Bob',
          'type': 'text',
          'isDeleted': false,
        },
        'forward': {
          'sourceType': 'group',
          'sourceId': 'g-1',
          'sourceName': '开发群',
        },
        'parts': [
          {
            'position': '1',
            'type': 'image',
            'attachment': {'key': 'obj-1', 'size': '128', 'mime': 'image/png'},
          },
        ],
        'reactions': [
          {
            'reaction_key': '👍',
            'count': 2,
            'user_ids': ['u-1', 'u-3'],
            'has_self': true,
          },
        ],
      });

      expect(restored.type, MessageType.mixed);
      expect(restored.quotedMessage, isNotNull);
      expect(restored.forwardInfo?.sourceType, ForwardSourceType.group);
      expect(restored.parts, hasLength(1));
      expect(restored.parts.first.attachment?.size, 128);
      expect(restored.reactions, hasLength(1));
      expect(restored.reactions?.first.reactionKey, '👍');
      expect(restored.reactions?.first.hasSelf, isTrue);
    });
  });
}
