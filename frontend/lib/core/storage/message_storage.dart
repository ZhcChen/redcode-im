import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../features/chat/models/message_model.dart';

class MessageStorage {
  const MessageStorage();

  static const _keyPrefix = 'chat_messages_';
  static const int _maxCacheCount = 200;

  Future<List<Message>> loadMessages(String roomId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('$_keyPrefix$roomId');
    if (raw == null || raw.isEmpty) {
      return const [];
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        return const [];
      }
      final messages = decoded
          .whereType<Map<String, dynamic>>()
          .map(Message.fromCacheJson)
          .toList();
      messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
      return messages;
    } catch (_) {
      await prefs.remove('$_keyPrefix$roomId');
      return const [];
    }
  }

  Future<void> saveMessages(String roomId, List<Message> messages) async {
    if (roomId.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final trimmed = messages.length > _maxCacheCount
        ? messages.sublist(messages.length - _maxCacheCount)
        : messages;

    final serialized = trimmed.map((m) => m.toCacheJson()).toList();
    await prefs.setString('$_keyPrefix$roomId', jsonEncode(serialized));
  }

  Future<void> clear(String roomId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_keyPrefix$roomId');
  }
}
