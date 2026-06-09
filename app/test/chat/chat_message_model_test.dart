import 'package:flutter_test/flutter_test.dart';
import 'package:app/features/chat/models/chat_message.dart';

void main() {
  group('chat_message model', () {
    test('MessageReactionSummary fromJson/toJson roundtrip', () {
      final reaction = MessageReactionSummary.fromJson({
        'reaction_key': '🔥',
        'count': 5,
        'has_self': true,
      });

      final json = reaction.toJson();

      expect(reaction.reactionKey, '🔥');
      expect(reaction.count, 5);
      expect(reaction.hasSelf, isTrue);
      expect(json['reaction_key'], '🔥');
      expect(json['count'], 5);
      expect(json['has_self'], isTrue);
    });

    test('MessageReactionSummary uses defaults for malformed payload', () {
      final reaction = MessageReactionSummary.fromJson({'unexpected': 1});
      expect(reaction.reactionKey, '');
      expect(reaction.count, 0);
      expect(reaction.hasSelf, isFalse);
    });

    test('ChatMessage copyWith keeps fields when unset and supports clear', () {
      final message = ChatMessage(
        id: 'm1',
        senderId: 'u1',
        senderName: 'Alice',
        content: 'hello',
        timestamp: DateTime(2026, 3, 5, 10, 0),
        type: ChatMessageType.image,
        isSelf: false,
        imageAsset: 'assets/a.png',
        imageUrl: 'https://cdn.example.com/a.png',
        reactions: const [
          MessageReactionSummary(reactionKey: '👍', count: 1, hasSelf: true),
        ],
      );

      final keepImage = message.copyWith(content: 'updated');
      expect(keepImage.imageAsset, 'assets/a.png');
      expect(keepImage.imageUrl, 'https://cdn.example.com/a.png');
      expect(keepImage.reactions, hasLength(1));

      final clearedImage = message.copyWith(
        imageAsset: null,
        imageUrl: null,
        reactions: const <MessageReactionSummary>[],
      );
      expect(clearedImage.imageAsset, isNull);
      expect(clearedImage.imageUrl, isNull);
      expect(clearedImage.reactions, isEmpty);
    });
  });
}
