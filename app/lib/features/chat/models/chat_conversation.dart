import 'package:flutter/foundation.dart';

@immutable
class ChatConversation {
  const ChatConversation({
    required this.id,
    required this.name,
    required this.lastMessage,
    required this.lastMessageTime,
    this.unreadCount = 0,
    this.isPinned = false,
    this.avatar,
  });

  final String id;
  final String name;
  final String lastMessage;
  final DateTime lastMessageTime;
  final int unreadCount;
  final bool isPinned;
  final String? avatar;

  ChatConversation copyWith({
    String? id,
    String? name,
    String? lastMessage,
    DateTime? lastMessageTime,
    int? unreadCount,
    bool? isPinned,
    String? avatar,
  }) {
    return ChatConversation(
      id: id ?? this.id,
      name: name ?? this.name,
      lastMessage: lastMessage ?? this.lastMessage,
      lastMessageTime: lastMessageTime ?? this.lastMessageTime,
      unreadCount: unreadCount ?? this.unreadCount,
      isPinned: isPinned ?? this.isPinned,
      avatar: avatar ?? this.avatar,
    );
  }

  String get timeLabel {
    final now = DateTime.now();
    final difference = now.difference(lastMessageTime);
    if (difference.inDays >= 1) {
      return '${lastMessageTime.month.toString().padLeft(2, '0')}-${lastMessageTime.day.toString().padLeft(2, '0')}';
    }
    final hour = lastMessageTime.hour.toString().padLeft(2, '0');
    final minute = lastMessageTime.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}
