import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/storage/chat_cache.dart';
import 'package:frontend/features/chat/models/chat_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

Chat _buildChat({
  required String id,
  required DateTime time,
  required bool isPinned,
  int unreadCount = 0,
}) {
  return Chat(
    id: id,
    roomId: 'room-$id',
    name: 'chat-$id',
    type: ChatType.group,
    lastMessage: 'msg-$id',
    lastMessageTime: time,
    unreadCount: unreadCount,
    isPinned: isPinned,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ChatCache', () {
    const cache = ChatCache();

    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test(
      'save and load chats keep order: pinned first then latest time',
      () async {
        final now = DateTime.now();
        final chats = [
          _buildChat(
            id: 'a',
            time: now.subtract(const Duration(minutes: 30)),
            isPinned: false,
          ),
          _buildChat(
            id: 'b',
            time: now.subtract(const Duration(hours: 1)),
            isPinned: true,
          ),
          _buildChat(
            id: 'c',
            time: now.subtract(const Duration(minutes: 5)),
            isPinned: false,
            unreadCount: 3,
          ),
        ];

        await cache.saveChats(chats);
        final loaded = await cache.loadChats();

        expect(loaded, isNotNull);
        expect(loaded, hasLength(3));
        expect(loaded![0].id, 'b');
        expect(loaded[1].id, 'c');
        expect(loaded[2].id, 'a');
        expect(loaded[1].unreadCount, 3);
      },
    );

    test('load supports legacy roomId/avatarUrl field fallback', () async {
      final now = DateTime.now();
      SharedPreferences.setMockInitialValues({
        'chat_list_cache': jsonEncode([
          {
            'id': 'legacy-1',
            'name': 'legacy-chat',
            'avatarUrl': 'https://cdn.example.com/legacy.png',
            'lastMessage': 'hello',
            'lastMessageTime': now.toIso8601String(),
            'type': 0,
          },
        ]),
        'chat_list_cache_timestamp': now.millisecondsSinceEpoch,
      });

      final loaded = await cache.loadChats();
      expect(loaded, isNotNull);
      expect(loaded, hasLength(1));
      expect(loaded!.first.roomId, 'legacy-1');
      expect(loaded.first.avatar, 'https://cdn.example.com/legacy.png');
    });

    test('expired cache returns null and clears persisted keys', () async {
      final expired = DateTime.now().subtract(const Duration(hours: 25));
      SharedPreferences.setMockInitialValues({
        'chat_list_cache': jsonEncode([
          {
            'id': 'old-1',
            'roomId': 'room-old-1',
            'name': 'old-chat',
            'lastMessage': 'old',
            'lastMessageTime': DateTime.now().toIso8601String(),
            'type': 1,
          },
        ]),
        'chat_list_cache_timestamp': expired.millisecondsSinceEpoch,
      });

      final loaded = await cache.loadChats();
      final prefs = await SharedPreferences.getInstance();

      expect(loaded, isNull);
      expect(prefs.getString('chat_list_cache'), isNull);
      expect(prefs.getInt('chat_list_cache_timestamp'), isNull);
    });

    test('isCacheValid depends on timestamp availability and age', () async {
      expect(await cache.isCacheValid(), isFalse);

      final now = DateTime.now();
      SharedPreferences.setMockInitialValues({
        'chat_list_cache_timestamp': now.millisecondsSinceEpoch,
      });
      expect(await cache.isCacheValid(), isTrue);
    });
  });
}
