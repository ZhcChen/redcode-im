import 'package:flutter/foundation.dart';

enum ChatMessageType { text, system }

@immutable
class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.content,
    required this.timestamp,
    this.type = ChatMessageType.text,
    this.isSelf = false,
  });

  final String id;
  final String senderId;
  final String senderName;
  final String content;
  final DateTime timestamp;
  final ChatMessageType type;
  final bool isSelf;
}
