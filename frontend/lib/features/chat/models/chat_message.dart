import 'package:flutter/foundation.dart';

enum ChatMessageType { text, system, image }

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
}
