import 'package:flutter/foundation.dart';

enum ChatMessageType { text, system, image }

@immutable
class MessageReactionSummary {
  const MessageReactionSummary({
    required this.reactionKey,
    required this.count,
    required this.hasSelf,
  });

  final String reactionKey;
  final int count;
  final bool hasSelf;

  factory MessageReactionSummary.fromJson(Map<String, dynamic> json) {
    return MessageReactionSummary(
      reactionKey: json['reaction_key']?.toString() ?? '',
      count: (json['count'] as num?)?.toInt() ?? 0,
      hasSelf: json['has_self'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {'reaction_key': reactionKey, 'count': count, 'has_self': hasSelf};
  }
}

@immutable
class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.timestamp,
    this.content = '',
    this.type = ChatMessageType.text,
    this.isSelf = false,
    this.imageAsset,
    this.imageUrl,
    this.reactions = const [],
  });

  final String id;
  final String senderId;
  final String senderName;
  final String content;
  final DateTime timestamp;
  final ChatMessageType type;
  final bool isSelf;
  final String? imageAsset;
  final String? imageUrl;
  final List<MessageReactionSummary> reactions;

  ChatMessage copyWith({
    String? id,
    String? senderId,
    String? senderName,
    String? content,
    DateTime? timestamp,
    ChatMessageType? type,
    bool? isSelf,
    Object? imageAsset = const _Unset(),
    Object? imageUrl = const _Unset(),
    Object? reactions = const _Unset(),
  }) {
    return ChatMessage(
      id: id ?? this.id,
      senderId: senderId ?? this.senderId,
      senderName: senderName ?? this.senderName,
      content: content ?? this.content,
      timestamp: timestamp ?? this.timestamp,
      type: type ?? this.type,
      isSelf: isSelf ?? this.isSelf,
      imageAsset: identical(imageAsset, const _Unset())
          ? this.imageAsset
          : imageAsset as String?,
      imageUrl: identical(imageUrl, const _Unset())
          ? this.imageUrl
          : imageUrl as String?,
      reactions: identical(reactions, const _Unset())
          ? this.reactions
          : (reactions as List<MessageReactionSummary>),
    );
  }
}

class _Unset {
  const _Unset();
}
