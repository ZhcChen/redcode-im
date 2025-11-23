import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../features/chat/models/chat_model.dart';

/// 会话列表缓存
class ChatCache {
  const ChatCache();

  static const String _cacheKey = 'chat_list_cache';
  static const String _cacheTimestampKey = 'chat_list_cache_timestamp';
  static const int _cacheExpirationHours = 24; // 缓存24小时

  /// 保存会话列表到缓存
  Future<void> saveChats(List<Chat> chats) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // 转换为可序列化的格式
      final chatMaps = chats
          .map(
            (chat) => {
              'id': chat.id,
              'roomId': chat.roomId,
              'name': chat.name,
              'avatar': chat.avatar,
              'avatarObjectKey': chat.avatarObjectKey,
              'localAvatarPath': chat.localAvatarPath,
              'lastMessage': chat.lastMessage,
              'lastMessageTime': chat.lastMessageTime.toIso8601String(),
              'unreadCount': chat.unreadCount,
              'type': chat.type.index,
              'isPinned': chat.isPinned,
              'isMuted': chat.isMuted,
              'extra': chat.extra,
            },
          )
          .toList();

      final jsonString = jsonEncode(chatMaps);
      await prefs.setString(_cacheKey, jsonString);
      await prefs.setInt(
        _cacheTimestampKey,
        DateTime.now().millisecondsSinceEpoch,
      );
    } catch (e) {
      debugPrint('Failed to save chat cache: $e');
    }
  }

  /// 从缓存加载会话列表
  Future<List<Chat>?> loadChats() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // 检查缓存是否过期
      final timestamp = prefs.getInt(_cacheTimestampKey);
      if (timestamp != null) {
        final cacheTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
        final now = DateTime.now();
        if (now.difference(cacheTime).inHours > _cacheExpirationHours) {
          // 缓存过期
          await clearCache();
          return null;
        }
      }

      final jsonString = prefs.getString(_cacheKey);
      if (jsonString == null) {
        return null;
      }

      final List<dynamic> chatMaps = jsonDecode(jsonString);
      final chats = chatMaps.map((map) {
        return Chat(
          id: map['id'] ?? '',
          roomId: map['roomId'] ?? map['id'] ?? '',  // 兼容旧缓存
          name: map['name'] ?? '',
          avatar: map['avatar'] ?? map['avatarUrl'],  // 兼容旧字段名
          avatarObjectKey: map['avatarObjectKey'],
          localAvatarPath: map['localAvatarPath'],
          lastMessage: map['lastMessage'] ?? '',
          lastMessageTime: DateTime.parse(map['lastMessageTime']),
          unreadCount: map['unreadCount'] ?? 0,
          type: ChatType.values[map['type'] ?? 0],
          isPinned: map['isPinned'] ?? false,
          isMuted: map['isMuted'] ?? false,
          extra: map['extra'],
        );
      }).toList();

      // 按照置顶和时间排序
      chats.sort((a, b) {
        if (a.isPinned != b.isPinned) {
          return a.isPinned ? -1 : 1;
        }
        return b.lastMessageTime.compareTo(a.lastMessageTime);
      });

      return chats;
    } catch (e) {
      debugPrint('Failed to load chat cache: $e');
      return null;
    }
  }

  /// 清除缓存
  Future<void> clearCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_cacheKey);
      await prefs.remove(_cacheTimestampKey);
    } catch (e) {
      debugPrint('Failed to clear chat cache: $e');
    }
  }

  /// 获取缓存时间
  Future<DateTime?> getCacheTime() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final timestamp = prefs.getInt(_cacheTimestampKey);
      if (timestamp != null) {
        return DateTime.fromMillisecondsSinceEpoch(timestamp);
      }
    } catch (e) {
      debugPrint('Failed to get cache time: $e');
    }
    return null;
  }

  /// 检查缓存是否有效
  Future<bool> isCacheValid() async {
    final cacheTime = await getCacheTime();
    if (cacheTime == null) {
      return false;
    }

    final now = DateTime.now();
    return now.difference(cacheTime).inHours <= _cacheExpirationHours;
  }
}
