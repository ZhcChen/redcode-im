import 'package:flutter/material.dart';

import '../../features/chat/chat_detail_page_v2.dart';
import '../../features/chat/models/chat_model.dart';

final GlobalKey<NavigatorState> pushNavigatorKey = GlobalKey<NavigatorState>();

ChatType _chatTypeFromRoomType(String? roomType) {
  final value = (roomType ?? '').trim().toLowerCase();
  switch (value) {
    case 'group':
      return ChatType.group;
    case 'favorite':
      return ChatType.favorite;
    case 'private':
    default:
      return ChatType.single;
  }
}

Future<void> openChatFromPushPayload(Map<String, dynamic> payload) async {
  final roomId = payload['room_id']?.toString().trim() ?? '';
  if (roomId.isEmpty) return;

  final roomType = payload['room_type']?.toString();
  final chatType = _chatTypeFromRoomType(roomType);
  final chatName =
      payload['chat_name']?.toString().trim().isNotEmpty == true
          ? payload['chat_name']!.toString().trim()
          : '聊天';
  final messageId = payload['message_id']?.toString().trim();

  final navigator = pushNavigatorKey.currentState;
  if (navigator == null) return;

  navigator.push(
    MaterialPageRoute(
      builder: (_) => ChatDetailPageV2(
        roomId: roomId,
        chatName: chatName,
        chatType: chatType,
        initialMessageId: messageId?.isNotEmpty == true ? messageId : null,
      ),
    ),
  );
}

