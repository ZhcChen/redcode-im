import 'dart:async';

import 'package:flutter/material.dart';

import '../../features/chat/chat_detail_page_v2.dart';
import '../../features/chat/models/chat_model.dart';
import '../../features/contacts/add_friend_page.dart';
import 'friend_store.dart';

final GlobalKey<NavigatorState> pushNavigatorKey = GlobalKey<NavigatorState>();

final List<Map<String, dynamic>> _pendingPushPayloads = [];
bool _pendingFlushScheduled = false;

void _scheduleFlushPendingPushPayloads() {
  if (_pendingFlushScheduled) return;
  _pendingFlushScheduled = true;

  WidgetsBinding.instance.addPostFrameCallback((_) {
    _pendingFlushScheduled = false;
    if (_pendingPushPayloads.isEmpty) return;

    final pending = List<Map<String, dynamic>>.from(_pendingPushPayloads);
    _pendingPushPayloads.clear();
    for (final payload in pending) {
      unawaited(openChatFromPushPayload(payload));
    }
  });
}

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
  final type = payload['type']?.toString().trim().toLowerCase();
  if (type == 'friend_request') {
    final navigator = pushNavigatorKey.currentState;
    if (navigator == null) {
      _pendingPushPayloads.add(Map<String, dynamic>.from(payload));
      _scheduleFlushPendingPushPayloads();
      return;
    }

    final existingFriendIds =
        FriendStore.instance.friends.map((f) => f.user.id).toSet();
    navigator.push(
      MaterialPageRoute(
        builder: (_) => AddFriendPage(
          existingFriendIds: existingFriendIds,
          showRequestsFirst: true,
        ),
      ),
    );
    return;
  }

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
  if (navigator == null) {
    _pendingPushPayloads.add(Map<String, dynamic>.from(payload));
    _scheduleFlushPendingPushPayloads();
    return;
  }

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
