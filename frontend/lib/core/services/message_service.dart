import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart' as uuid_pkg;

import '../constants/app_assets.dart';
import '../constants/app_config.dart';
import '../storage/token_storage.dart';
import '../../features/chat/models/message_model.dart';
import '../../features/chat/models/message_reader.dart';
import '../../features/chat/models/chat_model.dart';
import 'websocket_service.dart';

/// 消息状态
enum MessageStatus {
  sending, // 发送中
  sent, // 已发送
  delivered, // 已送达
  read, // 已读
  failed, // 发送失败
}

/// 消息服务 - 管理消息的发送、接收和存储
class MessageService with ChangeNotifier {
  MessageService({TokenStorage? tokenStorage})
    : _tokenStorage = tokenStorage ?? const TokenStorage();

  final TokenStorage _tokenStorage;

  // 消息存储 (roomId -> messages)
  final Map<String, List<Message>> _messagesByRoom = {};

  // 消息发送队列
  final Map<String, Message> _pendingMessages = {};

  // 聊天列表
  final List<Chat> _chats = [];
  final Map<String, List<MessageReader>> _messageReadersCache = {};
  final Map<String, int> _roomMemberCountCache = {};

  // 单例模式
  static MessageService? _instance;
  static MessageService get instance {
    _instance ??= MessageService();
    return _instance!;
  }

  /// 获取房间的消息列表
  List<Message> getMessages(String roomId) {
    return List.from(_messagesByRoom[roomId] ?? []);
  }

  /// 获取聊天列表
  List<Chat> get chats => List.from(_chats);

  /// 获取缓存的房间成员数量
  int? cachedRoomMemberCount(String roomId) => _roomMemberCountCache[roomId];

  /// 获取缓存的已读成员列表
  List<MessageReader>? cachedMessageReaders(String roomId, String messageId) {
    final key = _buildReaderCacheKey(roomId, messageId);
    final cached = _messageReadersCache[key];
    return cached == null ? null : List<MessageReader>.from(cached);
  }

  /// 拉取房间成员数量（带缓存）
  Future<int> fetchRoomMemberCount(
    String roomId, {
    bool forceRefresh = false,
  }) async {
    if (roomId.isEmpty) return 0;
    if (!forceRefresh && _roomMemberCountCache.containsKey(roomId)) {
      return _roomMemberCountCache[roomId]!;
    }

    final session = await _tokenStorage.readSession();
    if (session == null) {
      throw Exception('User not authenticated');
    }

    final uri = Uri.parse('${AppConfig.apiBaseUrl}/rooms/$roomId/members');
    final response = await http.get(
      uri,
      headers: {'Authorization': 'Bearer ${session.token}'},
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to load room members: ${response.body}');
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! List) {
      throw Exception('Invalid room member response');
    }

    final count = decoded.length;
    _roomMemberCountCache[roomId] = count;
    notifyListeners();
    return count;
  }

  /// 拉取消息已读成员列表（带缓存）
  Future<List<MessageReader>> fetchMessageReaders(
    String roomId,
    String messageId, {
    bool forceRefresh = false,
  }) async {
    final key = _buildReaderCacheKey(roomId, messageId);
    if (!forceRefresh && _messageReadersCache.containsKey(key)) {
      return List<MessageReader>.from(_messageReadersCache[key]!);
    }

    final session = await _tokenStorage.readSession();
    if (session == null) {
      throw Exception('User not authenticated');
    }

    final uri = Uri.parse(
      '${AppConfig.apiBaseUrl}/rooms/$roomId/messages/$messageId/reads',
    );

    final response = await http.get(
      uri,
      headers: {'Authorization': 'Bearer ${session.token}'},
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to load message readers: ${response.body}');
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! List) {
      throw Exception('Invalid message readers response');
    }

    final readers = decoded
        .whereType<Map<String, dynamic>>()
        .map(MessageReader.fromJson)
        .toList();

    _messageReadersCache[key] = readers;
    return List<MessageReader>.from(readers);
  }

  /// 从服务器拉取会话列表
  Future<List<Chat>> fetchChats() async {
    final session = await _tokenStorage.readSession();
    if (session == null) {
      throw Exception('User not authenticated');
    }

    final uri = Uri.parse('${AppConfig.apiBaseUrl}/chats');
    final response = await http.get(
      uri,
      headers: {'Authorization': 'Bearer ${session.token}'},
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to load chats: ${response.body}');
    }

    final raw = jsonDecode(response.body);
    final chatMaps =
        _tryExtractChatList(raw) ??
        (raw is List ? raw.whereType<Map<String, dynamic>>().toList() : null);

    if (chatMaps == null) {
      throw Exception('Invalid chat response structure');
    }

    final chats = chatMaps.map(_chatFromJson).toList();

    // 修正单聊标题：优先备注/昵称；若后端返回的 name 含自己昵称/账号，则剔除仅保留对方显示名
    for (var i = 0; i < chats.length; i++) {
      final chat = chats[i];
      if (chat.type == ChatType.single) {
        final preferred = chat.extra != null
            ? (chat.extra!['friend_remark'] as String? ??
                  chat.extra!['friend_nickname'] as String? ??
                  chat.extra!['friend_name'] as String? ??
                  chat.extra!['friend_username'] as String?)
            : null;
        if (preferred != null && preferred.trim().isNotEmpty) {
          chats[i] = chat.copyWith(name: preferred.trim());
        } else {
          final cleaned = _stripSelfFromRoomName(chat.name, {
            session.user.nickname ?? '',
            session.user.username,
          });
          if (cleaned.isNotEmpty && cleaned != chat.name) {
            chats[i] = chat.copyWith(name: cleaned);
          }
        }
      }
    }

    _chats
      ..clear()
      ..addAll(chats);
    _sortChats();
    _syncWebSocketSubscriptions();
    notifyListeners();

    return chats;
  }

  /// 发送文本消息
  Future<void> sendTextMessage(String roomId, String content) async {
    final trimmed = content.trim();
    if (roomId.isEmpty || trimmed.isEmpty) return;

    // 创建临时消息
    final tempId = const uuid_pkg.Uuid().v4();
    final session = await _tokenStorage.readSession();
    if (session == null) {
      throw Exception('User not authenticated');
    }

    final tempMessage = Message(
      id: tempId,
      roomId: roomId,
      senderId: session.user.id,
      senderUsername: session.user.username,
      senderName: session.user.nickname?.isNotEmpty == true
          ? session.user.nickname!
          : session.user.username,
      senderAvatar: session.user.avatarUrl,
      content: trimmed,
      type: MessageType.text,
      status: MessageStatus.sending,
      timestamp: DateTime.now(),
      isSelf: true,
    );

    // 添加到消息列表
    _addMessage(tempMessage);

    // 添加到待发送队列
    _pendingMessages[tempId] = tempMessage;

    try {
      // 调用API发送消息
      final response = await _sendMessageAPI(roomId, trimmed, 'text');
      final updated = _messageFromResponse(
        response,
        session.user.id,
        status: MessageStatus.sent,
      );

      if (_pendingMessages.containsKey(tempId)) {
        _replaceMessage(tempId, updated);
        _pendingMessages.remove(tempId);
      } else {
        // WebSocket 已提前对齐消息，直接按服务端 ID 更新
        _replaceMessage(updated.id, updated);
      }

      // 更新聊天列表的最后消息
      _updateChatLastMessage(roomId, updated);
    } catch (e) {
      debugPrint('Failed to send message: $e');
      _updateMessageStatus(tempId, MessageStatus.failed);

      // 可以实现重试逻辑
      _scheduleRetry(tempId);
    }
  }

  /// 发送图片消息
  Future<void> sendImageMessage(String roomId, String imagePath) async {
    // TODO: 实现图片上传和发送
    debugPrint('Sending image message: $imagePath');
  }

  /// 重发失败的消息
  Future<void> resendMessage(String messageId) async {
    final message = _pendingMessages[messageId];
    if (message == null) {
      debugPrint('Message not found in pending queue: $messageId');
      return;
    }

    _updateMessageStatus(messageId, MessageStatus.sending);

    try {
      final session = await _tokenStorage.readSession();
      if (session == null) {
        throw Exception('User not authenticated');
      }

      final response = await _sendMessageAPI(
        message.roomId,
        message.content,
        message.type == MessageType.text ? 'text' : 'image',
      );

      final updated = _messageFromResponse(
        response,
        session.user.id,
        status: MessageStatus.sent,
      );
      _replaceMessage(messageId, updated);
      _pendingMessages.remove(messageId);
    } catch (e) {
      debugPrint('Failed to resend message: $e');
      _updateMessageStatus(messageId, MessageStatus.failed);
    }
  }

  /// 调用API发送消息
  Future<MessageResponse> _sendMessageAPI(
    String roomId,
    String content,
    String messageType,
  ) async {
    final session = await _tokenStorage.readSession();
    if (session == null) {
      throw Exception('User not authenticated');
    }

    final uri = Uri.parse('${AppConfig.apiBaseUrl}/rooms/$roomId/messages');
    final response = await http.post(
      uri,
      headers: {
        'Authorization': 'Bearer ${session.token}',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'content': content, 'message_type': messageType}),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return MessageResponse.fromJson(data['message']);
    } else {
      throw Exception('Failed to send message: ${response.body}');
    }
  }

  /// 加载历史消息
  Future<List<Message>> loadMessages(
    String roomId, {
    int limit = 50,
    String? beforeId,
    String? sinceId,
  }) async {
    try {
      final session = await _tokenStorage.readSession();
      if (session == null) {
        throw Exception('User not authenticated');
      }

      if (beforeId != null && sinceId != null) {
        throw ArgumentError('beforeId 和 sinceId 不能同时指定');
      }

      final query = <String, String>{
        'limit': limit.toString(),
        if (beforeId != null) 'before_id': beforeId,
        if (sinceId != null) 'since_id': sinceId,
      };

      final uri = Uri.parse(
        '${AppConfig.apiBaseUrl}/rooms/$roomId/messages',
      ).replace(queryParameters: query);

      final response = await http.get(
        uri,
        headers: {'Authorization': 'Bearer ${session.token}'},
      );

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is! List) {
          throw Exception('Invalid message list response');
        }

        final newMessages = decoded
            .whereType<Map<String, dynamic>>()
            .map(MessageResponse.fromJson)
            .map(
              (msg) => _messageFromResponse(
                msg,
                session.user.id,
                status: MessageStatus.sent,
              ),
            )
            .toList();

        newMessages.sort((a, b) => a.timestamp.compareTo(b.timestamp));

        if (beforeId != null || sinceId != null) {
          final existing = _messagesByRoom.putIfAbsent(
            roomId,
            () => <Message>[],
          );

          final unique = <Message>[];
          for (final message in newMessages) {
            final index = existing.indexWhere((m) => m.id == message.id);
            if (index >= 0) {
              existing[index] = _mergeMessage(existing[index], message);
            } else {
              unique.add(message);
            }
          }

          if (beforeId != null && unique.isNotEmpty) {
            existing.insertAll(0, unique);
          } else if (sinceId != null && unique.isNotEmpty) {
            existing.addAll(unique);
          }

          existing.sort((a, b) => a.timestamp.compareTo(b.timestamp));
        } else {
          _messagesByRoom[roomId] = newMessages;
        }

        notifyListeners();
        return newMessages;
      }
    } catch (e) {
      debugPrint('Failed to load messages: $e');
    }

    return const [];
  }

  /// 处理WebSocket接收到的消息
  Future<void> handleWebSocketMessage(WebSocketMessage wsMessage) async {
    final session = await _tokenStorage.readSession();
    if (session == null) return;

    final message = _messageFromWebSocket(wsMessage, session.user.id);
    String? matchedPendingId;
    _pendingMessages.forEach((pendingId, pendingMessage) {
      if (matchedPendingId != null) {
        return;
      }
      final sameRoom = pendingMessage.roomId == message.roomId;
      final sameSender = pendingMessage.senderId == message.senderId;
      final sameContent = pendingMessage.content == message.content;
      if (sameRoom && sameSender && sameContent) {
        matchedPendingId = pendingId;
      }
    });

    if (matchedPendingId != null) {
      _pendingMessages.remove(matchedPendingId);
      _replaceMessage(matchedPendingId!, message);
      return;
    }

    final messages = _messagesByRoom.putIfAbsent(
      message.roomId,
      () => <Message>[],
    );
    final index = messages.indexWhere((m) => m.id == message.id);

    if (index >= 0) {
      messages[index] = _mergeMessage(messages[index], message);
    } else {
      messages.add(message);
    }

    messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    _updateChatLastMessage(message.roomId, message);
    notifyListeners();
  }

  /// 处理已读回执事件
  Future<void> handleReadReceipt({
    required String roomId,
    required String messageId,
    required String readerId,
  }) async {
    final session = await _tokenStorage.readSession();
    if (session == null) return;
    if (readerId == session.user.id) {
      // 自己触发的已读无需再次处理
      return;
    }

    final messages = _messagesByRoom[roomId];
    if (messages == null || messages.isEmpty) return;

    final targetIndex = messages.lastIndexWhere((m) => m.id == messageId);
    if (targetIndex == -1) return;

    var updated = false;

    for (var i = 0; i <= targetIndex && i < messages.length; i++) {
      final msg = messages[i];
      if (!msg.isSelf) continue;
      if (msg.status == MessageStatus.read) continue;

      messages[i] = msg.copyWith(status: MessageStatus.read);
      updated = true;
    }

    if (updated) {
      _invalidateMessageReaders(roomId, messageId);
      notifyListeners();
    }
  }

  /// 添加消息到列表
  void _addMessage(Message message) {
    final messages = _messagesByRoom.putIfAbsent(
      message.roomId,
      () => <Message>[],
    );
    final index = messages.indexWhere((m) => m.id == message.id);
    if (index >= 0) {
      messages[index] = _mergeMessage(messages[index], message);
    } else {
      messages.add(message);
    }
    messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    notifyListeners();
  }

  /// 用新消息替换旧消息（用于发送成功后更新临时消息）
  void _replaceMessage(String originalId, Message newMessage) {
    final messages = _messagesByRoom[newMessage.roomId];
    if (messages == null) return;

    final index = messages.indexWhere((m) => m.id == originalId);
    if (index >= 0) {
      messages[index] = newMessage;
    } else {
      messages.add(newMessage);
    }

    messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    notifyListeners();
  }

  /// 合并消息，保留最新状态和显示信息
  Message _mergeMessage(Message oldMessage, Message newMessage) {
    final mergedStatus = oldMessage.status == MessageStatus.failed
        ? newMessage.status
        : (_statusPriority(newMessage.status) >=
                  _statusPriority(oldMessage.status)
              ? newMessage.status
              : oldMessage.status);

    final latestTimestamp = newMessage.timestamp.isAfter(oldMessage.timestamp)
        ? newMessage.timestamp
        : oldMessage.timestamp;

    return oldMessage.copyWith(
      id: newMessage.id,
      senderId: newMessage.senderId,
      senderUsername: newMessage.senderUsername,
      senderName: newMessage.senderName,
      senderAvatar: newMessage.senderAvatar ?? oldMessage.senderAvatar,
      content: newMessage.content,
      type: newMessage.type,
      status: mergedStatus,
      timestamp: latestTimestamp,
      isSelf: newMessage.isSelf,
      extra: newMessage.extra ?? oldMessage.extra,
    );
  }

  int _statusPriority(MessageStatus status) {
    switch (status) {
      case MessageStatus.read:
        return 4;
      case MessageStatus.delivered:
        return 3;
      case MessageStatus.sent:
        return 2;
      case MessageStatus.sending:
        return 1;
      case MessageStatus.failed:
        return 0;
    }
  }

  /// 更新消息状态
  void _updateMessageStatus(
    String tempId,
    MessageStatus status, [
    String? newId,
  ]) {
    for (final messages in _messagesByRoom.values) {
      final index = messages.indexWhere((m) => m.id == tempId);
      if (index >= 0) {
        var updated = messages[index].copyWith(status: status);
        if (newId != null) {
          updated = updated.copyWith(id: newId);
        }
        messages[index] = updated;
        notifyListeners();
        break;
      }
    }
  }

  /// 更新聊天的最后消息
  void _updateChatLastMessage(String roomId, Message message) {
    final chatIndex = _chats.indexWhere((c) => c.roomId == roomId);
    if (chatIndex >= 0) {
      final isSelfMessage = message.isSelf;
      final unread = isSelfMessage ? 0 : (_chats[chatIndex].unreadCount + 1);

      _chats[chatIndex] = _chats[chatIndex].copyWith(
        lastMessage: message.content,
        lastMessageTime: message.timestamp,
        unreadCount: unread,
      );
      _sortChats();
      notifyListeners();
    } else {
      if (message.isSelf) {
        // 自己的消息缺少会话信息时，直接刷新等待服务端返回
        unawaited(fetchChats());
        return;
      }

      // 单聊场景优先展示对方昵称/账号，避免显示包含自己名称的 room_name
      final roomTypeRaw = _readString(message.extra, const [
        'room_type',
        'roomType',
        'chat_type',
        'chatType',
      ]);
      final inferredType = () {
        if (roomTypeRaw == null) {
          return ChatType.single;
        }
        final value = roomTypeRaw.toLowerCase();
        if (value == 'private' || value == 'single') {
          return ChatType.single;
        }
        if (value == 'favorite') {
          return ChatType.favorite;
        }
        return ChatType.group;
      }();

      final chatName = () {
        if (inferredType == ChatType.favorite) {
          return '收藏夹';
        }
        if (inferredType == ChatType.single) {
          return (_readString(message.extra, const [
                'sender_nickname',
                'senderNickname',
              ]) ??
              _readString(message.extra, const [
                'sender_username',
                'senderUsername',
              ]) ??
              message.senderName);
        }
        return (_readString(message.extra, const [
              'room_name',
              'roomName',
              'chat_name',
              'chatName',
            ]) ??
            message.senderName);
      }();

      final placeholder = Chat(
        id: roomId,
        roomId: roomId,
        name: chatName,
        avatar: inferredType == ChatType.favorite
            ? AppAssets.chatFavorite
            : message.senderAvatar,
        type: inferredType,
        lastMessage: message.content,
        lastMessageTime: message.timestamp,
        unreadCount: inferredType == ChatType.favorite ? 0 : 1,
        isPinned: inferredType == ChatType.favorite,
        extra: {
          if (message.extra != null) ...message.extra!,
          'placeholder': true,
        },
      );

      _chats.add(placeholder);
      _sortChats();
      notifyListeners();

      // 异步刷新会话列表，确保占位数据尽快被服务端数据覆盖
      unawaited(fetchChats());
    }
  }

  /// 安排消息重试
  void _scheduleRetry(String messageId, [int attempt = 1]) {
    if (attempt > 3) {
      debugPrint('Max retry attempts reached for message: $messageId');
      return;
    }

    Future.delayed(Duration(seconds: 2 * attempt), () {
      resendMessage(messageId);
    });
  }

  /// 标记消息已读
  Future<void> markMessagesAsRead(String roomId, String lastMessageId) async {
    try {
      final session = await _tokenStorage.readSession();
      if (session == null) return;

      final uri = Uri.parse(
        '${AppConfig.apiBaseUrl}/rooms/$roomId/messages/read',
      );

      await http.post(
        uri,
        headers: {
          'Authorization': 'Bearer ${session.token}',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'message_id': lastMessageId}),
      );

      // 更新本地消息状态
      final messages = _messagesByRoom[roomId];
      if (messages != null) {
        for (final msg in messages) {
          if (!msg.isSelf && msg.status != MessageStatus.read) {
            final index = messages.indexOf(msg);
            messages[index] = msg.copyWith(status: MessageStatus.read);
          }
        }
      }

      markChatAsRead(roomId);
    } catch (e) {
      debugPrint('Failed to mark messages as read: $e');
    }
  }

  /// 清除房间消息
  void clearRoomMessages(String roomId) {
    _messagesByRoom.remove(roomId);
    _clearMessageReadersForRoom(roomId);
    notifyListeners();
  }

  /// 清除所有数据
  void clearAll() {
    _messagesByRoom.clear();
    _pendingMessages.clear();
    _chats.clear();
    _messageReadersCache.clear();
    _roomMemberCountCache.clear();
    try {
      WebSocketService.instance.ensureRoomsSubscribed(
        const <String>[],
        pruneMissing: true,
      );
    } catch (_) {
      // 忽略清理期间的异常
    }
    notifyListeners();
  }

  /// 将会话标记为已读
  void markChatAsRead(String roomId) {
    final chatIndex = _chats.indexWhere((c) => c.roomId == roomId);
    if (chatIndex >= 0) {
      _chats[chatIndex] = _chats[chatIndex].copyWith(unreadCount: 0);
      notifyListeners();
    }
  }

  void _invalidateMessageReaders(String roomId, String messageId) {
    final key = _buildReaderCacheKey(roomId, messageId);
    if (_messageReadersCache.remove(key) != null) {
      notifyListeners();
    }
  }

  void _clearMessageReadersForRoom(String roomId) {
    final keysToRemove = _messageReadersCache.keys
        .where((key) => key.startsWith('$roomId::'))
        .toList();
    for (final key in keysToRemove) {
      _messageReadersCache.remove(key);
    }
  }

  String _buildReaderCacheKey(String roomId, String messageId) {
    return '$roomId::$messageId';
  }

  /// 解析会话 JSON
  Chat _chatFromJson(Map<String, dynamic> json) {
    final roomId = _readString(json, const ['room_id', 'roomId', 'id']) ?? '';
    final name =
        _readString(json, const ['name', 'room_name', 'roomName']) ?? '';
    final avatar = _readString(json, const [
      'avatar_url',
      'avatarUrl',
      'avatar',
    ]);

    final lastMessage = _readMap(json, const ['last_message', 'lastMessage']);
    final lastMessageTime =
        _readDate(lastMessage, const [
          'created_at',
          'createdAt',
          'timestamp',
        ]) ??
        _readDate(json, const ['last_read_at', 'lastReadAt']) ??
        DateTime.now();

    final unread = _readInt(json, const ['unread_count', 'unreadCount']);

    final extra = <String, dynamic>{
      'last_message_id': _readString(lastMessage, const [
        'id',
        'message_id',
        'messageId',
      ]),
      'last_message_type': _readString(lastMessage, const [
        'message_type',
        'messageType',
        'type',
      ]),
      'last_message_sender_id': _readString(lastMessage, const [
        'sender_id',
        'senderId',
      ]),
      'last_message_sender_username': _readString(lastMessage, const [
        'sender_username',
        'senderUsername',
      ]),
      'last_message_sender_nickname': _readString(lastMessage, const [
        'sender_nickname',
        'senderNickname',
      ]),
      'last_read_message_id': _readString(json, const [
        'last_read_message_id',
        'lastReadMessageId',
      ]),
      'last_read_at': _readString(json, const ['last_read_at', 'lastReadAt']),
      // 可能由后端返回的对端信息/备注，用于聊天列表标题显示
      'friend_username': _readString(json, const [
        'friend_username',
        'friendUsername',
      ]),
      'friend_nickname': _readString(json, const [
        'friend_nickname',
        'friendNickname',
      ]),
      'friend_name': _readString(json, const ['friend_name', 'friendName']),
      'friend_remark': _readString(json, const [
        'friend_remark',
        'friendRemark',
        'remark',
      ]),
    }..removeWhere((_, value) => value == null);

    final chatType = _mapRoomType(
      _readString(json, const ['room_type', 'roomType', 'type']),
    );

    var lastMessageText =
        _readString(lastMessage, const ['content', 'text', 'message']) ?? '';
    if (chatType == ChatType.favorite && lastMessageText.trim().isEmpty) {
      lastMessageText = '将消息转发到这里即可保存';
    }

    var effectiveAvatar = avatar;
    if (chatType == ChatType.favorite) {
      effectiveAvatar = AppAssets.chatFavorite;
    }

    final effectiveUnread = chatType == ChatType.favorite ? 0 : unread;

    return Chat(
      id: roomId,
      roomId: roomId,
      name: name,
      avatar: effectiveAvatar,
      type: chatType,
      lastMessage: lastMessageText,
      lastMessageTime: lastMessageTime,
      unreadCount: effectiveUnread,
      isPinned: chatType == ChatType.favorite,
      extra: extra.isEmpty ? null : extra,
    );
  }

  /// 按置顶与时间排序
  void _sortChats() {
    _chats.sort((a, b) {
      if (a.isPinned != b.isPinned) {
        return a.isPinned ? -1 : 1;
      }
      return b.lastMessageTime.compareTo(a.lastMessageTime);
    });
  }

  ChatType _mapRoomType(String? rawType) {
    switch (rawType?.toLowerCase()) {
      case 'private':
        return ChatType.single;
      case 'favorite':
        return ChatType.favorite;
      case 'group':
      case 'public':
      default:
        return ChatType.group;
    }
  }

  void _syncWebSocketSubscriptions() {
    try {
      WebSocketService.instance.ensureRoomsSubscribed(
        _chats.map((chat) => chat.roomId),
        pruneMissing: true,
      );
    } catch (e) {
      debugPrint('Failed to sync WebSocket rooms: $e');
    }
  }

  /// 确保会话占位存在，用于处理服务端推送的新房间事件
  void ensureRoomPlaceholder({
    required String roomId,
    required String name,
    String? roomType,
    String? avatarUrl,
    String? description,
    String? initiatorId,
    DateTime? createdAt,
  }) {
    if (roomId.isEmpty) return;

    final chatType = _mapRoomType(roomType);
    final now = createdAt ?? DateTime.now();
    final existingIndex = _chats.indexWhere((chat) => chat.roomId == roomId);
    final extra = <String, dynamic>{
      'placeholder': true,
      if (description != null && description.isNotEmpty)
        'description': description,
      if (initiatorId != null && initiatorId.isNotEmpty)
        'initiator_id': initiatorId,
    };

    if (existingIndex >= 0) {
      final existing = _chats[existingIndex];
      final mergedExtra = <String, dynamic>{
        if (existing.extra != null) ...existing.extra!,
        ...extra,
      };
      _chats[existingIndex] = existing.copyWith(
        name: name.isNotEmpty ? name : existing.name,
        avatar: avatarUrl ?? existing.avatar,
        type: chatType,
        extra: mergedExtra.isEmpty ? existing.extra : mergedExtra,
      );
    } else {
      final placeholder = Chat(
        id: roomId,
        roomId: roomId,
        name: name.isNotEmpty ? name : '新群聊',
        avatar: avatarUrl,
        type: chatType,
        lastMessage: '',
        lastMessageTime: now,
        unreadCount: 0,
        extra: extra.isEmpty ? null : extra,
      );
      _chats.add(placeholder);
    }

    _sortChats();
    _syncWebSocketSubscriptions();
    notifyListeners();
  }

  static const List<String> _chatListKeys = <String>[
    'items',
    'list',
    'rows',
    'rooms',
    'chats',
    'results',
    'records',
    'data',
  ];

  @visibleForTesting
  static List<Map<String, dynamic>>? debugParseChatList(dynamic payload) {
    return _tryExtractChatList(payload);
  }

  static List<Map<String, dynamic>>? _tryExtractChatList(
    dynamic payload, {
    int depth = 0,
  }) {
    if (depth > 6) {
      return null;
    }
    if (payload == null) {
      return depth == 0 ? null : <Map<String, dynamic>>[];
    }
    if (payload is List) {
      return payload.whereType<Map<String, dynamic>>().toList();
    }
    if (payload is Map<String, dynamic>) {
      if (payload.isNotEmpty &&
          payload.values.every((value) => value is Map<String, dynamic>)) {
        return payload.values.cast<Map<String, dynamic>>().toList();
      }
      for (final key in _chatListKeys) {
        if (!payload.containsKey(key)) continue;
        final next = payload[key];
        if (identical(next, payload)) continue;
        final result = _tryExtractChatList(next, depth: depth + 1);
        if (result != null) {
          return result;
        }
      }
    }
    return null;
  }

  /// 从房间名中剔除当前用户的名称，仅返回对方显示名（用于单聊兜底）
  String _stripSelfFromRoomName(String roomName, Set<String> selfNames) {
    final normalizedSelf = selfNames
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toSet();
    if (normalizedSelf.isEmpty) return roomName;

    // 常见分隔符与连接词
    const separators = [',', '，', '/', '|', '&', '、', '-', '·'];
    const joiners = ['与', '和'];

    // 将连接词统一替换为分隔符，便于 split
    var work = roomName;
    for (final j in joiners) {
      work = work.replaceAll(j, ',');
    }
    for (final s in separators) {
      work = work.replaceAll(s, ',');
    }

    final parts = work
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    if (parts.isEmpty) return roomName;

    final candidates = parts
        .where((p) => !normalizedSelf.contains(p))
        .toList(growable: false);
    if (candidates.isEmpty) return parts.first; // 全部是自己的名称，返回首个

    // 取最长的片段作为对方显示名（更稳健）
    candidates.sort((a, b) => b.length.compareTo(a.length));
    return candidates.first;
  }

  static String? _readString(Map<String, dynamic>? source, List<String> keys) {
    if (source == null) return null;
    for (final key in keys) {
      if (!source.containsKey(key)) continue;
      final value = source[key];
      if (value == null) continue;
      if (value is String) return value.trim();
      if (value is num || value is bool) return value.toString();
    }
    return null;
  }

  static Map<String, dynamic>? _readMap(
    Map<String, dynamic>? source,
    List<String> keys,
  ) {
    if (source == null) return null;
    for (final key in keys) {
      final value = source[key];
      if (value is Map<String, dynamic>) return value;
    }
    return null;
  }

  static int _readInt(
    Map<String, dynamic> source,
    List<String> keys, {
    int defaultValue = 0,
  }) {
    for (final key in keys) {
      if (!source.containsKey(key)) continue;
      final value = source[key];
      if (value is int) return value;
      if (value is num) return value.toInt();
      if (value is String) {
        final parsed = int.tryParse(value);
        if (parsed != null) return parsed;
      }
    }
    return defaultValue;
  }

  static DateTime? _readDate(Map<String, dynamic>? source, List<String> keys) {
    final raw = _readString(source, keys);
    if (raw == null || raw.isEmpty) return null;
    return DateTime.tryParse(raw)?.toLocal();
  }

  Message _messageFromResponse(
    MessageResponse response,
    String currentUserId, {
    MessageStatus status = MessageStatus.sent,
  }) {
    final type = _mapMessageType(response.messageType);
    final isSelf = response.senderId == currentUserId;

    return Message(
      id: response.id,
      roomId: response.roomId,
      senderId: response.senderId,
      senderUsername: response.senderUsername.isNotEmpty
          ? response.senderUsername
          : response.senderId,
      senderName: response.displayName,
      senderAvatar: response.senderAvatarUrl,
      content: response.content,
      type: type,
      status: status,
      timestamp: response.createdAt,
      isSelf: isSelf,
      extra: response.senderNickname == null
          ? null
          : {'sender_nickname': response.senderNickname},
    );
  }

  Message _messageFromWebSocket(
    WebSocketMessage wsMessage,
    String currentUserId,
  ) {
    final type = _mapMessageType(wsMessage.messageType);
    final isSelf = wsMessage.senderId == currentUserId;
    final status = isSelf ? MessageStatus.sent : MessageStatus.delivered;

    return Message(
      id: wsMessage.id,
      roomId: wsMessage.roomId,
      senderId: wsMessage.senderId,
      senderUsername: wsMessage.senderUsername ?? wsMessage.senderId,
      senderName: wsMessage.displayName,
      senderAvatar: wsMessage.senderAvatarUrl,
      content: wsMessage.content,
      type: type,
      status: status,
      timestamp: wsMessage.timestamp,
      isSelf: isSelf,
      extra: wsMessage.extra,
    );
  }

  MessageType _mapMessageType(String raw) {
    switch (raw.toLowerCase()) {
      case 'image':
        return MessageType.image;
      case 'voice':
        return MessageType.voice;
      case 'video':
        return MessageType.video;
      case 'file':
        return MessageType.file;
      case 'system':
        return MessageType.system;
      case 'text':
      default:
        return MessageType.text;
    }
  }
}

/// 消息响应模型
class MessageResponse {
  final String id;
  final String roomId;
  final String senderId;
  final String senderUsername;
  final String? senderNickname;
  final String? senderAvatarUrl;
  final String content;
  final String messageType;
  final DateTime createdAt;

  MessageResponse({
    required this.id,
    required this.roomId,
    required this.senderId,
    required this.senderUsername,
    required this.senderNickname,
    required this.senderAvatarUrl,
    required this.content,
    required this.messageType,
    required this.createdAt,
  });

  factory MessageResponse.fromJson(Map<String, dynamic> json) {
    return MessageResponse(
      id: json['id'] ?? '',
      roomId: json['room_id'] ?? '',
      senderId: json['sender_id'] ?? '',
      senderUsername: json['sender_username'] ?? '',
      senderNickname: json['sender_nickname'] as String?,
      senderAvatarUrl: json['sender_avatar_url'] as String?,
      content: json['content'] ?? '',
      messageType: json['message_type'] ?? 'text',
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
    );
  }

  String get displayName {
    if (senderNickname != null && senderNickname!.isNotEmpty) {
      return senderNickname!;
    }
    return senderUsername;
  }
}
