import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:mime/mime.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart' as uuid_pkg;

import '../constants/app_assets.dart';
import '../constants/app_config.dart';
import '../network/direct_upload.dart';
import '../utils/file_hash.dart';
import '../storage/attachment_cache.dart';
import '../storage/attachment_url_cache.dart';
import '../storage/avatar_cache.dart';
import '../storage/token_storage.dart';
import '../storage/message_storage.dart';
import '../storage/chat_cache.dart';
import 'local_notification_service.dart';
import 'upload_policy_service.dart';
import '../../features/chat/models/message_model.dart';
import '../../features/chat/models/message_reader.dart';
import '../../features/chat/models/chat_model.dart';
import 'room_avatar_service.dart';
import 'room_service.dart';
import 'user_avatar_service.dart';
import 'user_service.dart';
import 'websocket_service.dart';

/// 消息状态
enum MessageStatus {
  sending, // 发送中
  sent, // 已发送
  delivered, // 已送达
  read, // 已读
  failed, // 发送失败
}

/// 附件路径更新事件
class AttachmentPathUpdate {
  final String messageId;
  final String attachmentKey;
  final String? localPath;

  AttachmentPathUpdate({
    required this.messageId,
    required this.attachmentKey,
    required this.localPath,
  });
}

/// 待发送的附件草稿
class MessageAttachmentDraft {
  MessageAttachmentDraft({
    required this.type,
    required this.file,
    this.displayName,
    this.mime,
    this.width,
    this.height,
    this.durationMs,
    this.existingKey,
  });

  final MessagePartType type;
  final File file;
  final String? displayName;
  final String? mime;
  final int? width;
  final int? height;
  final int? durationMs;
  final String? existingKey;

  bool get hasExistingKey => existingKey != null && existingKey!.isNotEmpty;
}

/// 消息服务 - 管理消息的发送、接收和存储
class MessageService with ChangeNotifier {
  static const int _multipartThresholdBytes = 5 * 1024 * 1024;

  MessageService({
    TokenStorage? tokenStorage,
    MessageStorage? messageStorage,
    ChatCache? chatCache,
  }) : _tokenStorage = tokenStorage ?? const TokenStorage(),
       _messageStorage = messageStorage ?? const MessageStorage(),
       _chatCache = chatCache ?? const ChatCache() {
    _loadCachedChats();
  }

  final TokenStorage _tokenStorage;
  final MessageStorage _messageStorage;
  final ChatCache _chatCache;

  // 消息存储 (roomId -> messages)
  final Map<String, List<Message>> _messagesByRoom = {};

  // 消息发送队列
  final Map<String, Message> _pendingMessages = {};
  final Map<String, _PendingMessagePayload> _pendingPayloads = {};

  // 聊天列表
  List<Chat> _chats = [];
  final Map<String, List<MessageReader>> _messageReadersCache = {};
  final Map<String, int> _roomMemberCountCache = {};
  // 每个房间可能存在多条置顶消息，这里缓存 messageId 列表以便快速查询
  final Map<String, List<String>> _pinnedMessageIds = {};
  // 上传进度节流计时器 (roomId:messageId:key -> timestamp)
  final Map<String, int> _progressUpdateThrottle = {};

  // 下载去重：正在进行的下载任务 (attachmentKey -> Future)
  final Map<String, Future<String?>> _pendingDownloads = {};

  // 附件路径更新广播
  final _attachmentPathController =
      StreamController<AttachmentPathUpdate>.broadcast();

  /// 附件路径更新流，UI 组件可以监听此流来实时更新
  Stream<AttachmentPathUpdate> get attachmentPathUpdates =>
      _attachmentPathController.stream;

  // 单例模式
  static MessageService? _instance;
  static MessageService get instance {
    _instance ??= MessageService();
    return _instance!;
  }

  // 防抖定时器
  Timer? _fetchChatsDebouncer;
  bool _isLoadingChatsFromCache = false;
  bool _offlineSyncInProgress = false;

  /// 获取房间的消息列表
  List<Message> getMessages(String roomId) {
    return List.from(_messagesByRoom[roomId] ?? []);
  }

  Future<List<Message>> loadCachedMessages(String roomId) async {
    if (roomId.isEmpty) {
      return const [];
    }
    try {
      final cached = await _messageStorage.loadMessages(roomId);
      _messagesByRoom[roomId] = List<Message>.from(cached);

      // 恢复发送中或失败的消息到重试队列
      _restorePendingMessages(roomId, cached);

      notifyListeners();
      return cached;
    } catch (e) {
      debugPrint('Failed to load cached messages: $e');
      return const [];
    }
  }

  /// 恢复发送中的消息到重试队列
  void _restorePendingMessages(String roomId, List<Message> messages) {
    for (final message in messages) {
      // 只恢复自己发送的、状态为发送中的消息
      if (!message.isSelf) continue;
      if (message.status != MessageStatus.sending) {
        continue;
      }

      // 如果已经在待发送队列中，跳过
      if (_pendingMessages.containsKey(message.id)) continue;

      debugPrint('Restoring pending message: ${message.id}');

      // 添加到待发送队列
      _pendingMessages[message.id] = message;

      // 构建 payload，从 parts 中提取实际文本内容
      final parts = <Map<String, dynamic>>[];
      String? actualTextContent;
      for (final part in message.parts) {
        if (part.type == MessagePartType.text && part.text != null) {
          parts.add({'type': 'text', 'text': part.text});
          // 提取实际文本内容
          actualTextContent = part.text;
        } else if (part.attachment != null) {
          parts.add({
            'type': part.type.name,
            'key': part.attachment!.key,
            if (part.attachment!.name != null) 'name': part.attachment!.name,
            if (part.attachment!.mime != null) 'mime': part.attachment!.mime,
            if (part.attachment!.size != null) 'size': part.attachment!.size,
            if (part.attachment!.width != null) 'width': part.attachment!.width,
            if (part.attachment!.height != null)
              'height': part.attachment!.height,
            if (part.attachment!.durationMs != null)
              'duration_ms': part.attachment!.durationMs,
            if (part.attachment!.thumbnailKey != null)
              'thumbnail_key': part.attachment!.thumbnailKey,
          });
        }
      }

      // 使用从 parts 提取的实际文本内容，而不是占位符（如 [语音]、[图片] 等）
      _pendingPayloads[message.id] = _PendingMessagePayload(
        roomId: roomId,
        content: actualTextContent,
        parts: parts,
        quotedMessageId: message.quotedMessage?.id,
      );

      // 启动重试
      _scheduleRetry(message.id);
    }
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

  /// 获取 TokenStorage 实例
  TokenStorage get tokenStorage => _tokenStorage;

  /// 获取房间成员列表详细信息
  Future<List<Map<String, dynamic>>> fetchRoomMembers(String roomId) async {
    if (roomId.isEmpty) return [];

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

    return decoded.cast<Map<String, dynamic>>();
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

  /// 从缓存加载会话列表
  Future<void> _loadCachedChats() async {
    if (_isLoadingChatsFromCache) return;
    _isLoadingChatsFromCache = true;

    try {
      final cachedChats = await _chatCache.loadChats();
      if (cachedChats != null && cachedChats.isNotEmpty) {
        _chats = cachedChats;
        notifyListeners();
        debugPrint('Loaded ${cachedChats.length} chats from cache');
      }
    } catch (e) {
      debugPrint('Failed to load cached chats: $e');
    } finally {
      _isLoadingChatsFromCache = false;
    }
  }

  /// 从服务器拉取会话列表（带防抖）
  Future<List<Chat>> fetchChats({bool force = false}) async {
    // 如果不是强制刷新，使用防抖
    if (!force) {
      // 取消之前的防抖定时器
      _fetchChatsDebouncer?.cancel();

      // 设置新的防抖定时器（500ms）
      final completer = Completer<List<Chat>>();
      _fetchChatsDebouncer = Timer(const Duration(milliseconds: 500), () async {
        try {
          final result = await _actualFetchChats();
          completer.complete(result);
        } catch (e) {
          completer.completeError(e);
        }
      });

      return completer.future;
    }

    // 强制刷新直接执行
    return _actualFetchChats();
  }

  /// 离线消息补拉：用于 WebSocket 断线重连后把缺失消息拉齐
  ///
  /// 当前策略：
  /// - 仅对未读会话补拉（避免全量刷爆请求）
  /// - 以本地最后一条消息 ID（内存/SQLite）或 last_read_message_id 作为 since_id 游标
  /// - 分页循环直到没有更多数据或达到最大页数
  Future<void> syncOfflineMessages({
    int perPage = 100,
    int maxRooms = 20,
    int maxPagesPerRoom = 10,
  }) async {
    if (_offlineSyncInProgress) return;
    _offlineSyncInProgress = true;

    try {
      final candidates = _chats
          .where((chat) {
            if (chat.type == ChatType.favorite) return false;
            if (chat.roomId.trim().isEmpty) return false;
            return chat.unreadCount > 0;
          })
          .toList()
        ..sort((a, b) => b.lastMessageTime.compareTo(a.lastMessageTime));

      if (candidates.isEmpty) return;

      final rooms = candidates.take(maxRooms).toList();
      for (final chat in rooms) {
        await _syncOfflineMessagesForRoom(
          chat,
          perPage: perPage,
          maxPages: maxPagesPerRoom,
        );
      }
    } catch (e) {
      debugPrint('[OfflineSync] Failed to sync: $e');
    } finally {
      _offlineSyncInProgress = false;
    }
  }

  Future<void> _syncOfflineMessagesForRoom(
    Chat chat, {
    required int perPage,
    required int maxPages,
  }) async {
    final roomId = chat.roomId.trim();
    if (roomId.isEmpty) return;

    String? sinceId;

    // 1) 内存缓存（进入过聊天室）
    final cached = _messagesByRoom[roomId];
    if (cached != null && cached.isNotEmpty) {
      cached.sort((a, b) => a.timestamp.compareTo(b.timestamp));
      sinceId = cached.last.id;
    }

    // 2) SQLite 缓存
    sinceId ??= await _messageStorage.getLatestMessageId(roomId);

    // 3) 会话列表中的 last_read_message_id（确保最少能补到未读消息）
    final extra = chat.extra;
    final lastReadId =
        extra != null ? (extra['last_read_message_id'] as String?) : null;
    if (sinceId == null || sinceId!.trim().isEmpty) {
      sinceId = lastReadId;
    }

    // 4) 实在拿不到游标，则拉一页最新消息作为兜底
    if (sinceId == null || sinceId.trim().isEmpty) {
      await loadMessages(roomId, limit: perPage);
      return;
    }

    var cursor = sinceId.trim();
    for (var page = 0; page < maxPages; page++) {
      final fetched = await loadMessages(
        roomId,
        limit: perPage,
        sinceId: cursor,
      );
      if (fetched.isEmpty) {
        break;
      }

      final newestId = fetched.last.id;
      if (newestId == cursor) {
        break;
      }

      cursor = newestId;
      if (fetched.length < perPage) {
        break;
      }
    }
  }

  /// 实际执行拉取会话列表
  Future<List<Chat>> _actualFetchChats() async {
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

    // 保存到缓存（异步，不阻塞返回）
    unawaited(_chatCache.saveChats(chats));

    return chats;
  }

  /// 发送文本消息
  Future<void> sendTextMessage(
    String roomId,
    String content, {
    Message? quotedMessage,
  }) async {
    await sendRichMessage(
      roomId: roomId,
      text: content,
      quotedMessage: quotedMessage,
    );
  }

  Future<void> sendRichMessage({
    required String roomId,
    String? text,
    List<MessageAttachmentDraft> attachments = const [],
    Message? quotedMessage,
  }) async {
    final trimmedText = text?.trim();
    if (roomId.isEmpty) {
      return;
    }
    if ((trimmedText == null || trimmedText.isEmpty) && attachments.isEmpty) {
      return;
    }

    final policy = await UploadPolicyService.instance.getPolicy();
    _validateDraft(trimmedText, attachments, policy);

    final totalSize = await _calculateAttachmentSize(attachments);
    final maxBytes = policy.maxTotalBytes();
    if (totalSize > maxBytes) {
      throw StateError(
        '附件总大小超过 ${policy.maxTotalSizeMb} MB 限制',
      );
    }

    final session = await _tokenStorage.readSession();
    if (session == null) {
      throw Exception('User not authenticated');
    }

    final tempId = const uuid_pkg.Uuid().v4();
    final plans = <_AttachmentUploadPlan>[];

    try {
      if (attachments.isNotEmpty) {
        plans.addAll(
          await _prepareAttachmentUploads(
            roomId: roomId,
            messageId: tempId,
            attachments: attachments,
            token: session.token,
            policy: policy,
          ),
        );
      }

      final pendingMessage = _buildPendingMessage(
        tempId: tempId,
        roomId: roomId,
        senderId: session.user.id,
        senderUsername: session.user.username,
        senderName: session.user.nickname?.isNotEmpty == true
            ? session.user.nickname!
            : session.user.username,
        senderAvatar: session.user.avatarUrl,
        text: trimmedText,
        attachments: attachments,
        plans: plans,
        quotedMessage: quotedMessage,
      );

      _addMessage(pendingMessage);
      _pendingMessages[tempId] = pendingMessage;

      final partsPayload = _buildPartsPayload(
        text: trimmedText,
        attachments: attachments,
        plans: plans,
      );
      _pendingPayloads[tempId] = _PendingMessagePayload(
        roomId: roomId,
        content: trimmedText,
        parts: partsPayload,
        quotedMessageId: quotedMessage?.id,
      );

      for (final plan in plans) {
        await _executeAttachmentUpload(plan);
      }

      final response = await _sendMessageAPI(
        roomId,
        content: trimmedText,
        parts: partsPayload,
        quotedMessageId: quotedMessage?.id,
      );

      final updated = _messageFromResponse(
        response,
        session.user.id,
        overrideStatus: MessageStatus.sent,
      );

      if (_pendingMessages.containsKey(tempId)) {
        _replaceMessage(tempId, updated);
        _pendingMessages.remove(tempId);
      } else {
        _replaceMessage(updated.id, updated);
      }

      _pendingPayloads.remove(tempId);
      _updateChatLastMessage(roomId, updated);
      unawaited(_hydrateAttachmentLocalPaths(updated));
    } catch (error, stackTrace) {
      debugPrint('Failed to send message: $error');
      if (kDebugMode) {
        debugPrint(stackTrace.toString());
      }
      // 保持 sending 状态，持续重试直到成功
      _scheduleRetry(tempId);
    }
  }

  /// 重发失败的消息（手动触发）
  Future<void> resendMessage(String messageId) async {
    // 取消自动重试定时器
    _cancelRetry(messageId);

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

      final payload = _pendingPayloads[messageId];
      // 使用 payload 中的内容，不回退到 message.content（可能是占位符如 [语音]）
      final response = await _sendMessageAPI(
        payload?.roomId ?? message.roomId,
        content: payload?.content,
        parts: payload?.parts ?? const <Map<String, dynamic>>[],
        quotedMessageId: payload?.quotedMessageId ?? message.quotedMessage?.id,
      );

      final updated = _messageFromResponse(
        response,
        session.user.id,
        overrideStatus: MessageStatus.sent,
      );
      _replaceMessage(messageId, updated);
      _pendingMessages.remove(messageId);
      _pendingPayloads.remove(messageId);
      unawaited(_hydrateAttachmentLocalPaths(updated));
    } catch (e) {
      debugPrint('Failed to resend message: $e');
      // 保持 sending 状态，继续自动重试
      _scheduleRetry(messageId);
    }
  }

  Future<void> forwardMessage({
    required Message original,
    required String targetRoomId,
    required ForwardInfo forwardInfo,
  }) async {
    final session = await _tokenStorage.readSession();
    if (session == null) {
      throw Exception('User not authenticated');
    }

    if (targetRoomId.isEmpty) {
      throw ArgumentError('targetRoomId is required');
    }

    if (original.type != MessageType.text) {
      throw UnsupportedError('当前仅支持转发文本消息');
    }

    final tempId = const uuid_pkg.Uuid().v4();
    final now = DateTime.now();

    final tempExtra = _mergeExtra(original.extra, {
      'forward': forwardInfo.toCacheJson(),
    });

    final tempMessage = Message(
      id: tempId,
      roomId: targetRoomId,
      senderId: session.user.id,
      senderUsername: session.user.username,
      senderName: session.user.nickname?.isNotEmpty == true
          ? session.user.nickname!
          : session.user.username,
      senderAvatar: session.user.avatarUrl,
      content: original.content,
      type: original.type,
      status: MessageStatus.sending,
      timestamp: now,
      isSelf: true,
      extra: tempExtra,
      quotedMessage: original.quotedMessage,
      forwardInfo: forwardInfo,
    );

    _addMessage(tempMessage);
    _pendingMessages[tempId] = tempMessage;

    try {
      final response = await _forwardMessageAPI(
        roomId: targetRoomId,
        originalMessageId: original.id,
        token: session.token,
      );

      var updated = _messageFromResponse(
        response,
        session.user.id,
        overrideStatus: MessageStatus.sent,
      );

      if (_pendingMessages.containsKey(tempId)) {
        _replaceMessage(tempId, updated);
        _pendingMessages.remove(tempId);
      } else {
        _replaceMessage(updated.id, updated);
      }

      _updateChatLastMessage(targetRoomId, updated);
      unawaited(_hydrateAttachmentLocalPaths(updated));
    } catch (e) {
      debugPrint('Failed to forward message: $e');
      _updateMessageStatus(tempId, MessageStatus.failed);
    }
  }

  Future<void> pinMessage(String roomId, String messageId) async {
    final session = await _tokenStorage.readSession();
    if (session == null) {
      throw Exception('User not authenticated');
    }

    final response = await _pinMessageAPI(
      roomId: roomId,
      messageId: messageId,
      token: session.token,
    );

    if (response.message != null) {
      final status = _currentMessageStatus(roomId, response.message!.id);
      final updated = _messageFromResponse(
        response.message!,
        session.user.id,
        overrideStatus: status,
      );
      _replaceMessage(updated.id, updated);
      unawaited(_hydrateAttachmentLocalPaths(updated));
      return;
    }

    if (response.isPinned) {
      final messages = _messagesByRoom[roomId];
      if (messages != null) {
        final index = messages.indexWhere((m) => m.id == messageId);
        if (index >= 0) {
          final msg = messages[index];
          final extra = _mergeExtra(msg.extra, {
            'pinned_at': response.pinnedAt?.toIso8601String(),
            'pinned_by': response.pinnedBy,
          });
          messages[index] = msg.copyWith(
            pinnedAt: response.pinnedAt,
            extra: extra,
          );
          _refreshPinnedCache(roomId);
          notifyListeners();
          unawaited(_persistMessages(roomId));
        }
      }
    } else {
      _refreshPinnedCache(roomId);
      notifyListeners();
    }
  }

  Future<void> unpinMessage(String roomId, String messageId) async {
    final session = await _tokenStorage.readSession();
    if (session == null) {
      throw Exception('User not authenticated');
    }

    final response = await _unpinMessageAPI(
      roomId: roomId,
      messageId: messageId,
      token: session.token,
    );

    if (response.message != null) {
      final status = _currentMessageStatus(roomId, response.message!.id);
      final updated = _messageFromResponse(
        response.message!,
        session.user.id,
        overrideStatus: status,
      );
      _replaceMessage(updated.id, updated);
      unawaited(_hydrateAttachmentLocalPaths(updated));
      return;
    }

    final messages = _messagesByRoom[roomId];
    if (messages != null) {
      final index = messages.indexWhere((m) => m.id == messageId);
      if (index >= 0) {
        final msg = messages[index];
        final extra = _mergeExtra(msg.extra, {
          'pinned_at': null,
          'pinned_by': null,
        });
        messages[index] = msg.copyWith(pinnedAt: null, extra: extra);
        _refreshPinnedCache(roomId);
        notifyListeners();
        unawaited(_persistMessages(roomId));
      } else {
        _refreshPinnedCache(roomId);
        notifyListeners();
      }
    } else {
      _refreshPinnedCache(roomId);
      notifyListeners();
    }
  }

  Future<void> markMessageDeleted(String roomId, String messageId) async {
    final session = await _tokenStorage.readSession();
    if (session == null) {
      throw Exception('User not authenticated');
    }

    final response = await _deleteMessageAPI(
      roomId: roomId,
      messageId: messageId,
      token: session.token,
    );

    final status = _currentMessageStatus(roomId, response.id);
    final updated = _messageFromResponse(
      response,
      session.user.id,
      overrideStatus: status,
    );

    _replaceMessage(response.id, updated);
    unawaited(_hydrateAttachmentLocalPaths(updated));
  }

  /// 编辑消息（仅支持编辑自己发送的文本消息）
  Future<void> editMessage({
    required String roomId,
    required String messageId,
    required String content,
  }) async {
    final session = await _tokenStorage.readSession();
    if (session == null) {
      throw Exception('User not authenticated');
    }

    final response = await _editMessageAPI(
      roomId: roomId,
      messageId: messageId,
      content: content,
      token: session.token,
    );

    final status = _currentMessageStatus(roomId, response.id);
    final updated = _messageFromResponse(
      response,
      session.user.id,
      overrideStatus: status,
    );

    _replaceMessage(response.id, updated);
    unawaited(_hydrateAttachmentLocalPaths(updated));
  }

  /// 添加消息反应
  Future<List<MessageReactionSummary>> addReaction({
    required String roomId,
    required String messageId,
    required String reactionKey,
  }) async {
    final session = await _tokenStorage.readSession();
    if (session == null) {
      throw Exception('User not authenticated');
    }

    final response = await _addReactionAPI(
      roomId: roomId,
      messageId: messageId,
      reactionKey: reactionKey,
      token: session.token,
    );

    // 更新消息的反应列表
    final messageIndex = _messagesByRoom[roomId]
        ?.indexWhere((m) => m.id == messageId);
    if (messageIndex != null && messageIndex >= 0) {
      final messages = _messagesByRoom[roomId]!;
      messages[messageIndex] = messages[messageIndex].copyWith(
        reactions: response.summaries,
      );
      notifyListeners();
    }

    return response.summaries;
  }

  /// 删除消息反应
  Future<List<MessageReactionSummary>> removeReaction({
    required String roomId,
    required String messageId,
    required String reactionKey,
  }) async {
    final session = await _tokenStorage.readSession();
    if (session == null) {
      throw Exception('User not authenticated');
    }

    final response = await _removeReactionAPI(
      roomId: roomId,
      messageId: messageId,
      reactionKey: reactionKey,
      token: session.token,
    );

    // 更新消息的反应列表
    final messageIndex = _messagesByRoom[roomId]
        ?.indexWhere((m) => m.id == messageId);
    if (messageIndex != null && messageIndex >= 0) {
      final messages = _messagesByRoom[roomId]!;
      messages[messageIndex] = messages[messageIndex].copyWith(
        reactions: response.summaries,
      );
      notifyListeners();
    }

    return response.summaries;
  }

  /// 获取消息的所有反应
  Future<List<MessageReactionSummary>> getReactions({
    required String roomId,
    required String messageId,
  }) async {
    final session = await _tokenStorage.readSession();
    if (session == null) {
      throw Exception('User not authenticated');
    }

    final response = await _getReactionsAPI(
      roomId: roomId,
      messageId: messageId,
      token: session.token,
    );

    return response.summaries;
  }

  Message? getPinnedMessage(String roomId) {
    final messages = _messagesByRoom[roomId];
    if (messages == null || messages.isEmpty) return null;

    final pinnedIds = _pinnedMessageIds[roomId];
    if (pinnedIds != null && pinnedIds.isNotEmpty) {
      final firstId = pinnedIds.first;
      for (final message in messages) {
        if (message.id == firstId && message.isPinned) {
          return message;
        }
      }
    }

    // 回退：直接从消息列表中找到第一条置顶消息
    for (final message in messages) {
      if (message.isPinned) {
        return message;
      }
    }
    return null;
  }

  List<Message> getPinnedMessages(String roomId) {
    final messages = _messagesByRoom[roomId];
    if (messages == null || messages.isEmpty) return [];

    final pinnedIds = _pinnedMessageIds[roomId];
    if (pinnedIds != null && pinnedIds.isNotEmpty) {
      final pinnedList = <Message>[];
      for (final message in messages) {
        if (pinnedIds.contains(message.id) && message.isPinned) {
          pinnedList.add(message);
        }
      }
      return pinnedList;
    }

    // 回退：直接从消息列表中找到所有置顶消息
    return messages.where((message) => message.isPinned).toList();
  }

  bool isMessagePinned(String roomId, String messageId) {
    final pinnedIds = _pinnedMessageIds[roomId];
    if (pinnedIds != null && pinnedIds.isNotEmpty) {
      return pinnedIds.contains(messageId);
    }
    final messages = _messagesByRoom[roomId];
    if (messages == null || messages.isEmpty) return false;
    for (final message in messages) {
      if (message.id == messageId) {
        return message.isPinned;
      }
    }
    return false;
  }

  /// 调用API发送消息
  Future<MessageResponse> _sendMessageAPI(
    String roomId, {
    String? content,
    List<Map<String, dynamic>> parts = const [],
    String? quotedMessageId,
  }) async {
    final session = await _tokenStorage.readSession();
    if (session == null) {
      throw Exception('User not authenticated');
    }

    final payload = <String, dynamic>{};
    final normalizedContent = content?.trim();
    if (normalizedContent != null && normalizedContent.isNotEmpty) {
      payload['content'] = normalizedContent;
    }
    if (parts.isNotEmpty) {
      payload['parts'] = parts;
    }
    if (quotedMessageId != null && quotedMessageId.isNotEmpty) {
      payload['quoted_message_id'] = quotedMessageId;
    }

    if (payload.isEmpty) {
      throw Exception('消息内容不能为空');
    }

    final uri = Uri.parse('${AppConfig.apiBaseUrl}/rooms/$roomId/messages');
    final response = await http.post(
      uri,
      headers: {
        'Authorization': 'Bearer ${session.token}',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(payload),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return MessageResponse.fromJson(data['message']);
    } else {
      throw Exception('Failed to send message: ${response.body}');
    }
  }

  Future<MessageResponse> _forwardMessageAPI({
    required String roomId,
    required String originalMessageId,
    required String token,
  }) async {
    final uri = Uri.parse(
      '${AppConfig.apiBaseUrl}/rooms/$roomId/messages/forward',
    );
    final response = await http.post(
      uri,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'original_message_id': originalMessageId}),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final payload = data['message'];
      if (payload is Map<String, dynamic>) {
        return MessageResponse.fromJson(payload);
      }
      throw Exception('Invalid forward message response structure');
    }

    throw Exception('Failed to forward message: ${response.body}');
  }

  Future<PinMessageServerResponse> _pinMessageAPI({
    required String roomId,
    required String messageId,
    required String token,
  }) async {
    final uri = Uri.parse(
      '${AppConfig.apiBaseUrl}/rooms/$roomId/messages/$messageId/pin',
    );
    final response = await http.post(
      uri,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return PinMessageServerResponse.fromJson(data);
    }

    throw Exception('置顶消息失败: ${response.body}');
  }

  Future<PinMessageServerResponse> _unpinMessageAPI({
    required String roomId,
    required String messageId,
    required String token,
  }) async {
    final uri = Uri.parse(
      '${AppConfig.apiBaseUrl}/rooms/$roomId/messages/$messageId/pin',
    );
    final response = await http.delete(
      uri,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return PinMessageServerResponse.fromJson(data);
    }

    throw Exception('取消置顶失败: ${response.body}');
  }

  Future<MessageResponse> _deleteMessageAPI({
    required String roomId,
    required String messageId,
    required String token,
  }) async {
    final uri = Uri.parse(
      '${AppConfig.apiBaseUrl}/rooms/$roomId/messages/$messageId',
    );
    final response = await http.delete(
      uri,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data is Map<String, dynamic>) {
        return MessageResponse.fromJson(data);
      }
      throw Exception('Invalid delete message response structure');
    }

    throw Exception('删除消息失败: ${response.body}');
  }

  Future<MessageResponse> _editMessageAPI({
    required String roomId,
    required String messageId,
    required String content,
    required String token,
  }) async {
    final uri = Uri.parse(
      '${AppConfig.apiBaseUrl}/rooms/$roomId/messages/$messageId',
    );
    final response = await http.patch(
      uri,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'content': content}),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data is Map<String, dynamic>) {
        return MessageResponse.fromJson(data);
      }
      throw Exception('Invalid edit message response structure');
    }

    throw Exception('编辑消息失败: ${response.body}');
  }

  Future<_ReactionResponse> _addReactionAPI({
    required String roomId,
    required String messageId,
    required String reactionKey,
    required String token,
  }) async {
    final uri = Uri.parse(
      '${AppConfig.apiBaseUrl}/rooms/$roomId/messages/$messageId/reactions',
    );
    final response = await http.post(
      uri,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'reaction_key': reactionKey}),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data is Map<String, dynamic>) {
        return _ReactionResponse.fromJson(data);
      }
      throw Exception('Invalid add reaction response structure');
    }

    throw Exception('添加反应失败: ${response.body}');
  }

  Future<_ReactionResponse> _removeReactionAPI({
    required String roomId,
    required String messageId,
    required String reactionKey,
    required String token,
  }) async {
    final uri = Uri.parse(
      '${AppConfig.apiBaseUrl}/rooms/$roomId/messages/$messageId/reactions?reaction_key=${Uri.encodeComponent(reactionKey)}',
    );
    final response = await http.delete(
      uri,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data is Map<String, dynamic>) {
        return _ReactionResponse.fromJson(data);
      }
      throw Exception('Invalid remove reaction response structure');
    }

    throw Exception('删除反应失败: ${response.body}');
  }

  Future<_ReactionResponse> _getReactionsAPI({
    required String roomId,
    required String messageId,
    required String token,
  }) async {
    final uri = Uri.parse(
      '${AppConfig.apiBaseUrl}/rooms/$roomId/messages/$messageId/reactions',
    );
    final response = await http.get(
      uri,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data is Map<String, dynamic>) {
        return _ReactionResponse.fromJson(data);
      }
      throw Exception('Invalid get reactions response structure');
    }

    throw Exception('获取反应失败: ${response.body}');
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
            .map((msg) => _messageFromResponse(msg, session.user.id))
            .toList();

        for (final message in newMessages) {
          unawaited(_hydrateAttachmentLocalPaths(message));
        }

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
          final existing = _messagesByRoom[roomId];
          if (existing != null && existing.isNotEmpty) {
            _messagesByRoom[roomId] = _mergeMessageLists(existing, newMessages);
          } else {
            _messagesByRoom[roomId] = newMessages;
          }
        }

        _refreshPinnedCache(roomId);
        notifyListeners();
        await _persistMessages(roomId);
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
      unawaited(_hydrateAttachmentLocalPaths(message));
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
    unawaited(_hydrateAttachmentLocalPaths(message));
    _updateChatLastMessage(message.roomId, message);

    if (index < 0) {
      _maybeNotifyLocalForIncomingMessage(message);
    }

    notifyListeners();
    unawaited(_persistMessages(message.roomId));
  }

  void _maybeNotifyLocalForIncomingMessage(Message message) {
    if (message.isSelf) return;
    if (message.type == MessageType.system) return;
    if (message.roomId.trim().isEmpty) return;

    final chatIndex = _chats.indexWhere((c) => c.roomId == message.roomId);
    final chat = chatIndex >= 0 ? _chats[chatIndex] : null;
    if (chat?.isMuted == true) return;

    final title = chat?.name.trim().isNotEmpty == true ? chat!.name : '聊天';
    final body = _buildLocalNotificationBody(message, chat);

    unawaited(
      LocalNotificationService.instance.maybeShowChatMessage(
        roomId: message.roomId,
        roomType: chat == null ? null : _rawRoomType(chat.type),
        chatName: chat?.name,
        messageId: message.id,
        title: title,
        body: body,
      ),
    );
  }

  String _buildLocalNotificationBody(Message message, Chat? chat) {
    final base = () {
      final content = message.content.trim();
      if (content.isNotEmpty) return content;
      switch (message.type) {
        case MessageType.image:
          return '[图片]';
        case MessageType.audio:
          return '[语音]';
        case MessageType.video:
          return '[视频]';
        case MessageType.file:
          return '[文件]';
        case MessageType.mixed:
          return '[多媒体消息]';
        case MessageType.system:
          return '[系统消息]';
        case MessageType.text:
          return '[消息]';
      }
    }();

    if (chat?.type == ChatType.group) {
      final sender = message.displaySenderName.trim();
      if (sender.isNotEmpty) {
        return '$sender：$base';
      }
    }
    return base;
  }

  String _rawRoomType(ChatType type) {
    switch (type) {
      case ChatType.group:
        return 'group';
      case ChatType.favorite:
        return 'favorite';
      case ChatType.single:
        return 'private';
    }
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
      unawaited(_persistMessages(roomId));
    }
  }

  Future<void> handleMessageUpdate({
    required String roomId,
    required String messageId,
    required bool isDeleted,
    DateTime? deletedAt,
    String? updateType,
    DateTime? editedAt,
    String? content,
  }) async {
    final messages = _messagesByRoom[roomId];
    if (messages == null || messages.isEmpty) return;

    final index = messages.indexWhere((m) => m.id == messageId);
    if (index == -1) return;

    final message = messages[index];
    final isEditUpdate = updateType == 'edited' || (!isDeleted && editedAt != null);
    
    if (isEditUpdate) {
      // 编辑消息
      final extra = _mergeExtra(message.extra, {
        'is_edited': true,
        'edited_at': editedAt?.toIso8601String(),
      });
      messages[index] = message.copyWith(
        content: content ?? message.content,
        isEdited: true,
        editedAt: editedAt,
        extra: extra,
      );
    } else {
      // 删除消息
      final extra = _mergeExtra(message.extra, {
        'is_deleted': isDeleted ? true : null,
        'deleted_at': deletedAt?.toIso8601String(),
      });
      messages[index] = message.copyWith(isDeleted: isDeleted, extra: extra);
    }

    if (isDeleted) {
      final list = List<String>.from(
        _pinnedMessageIds[roomId] ?? const <String>[],
      );
      if (list.remove(messageId)) {
        if (list.isEmpty) {
          _pinnedMessageIds.remove(roomId);
        } else {
          _pinnedMessageIds[roomId] = list;
        }
        _refreshPinnedCache(roomId);
      }
    }

    notifyListeners();
    unawaited(_persistMessages(roomId));
  }

  Future<void> handleReactionUpdate({
    required String roomId,
    required String messageId,
    required String reactionKey,
    required String userId,
    required String action,
  }) async {
    // 重新获取反应列表以更新 UI
    try {
      final summaries = await getReactions(
        roomId: roomId,
        messageId: messageId,
      );

      final messages = _messagesByRoom[roomId];
      if (messages != null && messages.isNotEmpty) {
        final index = messages.indexWhere((m) => m.id == messageId);
        if (index >= 0) {
          messages[index] = messages[index].copyWith(
            reactions: summaries,
          );
          notifyListeners();
          unawaited(_persistMessages(roomId));
        }
      }
    } catch (e) {
      debugPrint('Failed to handle reaction update: $e');
    }
  }

  Future<void> handlePinUpdate({
    required String roomId,
    String? messageId,
    required bool isPinned,
    DateTime? pinnedAt,
    String? pinnedBy,
  }) async {
    if (messageId != null && messageId.isNotEmpty) {
      final list = List<String>.from(
        _pinnedMessageIds[roomId] ?? const <String>[],
      );
      if (isPinned) {
        if (!list.contains(messageId)) {
          list.add(messageId);
        }
      } else {
        list.removeWhere((id) => id == messageId);
      }
      if (list.isEmpty) {
        _pinnedMessageIds.remove(roomId);
      } else {
        _pinnedMessageIds[roomId] = list;
      }
    }

    final messages = _messagesByRoom[roomId];
    var changed = false;

    if (messages != null && messages.isNotEmpty && messageId != null) {
      final index = messages.indexWhere((m) => m.id == messageId);
      if (index >= 0) {
        final message = messages[index];
        final extra = _mergeExtra(message.extra, {
          'pinned_at': pinnedAt?.toIso8601String(),
          'pinned_by': pinnedBy,
        });

        messages[index] = message.copyWith(
          pinnedAt: isPinned ? pinnedAt : null,
          extra: extra,
        );
        changed = true;
      }
    }

    _refreshPinnedCache(roomId);

    if (changed) {
      notifyListeners();
      unawaited(_persistMessages(roomId));
    } else {
      notifyListeners();
    }
  }

  Future<void> _persistMessages(String roomId) async {
    final messages = _messagesByRoom[roomId];
    if (messages == null) return;
    try {
      // 创建列表副本，避免在异步操作期间列表被修改导致并发修改异常
      final snapshot = List<Message>.from(messages);
      await _messageStorage.saveMessages(roomId, snapshot);
    } catch (e) {
      debugPrint('Failed to persist messages for $roomId: $e');
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
      _applyPinnedState(message.roomId, message);
    }
    messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    _refreshPinnedCache(message.roomId);
    notifyListeners();
    unawaited(_persistMessages(message.roomId));
  }

  /// 插入系统消息（用于群信息变更等通知）
  void insertSystemMessage({
    required String roomId,
    required String content,
  }) {
    if (roomId.isEmpty || content.isEmpty) return;

    final now = DateTime.now();
    final message = Message(
      id: 'system_${now.millisecondsSinceEpoch}',
      roomId: roomId,
      senderId: '',
      senderUsername: '',
      senderName: '',
      content: content,
      type: MessageType.system,
      status: MessageStatus.sent,
      timestamp: now,
      isSelf: false,
    );

    _addMessage(message);
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
    _applyPinnedState(newMessage.roomId, newMessage);
    _refreshPinnedCache(newMessage.roomId);
    notifyListeners();
    unawaited(_persistMessages(newMessage.roomId));
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

    final mergedExtra = _mergeExtra(oldMessage.extra, newMessage.extra);
    final merged = oldMessage.copyWith(
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
      extra: mergedExtra,
      quotedMessage: newMessage.quotedMessage ?? oldMessage.quotedMessage,
      forwardInfo: newMessage.forwardInfo ?? oldMessage.forwardInfo,
      isDeleted: newMessage.isDeleted || oldMessage.isDeleted,
      pinnedAt: newMessage.pinnedAt ?? oldMessage.pinnedAt,
    );
    _applyPinnedState(merged.roomId, merged);
    return merged;
  }

  Map<String, dynamic>? _mergeExtra(
    Map<String, dynamic>? base,
    Map<String, dynamic>? updates,
  ) {
    if ((base == null || base.isEmpty) &&
        (updates == null || updates.isEmpty)) {
      return base ?? updates;
    }

    final result = <String, dynamic>{};
    if (base != null && base.isNotEmpty) {
      base.forEach((key, value) {
        result[key] = value;
      });
    }

    if (updates != null && updates.isNotEmpty) {
      updates.forEach((key, value) {
        if (value == null) {
          result.remove(key);
          return;
        }

        if (value is Map<String, dynamic> || value is Map) {
          final current = result[key];
          final normalizedCurrent = current is Map<String, dynamic>
              ? current
              : current is Map
              ? _normalizeMap(current)
              : <String, dynamic>{};
          final normalizedValue = value is Map<String, dynamic>
              ? value
              : _normalizeMap(value as Map<dynamic, dynamic>);
          final mergedMap = _mergeExtra(normalizedCurrent, normalizedValue);
          if (mergedMap == null || mergedMap.isEmpty) {
            result.remove(key);
          } else {
            result[key] = mergedMap;
          }
          return;
        }

        result[key] = value;
      });
    }

    return result.isEmpty ? null : result;
  }

  Map<String, dynamic> _normalizeMap(Map<dynamic, dynamic> raw) {
    final normalized = <String, dynamic>{};
    raw.forEach((key, value) {
      normalized[key.toString()] = value;
    });
    return normalized;
  }

  MessageStatus _currentMessageStatus(String roomId, String messageId) {
    final messages = _messagesByRoom[roomId];
    if (messages == null || messages.isEmpty) {
      return MessageStatus.sent;
    }
    final index = messages.indexWhere((m) => m.id == messageId);
    if (index == -1) {
      return MessageStatus.sent;
    }
    return messages[index].status;
  }

  void _applyPinnedState(String roomId, Message message) {
    final list = List<String>.from(
      _pinnedMessageIds[roomId] ?? const <String>[],
    );
    if (message.isPinned) {
      if (!list.contains(message.id)) {
        list.add(message.id);
      }
    } else {
      list.removeWhere((id) => id == message.id);
    }
    if (list.isEmpty) {
      _pinnedMessageIds.remove(roomId);
    } else {
      _pinnedMessageIds[roomId] = list;
    }
  }

  List<Message> _mergeMessageLists(
    List<Message> existing,
    List<Message> incoming,
  ) {
    final map = <String, Message>{};
    for (final message in existing) {
      map[message.id] = message;
    }
    for (final message in incoming) {
      final prev = map[message.id];
      if (prev != null) {
        map[message.id] = _mergeMessage(prev, message);
      } else {
        map[message.id] = message;
      }
    }

    final merged = map.values.toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return merged;
  }

  void _refreshPinnedCache(String roomId) {
    final messages = _messagesByRoom[roomId];
    if (messages == null || messages.isEmpty) {
      _pinnedMessageIds.remove(roomId);
      return;
    }

    final pinnedIds = <String>[];
    for (final message in messages) {
      if (message.isPinned) {
        pinnedIds.add(message.id);
      }
    }

    if (pinnedIds.isEmpty) {
      _pinnedMessageIds.remove(roomId);
    } else {
      _pinnedMessageIds[roomId] = pinnedIds;
    }
  }

  ForwardInfo? _parseForwardInfo(Map<String, dynamic>? extra) {
    if (extra == null || extra.isEmpty) {
      return null;
    }
    final raw = extra['forward'] ?? extra['forward_info'];
    if (raw == null) return null;
    if (raw is ForwardInfo) return raw;
    if (raw is Map<String, dynamic>) {
      return ForwardInfo.fromCacheJson(raw);
    }
    if (raw is Map) {
      return ForwardInfo.fromCacheJson(_normalizeMap(raw));
    }
    return null;
  }

  bool _parseIsDeleted(Map<String, dynamic>? extra) {
    if (extra == null || extra.isEmpty) {
      return false;
    }
    final raw = extra['is_deleted'] ?? extra['deleted'] ?? extra['deleted_at'];
    if (raw is bool) return raw;
    if (raw is num) return raw != 0;
    if (raw is String) {
      final lowered = raw.trim().toLowerCase();
      return lowered == 'true' || lowered == '1';
    }
    return false;
  }

  DateTime? _parsePinnedAt(Map<String, dynamic>? extra) {
    if (extra == null || extra.isEmpty) {
      return null;
    }
    final raw = extra['pinned_at'] ?? extra['pinnedAt'];
    if (raw == null) return null;
    if (raw is DateTime) return raw;
    if (raw is String && raw.isNotEmpty) {
      return DateTime.tryParse(raw);
    }
    return null;
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
        unawaited(_persistMessages(updated.roomId));
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

  void _validateDraft(
    String? text,
    List<MessageAttachmentDraft> attachments,
    UploadPolicy policy,
  ) {
    if (attachments.isEmpty) {
      return;
    }
    final hasAudio = attachments.any(
      (draft) => draft.type == MessagePartType.audio,
    );

    if (hasAudio && policy.audioOnly.enabled) {
      if (policy.audioOnly.forceSingleAttachment && attachments.length > 1) {
        throw StateError('语音消息暂不支持与其他附件混合发送');
      }
      if (!policy.audioOnly.allowText && text != null && text.isNotEmpty) {
        throw StateError('语音消息暂不支持附带文本');
      }
    }

    _enforceAttachmentPolicy(attachments, policy);
  }

  void _enforceAttachmentPolicy(
    List<MessageAttachmentDraft> attachments,
    UploadPolicy policy,
  ) {
    if (attachments.length > policy.maxAttachmentsPerMessage) {
      throw StateError('单条消息最多可发送 ${policy.maxAttachmentsPerMessage} 个附件');
    }

    for (final draft in attachments) {
      final file = draft.file;
      final size = file.lengthSync();
      final partTypeKey = _policyPartTypeKey(draft.type);
      final perFileLimitBytes = policy.maxSizeBytesForPartType(partTypeKey);
      if (perFileLimitBytes != null && size > perFileLimitBytes) {
        final mb = policy.maxSizeMbByPartType[partTypeKey] ?? 0;
        throw StateError(
          '附件 "${draft.displayName ?? file.path}" 超过 $mb MB 限制',
        );
      }

      final mime = draft.mime ?? lookupMimeType(file.path) ?? '';
      if (!_isMimeAllowed(draft.type, mime, policy)) {
        throw StateError('暂不支持发送该文件类型 ($mime)');
      }
    }
  }

  String _policyPartTypeKey(MessagePartType type) {
    switch (type) {
      case MessagePartType.image:
        return 'image';
      case MessagePartType.video:
        return 'video';
      case MessagePartType.audio:
        return 'audio';
      case MessagePartType.file:
      case MessagePartType.text:
        return 'file';
    }
  }

  bool _isMimeAllowed(MessagePartType type, String mime, UploadPolicy policy) {
    final normalized = mime.toLowerCase();
    switch (type) {
      case MessagePartType.image:
        return policy.isMimeAllowedForPartType('image', normalized);
      case MessagePartType.video:
        return policy.isMimeAllowedForPartType('video', normalized);
      case MessagePartType.audio:
        return policy.isMimeAllowedForPartType('audio', normalized);
      case MessagePartType.file:
      case MessagePartType.text:
        return policy.isMimeAllowedForPartType('file', normalized);
    }
  }

  Future<List<_AttachmentUploadPlan>> _prepareAttachmentUploads({
    required String roomId,
    required String messageId,
    required List<MessageAttachmentDraft> attachments,
    required String token,
    required UploadPolicy policy,
  }) async {
    final plans = <_AttachmentUploadPlan>[];
    for (var index = 0; index < attachments.length; index++) {
      final draft = attachments[index];
      if (draft.hasExistingKey) {
        throw StateError('暂不支持复用已存在的附件 key');
      }

      final contentType =
          draft.mime ??
          lookupMimeType(draft.file.path) ??
          'application/octet-stream';
      if (!_isMimeAllowed(draft.type, contentType, policy)) {
        throw StateError('暂不支持发送该文件类型 ($contentType)');
      }
      final size = await draft.file.length();
      final partTypeKey = _policyPartTypeKey(draft.type);
      final perFileLimitBytes = policy.maxSizeBytesForPartType(partTypeKey);
      if (perFileLimitBytes != null && size > perFileLimitBytes) {
        final mb = policy.maxSizeMbByPartType[partTypeKey] ?? 0;
        throw StateError(
          '附件 "${draft.displayName ?? draft.file.path}" 超过 $mb MB 限制',
        );
      }

      final fileName = draft.displayName ?? p.basename(draft.file.path);

      // 计算文件哈希（用于后端去重）
      FileHashResult? hashResult;
      try {
        final bytes = await draft.file.readAsBytes();
        hashResult = await computeFileHash(bytes);
      } catch (_) {
        hashResult = const FileHashResult(hashValue: null, hashAlg: null);
      }

      final hashValue = hashResult?.hashValue;
      final hashAlg = hashResult?.hashAlg;

      final bool shouldUseMultipart = size > _multipartThresholdBytes;
      final _AttachmentSignatureResult? signatureResult;
      final _AttachmentMultipartInitiateResult? multipartResult;

      if (shouldUseMultipart) {
        multipartResult = await _requestAttachmentMultipartInitiate(
          roomId: roomId,
          type: draft.type,
          fileName: fileName,
          contentType: contentType,
          fileSize: size,
          hashValue: hashValue,
          hashAlg: hashAlg,
          token: token,
        );
        signatureResult = null;
      } else {
        signatureResult = await _requestAttachmentSignature(
          roomId: roomId,
          type: draft.type,
          fileName: fileName,
          contentType: contentType,
          fileSize: size,
          hashValue: hashValue,
          hashAlg: hashAlg,
          token: token,
        );
        multipartResult = null;
      }

      plans.add(
        _AttachmentUploadPlan(
          index: index,
          messageId: messageId,
          roomId: roomId,
          draft: draft,
          key: signatureResult?.key ?? multipartResult!.key,
          signature: signatureResult?.signature,
          multipartSessionId: multipartResult?.sessionId,
          multipartPartSize: multipartResult?.partSize,
          multipartTotalParts: multipartResult?.totalParts,
          hashValue: hashValue,
          hashAlg: hashAlg,
          contentType: contentType,
          file: draft.file,
          size: size,
          width: draft.width,
          height: draft.height,
          durationMs: draft.durationMs,
        ),
      );
    }
    return plans;
  }

  Message _buildPendingMessage({
    required String tempId,
    required String roomId,
    required String senderId,
    required String senderUsername,
    required String senderName,
    required String? senderAvatar,
    required String? text,
    required List<MessageAttachmentDraft> attachments,
    required List<_AttachmentUploadPlan> plans,
    Message? quotedMessage,
  }) {
    final timestamp = DateTime.now();
    final messageType = _inferDraftMessageType(text, attachments);
    final summary = _buildDraftSummary(text, attachments);

    final planMap = {for (final plan in plans) plan.index: plan};

    final parts = <MessagePart>[];
    var position = 0;
    if (text != null && text.isNotEmpty) {
      parts.add(
        MessagePart(
          position: position++,
          type: MessagePartType.text,
          text: text,
        ),
      );
    }

    for (var index = 0; index < attachments.length; index++) {
      final draft = attachments[index];
      final plan = planMap[index];
      if (plan == null) continue;
      parts.add(
        MessagePart(
          position: position++,
          type: draft.type,
          attachment: MessageAttachment(
            key: plan.key,
            name: draft.displayName ?? p.basename(draft.file.path),
            mime: plan.contentType,
            size: plan.size,
            width: draft.width,
            height: draft.height,
            durationMs: draft.durationMs,
            localPath: draft.file.path,
            uploadProgress: 0,
          ),
        ),
      );
    }

    return Message(
      id: tempId,
      roomId: roomId,
      senderId: senderId,
      senderUsername: senderUsername,
      senderName: senderName,
      senderAvatar: senderAvatar,
      content: summary,
      type: messageType,
      status: MessageStatus.sending,
      timestamp: timestamp,
      isSelf: true,
      quotedMessage: quotedMessage != null
          ? QuotedMessage.fromMessage(quotedMessage)
          : null,
      parts: parts,
    );
  }

  String _buildDraftSummary(
    String? text,
    List<MessageAttachmentDraft> attachments,
  ) {
    final segments = <String>[];
    if (text != null && text.isNotEmpty) {
      segments.add(text);
    }
    for (final attachment in attachments) {
      switch (attachment.type) {
        case MessagePartType.image:
          segments.add('[图片]');
          break;
        case MessagePartType.video:
          segments.add('[视频]');
          break;
        case MessagePartType.audio:
          segments.add('[语音]');
          break;
        case MessagePartType.file:
          segments.add('[文件]');
          break;
        case MessagePartType.text:
          break;
      }
    }
    if (segments.isEmpty) {
      return '[消息]';
    }
    return segments.join(' ');
  }

  Future<int> _calculateAttachmentSize(
    List<MessageAttachmentDraft> attachments,
  ) async {
    var total = 0;
    for (final draft in attachments) {
      total += await draft.file.length();
    }
    return total;
  }

  MessageType _inferDraftMessageType(
    String? text,
    List<MessageAttachmentDraft> attachments,
  ) {
    final hasText = text != null && text.isNotEmpty;
    if (attachments.isEmpty) {
      return MessageType.text;
    }

    if (attachments.length == 1) {
      final attachment = attachments.first;
      switch (attachment.type) {
        case MessagePartType.image:
          return hasText ? MessageType.mixed : MessageType.image;
        case MessagePartType.video:
          return hasText ? MessageType.mixed : MessageType.video;
        case MessagePartType.audio:
          return MessageType.audio;
        case MessagePartType.file:
          return hasText ? MessageType.mixed : MessageType.file;
        case MessagePartType.text:
          return MessageType.text;
      }
    }

    final uniqueTypes = attachments.map((a) => a.type).toSet();
    if (uniqueTypes.length == 1 && !hasText) {
      final type = uniqueTypes.first;
      switch (type) {
        case MessagePartType.image:
          return MessageType.image;
        case MessagePartType.video:
          return MessageType.video;
        case MessagePartType.audio:
          return MessageType.audio;
        case MessagePartType.file:
          return MessageType.file;
        case MessagePartType.text:
          return MessageType.text;
      }
    }
    return MessageType.mixed;
  }

  List<Map<String, dynamic>> _buildPartsPayload({
    required String? text,
    required List<MessageAttachmentDraft> attachments,
    required List<_AttachmentUploadPlan> plans,
  }) {
    if (plans.isEmpty) {
      return const [];
    }
    final entries = plans.toList()..sort((a, b) => a.index.compareTo(b.index));
    final payload = <Map<String, dynamic>>[];
    for (final plan in entries) {
      final draft = plan.draft;
      payload.add({
        'type': _mapPartTypeName(draft.type),
        'key': plan.key,
        'name': draft.displayName ?? p.basename(draft.file.path),
        'mime': plan.contentType,
        'size': plan.size,
        if (draft.width != null) 'width': draft.width,
        if (draft.height != null) 'height': draft.height,
        if (draft.durationMs != null) 'duration_ms': draft.durationMs,
      });
    }
    return payload;
  }

  Future<void> _executeAttachmentUpload(_AttachmentUploadPlan plan) async {
    // 分片上传：使用 COS Multipart Upload（> 5MB）
    if (plan.multipartSessionId != null) {
      await _executeAttachmentMultipartUpload(plan);

      await _commitAttachmentUpload(
        roomId: plan.roomId,
        key: plan.key,
        fileSize: plan.size,
        hashValue: plan.hashValue,
        hashAlg: plan.hashAlg,
      );

      await _updateAttachmentUploadProgress(
        roomId: plan.roomId,
        messageId: plan.messageId,
        key: plan.key,
        progress: null,
      );

      final savedPath = await AttachmentCache.instance.saveFile(
        objectKey: plan.key,
        source: plan.file,
      );

      await _updateAttachmentLocalPath(
        roomId: plan.roomId,
        messageId: plan.messageId,
        key: plan.key,
        localPath: savedPath,
      );
      return;
    }

    // 若命中哈希去重（后端未返回签名/会话），无需上传，仅更新本地状态
    if (plan.signature == null) {
      final savedPath = await AttachmentCache.instance.saveFile(
        objectKey: plan.key,
        source: plan.file,
      );

      await _updateAttachmentLocalPath(
        roomId: plan.roomId,
        messageId: plan.messageId,
        key: plan.key,
        localPath: savedPath,
      );
      await _updateAttachmentUploadProgress(
        roomId: plan.roomId,
        messageId: plan.messageId,
        key: plan.key,
        progress: null,
      );
      return;
    }

    final sig = plan.signature!;
    final request = http.StreamedRequest(
      sig.method,
      Uri.parse(sig.url),
    );
    sig.applyHeaders(request, defaultContentType: plan.contentType);

    final total = plan.size.toDouble().clamp(1, double.infinity);
    double uploaded = 0;

    // 重要：必须先调用 send()（不 await），然后再写入数据到 sink
    // 否则当 sink 缓冲区满时会导致死锁
    final responseFuture = request.send();

    await for (final chunk in plan.file.openRead()) {
      request.sink.add(chunk);
      uploaded += chunk.length;
      final progress = (uploaded / total).clamp(0.0, 1.0);
      await _updateAttachmentUploadProgress(
        roomId: plan.roomId,
        messageId: plan.messageId,
        key: plan.key,
        progress: progress.toDouble(),
      );
    }
    await request.sink.close();

    // 现在等待响应
    final response = await responseFuture;
    final responseBody = await response.stream.bytesToString();

    if (!_isSuccessStatus(response.statusCode)) {
      final message = responseBody.isNotEmpty
          ? responseBody
          : '状态码 ${response.statusCode}';
      throw Exception('上传附件失败: $message');
    }

    await _commitAttachmentUpload(
      roomId: plan.roomId,
      key: plan.key,
      fileSize: plan.size,
      hashValue: plan.hashValue,
      hashAlg: plan.hashAlg,
    );

    await _updateAttachmentUploadProgress(
      roomId: plan.roomId,
      messageId: plan.messageId,
      key: plan.key,
      progress: null,
    );

    final savedPath = await AttachmentCache.instance.saveFile(
      objectKey: plan.key,
      source: plan.file,
    );

    await _updateAttachmentLocalPath(
      roomId: plan.roomId,
      messageId: plan.messageId,
      key: plan.key,
      localPath: savedPath,
    );
  }

  Future<void> _executeAttachmentMultipartUpload(_AttachmentUploadPlan plan) async {
    final session = await _tokenStorage.readSession();
    if (session == null) {
      throw Exception('User not authenticated');
    }

    final sessionId = plan.multipartSessionId;
    final partSize = plan.multipartPartSize;
    final totalParts = plan.multipartTotalParts;
    if (sessionId == null || sessionId.isEmpty || partSize == null || totalParts == null) {
      throw Exception('分片上传会话信息不完整');
    }

    final total = plan.size.toDouble().clamp(1, double.infinity);
    double uploaded = 0;
    final parts = <_MultipartCompletedPart>[];

    try {
      for (var partNumber = 1; partNumber <= totalParts; partNumber++) {
        final signature = await _requestMultipartPartSignature(
          sessionId: sessionId,
          partNumber: partNumber,
          token: session.token,
        );

        final start = (partNumber - 1) * partSize;
        final endExclusive = (start + partSize) <= plan.size
            ? (start + partSize)
            : plan.size;
        final request = http.StreamedRequest(
          signature.method,
          Uri.parse(signature.url),
        );
        signature.applyHeaders(request, defaultContentType: plan.contentType);

        final responseFuture = request.send();

        await for (final chunk in plan.file.openRead(start, endExclusive)) {
          request.sink.add(chunk);
          uploaded += chunk.length;
          final progress = (uploaded / total).clamp(0.0, 1.0);
          await _updateAttachmentUploadProgress(
            roomId: plan.roomId,
            messageId: plan.messageId,
            key: plan.key,
            progress: progress.toDouble(),
          );
        }
        await request.sink.close();

        final response = await responseFuture;
        final responseBody = await response.stream.bytesToString();
        if (!_isSuccessStatus(response.statusCode)) {
          final message = responseBody.isNotEmpty
              ? responseBody
              : '状态码 ${response.statusCode}';
          throw Exception('上传分片失败（part $partNumber）: $message');
        }

        final etagRaw = response.headers['etag'];
        if (etagRaw == null || etagRaw.isEmpty) {
          throw Exception('上传分片成功但未获取到 ETag（part $partNumber）');
        }
        final etag = etagRaw.replaceAll('"', '').trim();

        await _commitMultipartPart(
          sessionId: sessionId,
          partNumber: partNumber,
          etag: etag,
          token: session.token,
        );

        parts.add(_MultipartCompletedPart(partNumber: partNumber, etag: etag));
      }

      await _completeMultipartUpload(
        sessionId: sessionId,
        parts: parts,
        token: session.token,
      );
    } catch (error) {
      await _abortMultipartUpload(sessionId: sessionId, token: session.token);
      rethrow;
    }
  }

  Future<void> _updateAttachmentUploadProgress({
    required String roomId,
    required String messageId,
    required String key,
    double? progress,
  }) async {
    // 进度节流：对于 0.0 到 1.0 之间的进度，每 100ms 最多通知一次
    if (progress != null && progress > 0 && progress < 1.0) {
      final throttleKey = '$roomId:$messageId:$key';
      final now = DateTime.now().millisecondsSinceEpoch;
      final lastUpdate = _progressUpdateThrottle[throttleKey] ?? 0;
      if (now - lastUpdate < 100) {
        // 更新数据但不立刻通知监听者（除非是 0 或 1）
        _doUpdateProgressValue(roomId, messageId, key, progress,
            shouldNotify: false);
        return;
      }
      _progressUpdateThrottle[throttleKey] = now;
    } else if (progress == null || progress >= 1.0 || progress <= 0) {
      // 结束或开始时移除节流记录
      _progressUpdateThrottle.remove('$roomId:$messageId:$key');
    }

    _doUpdateProgressValue(roomId, messageId, key, progress, shouldNotify: true);
  }

  void _doUpdateProgressValue(
    String roomId,
    String messageId,
    String key,
    double? progress, {
    required bool shouldNotify,
  }) {
    final messages = _messagesByRoom[roomId];
    if (messages == null) return;

    bool changed = false;
    for (var i = 0; i < messages.length; i++) {
      final message = messages[i];
      if (message.id != messageId) continue;

      final updatedParts = <MessagePart>[];
      for (final part in message.parts) {
        final attachment = part.attachment;
        if (attachment == null || attachment.key != key) {
          updatedParts.add(part);
          continue;
        }
        changed = true;
        updatedParts.add(
          part.copyWith(
            attachment: attachment.copyWith(uploadProgress: progress),
          ),
        );
      }

      if (changed) {
        final updatedMessage = message.copyWith(parts: updatedParts);
        messages[i] = updatedMessage;
        if (_pendingMessages.containsKey(messageId)) {
          _pendingMessages[messageId] = _pendingMessages[messageId]!.copyWith(
            parts: updatedParts,
          );
        }
        if (shouldNotify) {
          notifyListeners();
        }
        unawaited(_persistMessages(roomId));
      }
      break;
    }
  }

  Future<void> _updateAttachmentLocalPath({
    required String roomId,
    required String messageId,
    required String key,
    required String localPath,
  }) async {
    final messages = _messagesByRoom[roomId];
    if (messages == null) return;

    var changed = false;
    for (var i = 0; i < messages.length; i++) {
      final message = messages[i];
      if (message.id != messageId) continue;

      final updatedParts = <MessagePart>[];
      for (final part in message.parts) {
        final attachment = part.attachment;
        if (attachment == null || attachment.key != key) {
          updatedParts.add(part);
          continue;
        }
        if (attachment.localPath == localPath) {
          updatedParts.add(part);
          continue;
        }
        changed = true;
        updatedParts.add(
          part.copyWith(
            attachment: attachment.copyWith(
              localPath: localPath,
              uploadProgress: null,
            ),
          ),
        );
      }

      if (changed) {
        final updatedMessage = message.copyWith(parts: updatedParts);
        messages[i] = updatedMessage;
        if (_pendingMessages.containsKey(messageId)) {
          _pendingMessages[messageId] = _pendingMessages[messageId]!.copyWith(
            parts: updatedParts,
          );
        }
        notifyListeners();
        unawaited(_persistMessages(roomId));

        // 广播附件路径更新事件
        _attachmentPathController.add(AttachmentPathUpdate(
          messageId: messageId,
          attachmentKey: key,
          localPath: localPath,
        ));
      }
      break;
    }
  }

  Future<_AttachmentSignatureResult> _requestAttachmentSignature({
    required String roomId,
    required MessagePartType type,
    required String fileName,
    required String contentType,
    required int fileSize,
    required String? hashValue,
    required int? hashAlg,
    required String token,
  }) async {
    final uri = Uri.parse(
      '${AppConfig.apiBaseUrl}/rooms/$roomId/messages/attachments/signature',
    );
    final response = await http.post(
      uri,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(<String, dynamic>{
        'part_type': _mapPartTypeName(type),
        'filename': fileName,
        'content_type': contentType,
        'file_size': fileSize,
        if (hashValue != null && hashValue.isNotEmpty) 'hash_value': hashValue,
        if (hashAlg != null) 'hash_alg': hashAlg,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('获取附件上传签名失败: ${response.body}');
    }

    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    final success = payload['success'] as bool? ?? false;
    if (!success) {
      final message = payload['message'] as String? ?? '未知错误';
      throw Exception('获取附件上传签名失败: $message');
    }

    final key = payload['key'] as String?;
    if (key == null || key.isEmpty) {
      throw Exception('上传签名响应不包含有效的 key');
    }

    final rawSignature = payload['signature'];
    DirectUploadSignature? signature;
    if (rawSignature is Map<String, dynamic>) {
      try {
        signature = DirectUploadSignature.fromJson(rawSignature);
      } catch (_) {
        signature = null;
      }
    }

    return _AttachmentSignatureResult(
      key: key,
      signature: signature,
    );
  }

  Future<_AttachmentMultipartInitiateResult> _requestAttachmentMultipartInitiate({
    required String roomId,
    required MessagePartType type,
    required String fileName,
    required String contentType,
    required int fileSize,
    required String? hashValue,
    required int? hashAlg,
    required String token,
  }) async {
    final uri = Uri.parse(
      '${AppConfig.apiBaseUrl}/rooms/$roomId/messages/attachments/multipart/initiate',
    );
    final response = await http.post(
      uri,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(<String, dynamic>{
        'part_type': _mapPartTypeName(type),
        'filename': fileName,
        'content_type': contentType,
        'file_size': fileSize,
        if (hashValue != null && hashValue.isNotEmpty) 'hash_value': hashValue,
        if (hashAlg != null) 'hash_alg': hashAlg,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('初始化附件分片上传失败: ${response.body}');
    }

    int? parseInt(dynamic value) {
      if (value is int) return value;
      if (value is num) return value.toInt();
      if (value is String) return int.tryParse(value);
      return null;
    }

    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    final success = payload['success'] as bool? ?? false;
    if (!success) {
      final message = payload['message'] as String? ?? '未知错误';
      throw Exception('初始化附件分片上传失败: $message');
    }

    final key = payload['key'] as String?;
    if (key == null || key.isEmpty) {
      throw Exception('分片上传初始化响应不包含有效的 key');
    }

    final sessionId = payload['session_id'] as String?;
    final partSize = parseInt(payload['part_size']);
    final totalParts = parseInt(payload['total_parts']);

    return _AttachmentMultipartInitiateResult(
      key: key,
      sessionId: sessionId,
      partSize: partSize,
      totalParts: totalParts,
    );
  }

  Future<DirectUploadSignature> _requestMultipartPartSignature({
    required String sessionId,
    required int partNumber,
    required String token,
  }) async {
    final uri = Uri.parse(
      '${AppConfig.apiBaseUrl}/uploads/multipart/sessions/$sessionId/parts/signature',
    );
    final response = await http.post(
      uri,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(<String, dynamic>{'part_number': partNumber}),
    );

    if (response.statusCode != 200) {
      throw Exception('获取分片上传签名失败: ${response.body}');
    }

    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    final success = payload['success'] as bool? ?? false;
    if (!success) {
      final message = payload['message'] as String? ?? '未知错误';
      throw Exception('获取分片上传签名失败: $message');
    }

    final rawSignature = payload['signature'];
    if (rawSignature is! Map<String, dynamic>) {
      throw Exception('分片上传签名响应不完整');
    }
    return DirectUploadSignature.fromJson(rawSignature);
  }

  Future<void> _commitMultipartPart({
    required String sessionId,
    required int partNumber,
    required String etag,
    required String token,
  }) async {
    final uri = Uri.parse(
      '${AppConfig.apiBaseUrl}/uploads/multipart/sessions/$sessionId/parts/commit',
    );
    final response = await http.post(
      uri,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(<String, dynamic>{
        'part_number': partNumber,
        'etag': etag,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('提交分片进度失败: ${response.body}');
    }

    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    final success = payload['success'] as bool? ?? false;
    if (!success) {
      final message = payload['message'] as String? ?? '未知错误';
      throw Exception('提交分片进度失败: $message');
    }
  }

  Future<void> _completeMultipartUpload({
    required String sessionId,
    required List<_MultipartCompletedPart> parts,
    required String token,
  }) async {
    final uri = Uri.parse(
      '${AppConfig.apiBaseUrl}/uploads/multipart/sessions/$sessionId/complete',
    );
    final response = await http.post(
      uri,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(<String, dynamic>{
        'parts': parts
            .map((part) => {
                  'part_number': part.partNumber,
                  'etag': part.etag,
                })
            .toList(),
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('完成分片上传失败: ${response.body}');
    }

    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    final success = payload['success'] as bool? ?? false;
    if (!success) {
      final message = payload['message'] as String? ?? '未知错误';
      throw Exception('完成分片上传失败: $message');
    }
  }

  Future<void> _abortMultipartUpload({
    required String sessionId,
    required String token,
  }) async {
    try {
      final uri = Uri.parse(
        '${AppConfig.apiBaseUrl}/uploads/multipart/sessions/$sessionId/abort',
      );
      final response = await http.post(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(<String, dynamic>{}),
      );

      if (response.statusCode != 200) {
        return;
      }

      final payload = jsonDecode(response.body) as Map<String, dynamic>;
      final success = payload['success'] as bool? ?? false;
      if (!success) {
        return;
      }
    } catch (_) {
      // ignore
    }
  }

  Future<void> _commitAttachmentUpload({
    required String roomId,
    required String key,
    required int fileSize,
    required String? hashValue,
    required int? hashAlg,
  }) async {
    final session = await _tokenStorage.readSession();
    if (session == null) {
      throw Exception('User not authenticated');
    }

    final uri = Uri.parse(
      '${AppConfig.apiBaseUrl}/rooms/$roomId/messages/attachments/commit',
    );
    final response = await http.post(
      uri,
      headers: {
        'Authorization': 'Bearer ${session.token}',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(<String, dynamic>{
        'key': key,
        'file_size': fileSize,
        if (hashValue != null && hashValue.isNotEmpty) 'hash_value': hashValue,
        if (hashAlg != null) 'hash_alg': hashAlg,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('标记附件上传完成失败: ${response.body}');
    }

    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    final success = payload['success'] as bool? ?? false;
    if (!success) {
      final message = payload['message'] as String? ?? '未知错误';
      throw Exception('标记附件上传完成失败: $message');
    }
  }

  String _mapPartTypeName(MessagePartType type) {
    switch (type) {
      case MessagePartType.text:
        return 'text';
      case MessagePartType.image:
        return 'image';
      case MessagePartType.video:
        return 'video';
      case MessagePartType.audio:
        return 'audio';
      case MessagePartType.file:
        return 'file';
    }
  }

  bool _isSuccessStatus(int status) => status >= 200 && status < 300;

  Future<void> _hydrateAttachmentLocalPaths(Message message) async {
    if (message.parts.isEmpty) {
      return;
    }
    for (final part in message.parts) {
      final attachment = part.attachment;
      if (attachment == null) continue;
      if (attachment.localPath != null && attachment.localPath!.isNotEmpty) {
        final file = File(attachment.localPath!);
        if (await file.exists()) {
          continue;
        }
      }
      final cached = await AttachmentCache.instance.resolve(attachment.key);
      if (cached != null && cached.isNotEmpty) {
        await _updateAttachmentLocalPath(
          roomId: message.roomId,
          messageId: message.id,
          key: attachment.key,
          localPath: cached,
        );
      }
    }
  }

  Future<String?> ensureAttachmentCached({
    required String roomId,
    required Message message,
    required MessagePart part,
    bool forceDownload = false,
  }) async {
    final attachment = part.attachment;
    if (attachment == null) {
      return null;
    }

    final key = attachment.key;

    // 1. 先查内存缓存（最快）
    if (!forceDownload) {
      final memoryCached = AttachmentUrlCache.instance.get(key);
      if (memoryCached != null && memoryCached.isNotEmpty) {
        final memoryFile = File(memoryCached);
        if (await memoryFile.exists()) {
          return memoryCached;
        }
        // 文件不存在，清除内存缓存
        AttachmentUrlCache.instance.remove(key);
      }
    }

    // 2. 检查消息中的 localPath
    if (!forceDownload &&
        attachment.localPath != null &&
        attachment.localPath!.isNotEmpty) {
      final localFile = File(attachment.localPath!);
      if (await localFile.exists()) {
        // 更新内存缓存
        AttachmentUrlCache.instance.set(key, attachment.localPath!);
        return attachment.localPath;
      }
    }

    // 3. 检查文件系统缓存
    final fileCached = await AttachmentCache.instance.resolve(key);
    if (!forceDownload && fileCached != null && fileCached.isNotEmpty) {
      final cachedFile = File(fileCached);
      if (await cachedFile.exists()) {
        // 更新内存缓存
        AttachmentUrlCache.instance.set(key, fileCached);
        // 更新消息中的 localPath
        await _updateAttachmentLocalPath(
          roomId: roomId,
          messageId: message.id,
          key: key,
          localPath: fileCached,
        );
        return fileCached;
      }
    }

    // 4. 检查是否有正在进行的下载（去重）
    if (_pendingDownloads.containsKey(key)) {
      return _pendingDownloads[key];
    }

    // 5. 开始下载
    final session = await _tokenStorage.readSession();
    if (session == null) {
      throw Exception('User not authenticated');
    }

    final downloadFuture = _downloadAttachment(
      roomId: roomId,
      messageId: message.id,
      attachment: attachment,
      token: session.token,
    );
    _pendingDownloads[key] = downloadFuture;

    try {
      final savedPath = await downloadFuture;
      // 更新内存缓存
      AttachmentUrlCache.instance.set(key, savedPath);
      return savedPath;
    } finally {
      _pendingDownloads.remove(key);
    }
  }

  Future<String> _downloadAttachment({
    required String roomId,
    required String messageId,
    required MessageAttachment attachment,
    required String token,
  }) async {
    final url = await _fetchAttachmentDownloadUrl(
      roomId: roomId,
      key: attachment.key,
      token: token,
    );

    final response = await http.get(Uri.parse(url));
    if (!_isSuccessStatus(response.statusCode)) {
      throw Exception('下载附件失败: HTTP ${response.statusCode}');
    }

    final savedPath = await AttachmentCache.instance.saveBytes(
      objectKey: attachment.key,
      bytes: response.bodyBytes,
      suggestedExtension: p.extension(attachment.key),
    );

    await _updateAttachmentLocalPath(
      roomId: roomId,
      messageId: messageId,
      key: attachment.key,
      localPath: savedPath,
    );

    return savedPath;
  }

  Future<String> _fetchAttachmentDownloadUrl({
    required String roomId,
    required String key,
    required String token,
  }) async {
    final uri = Uri.parse(
      '${AppConfig.apiBaseUrl}/rooms/$roomId/messages/attachments/download',
    ).replace(queryParameters: {'key': key});

    final response = await http.get(
      uri,
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode != 200) {
      throw Exception('获取附件下载链接失败: ${response.body}');
    }

    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    final success = payload['success'] as bool? ?? false;
    if (!success) {
      final message = payload['message'] as String? ?? '未知错误';
      throw Exception('获取附件下载链接失败: $message');
    }

    final downloadUrl = payload['download_url'] as String?;
    if (downloadUrl == null || downloadUrl.isEmpty) {
      throw Exception('下载链接为空');
    }
    return downloadUrl;
  }

  // 用于管理重试定时器，防止重复调度
  final Map<String, Timer?> _retryTimers = {};

  /// 安排消息重试 - 持续重试直到成功，间隔 3 秒
  void _scheduleRetry(String messageId) {
    // 如果已有定时器在运行，不重复调度
    if (_retryTimers[messageId]?.isActive == true) {
      return;
    }

    // 检查消息是否仍在待发送队列中
    if (!_pendingMessages.containsKey(messageId)) {
      debugPrint('Message $messageId not in pending queue, skip retry');
      _retryTimers.remove(messageId);
      return;
    }

    _retryTimers[messageId] = Timer(const Duration(seconds: 3), () {
      _retryTimers.remove(messageId);
      _executeRetry(messageId);
    });
  }

  /// 执行重试发送
  Future<void> _executeRetry(String messageId) async {
    // 再次检查消息是否仍在待发送队列中
    if (!_pendingMessages.containsKey(messageId)) {
      debugPrint('Message $messageId already sent or removed, skip retry');
      return;
    }

    final message = _pendingMessages[messageId];
    if (message == null) {
      return;
    }

    // 检查消息状态，只重试失败或发送中的消息
    final currentStatus = message.status;
    if (currentStatus != MessageStatus.failed &&
        currentStatus != MessageStatus.sending) {
      debugPrint('Message $messageId status is $currentStatus, skip retry');
      return;
    }

    debugPrint('Retrying message: $messageId');
    _updateMessageStatus(messageId, MessageStatus.sending);

    try {
      final session = await _tokenStorage.readSession();
      if (session == null) {
        throw Exception('User not authenticated');
      }

      final payload = _pendingPayloads[messageId];
      // 使用 payload 中的内容，不回退到 message.content（可能是占位符如 [语音]）
      final response = await _sendMessageAPI(
        payload?.roomId ?? message.roomId,
        content: payload?.content,
        parts: payload?.parts ?? const <Map<String, dynamic>>[],
        quotedMessageId: payload?.quotedMessageId ?? message.quotedMessage?.id,
      );

      final updated = _messageFromResponse(
        response,
        session.user.id,
        overrideStatus: MessageStatus.sent,
      );
      _replaceMessage(messageId, updated);
      _pendingMessages.remove(messageId);
      _pendingPayloads.remove(messageId);
      debugPrint('Message $messageId sent successfully after retry');
      unawaited(_hydrateAttachmentLocalPaths(updated));
    } catch (e) {
      debugPrint('Retry failed for message $messageId: $e');
      // 保持 sending 状态，继续调度下一次重试
      _scheduleRetry(messageId);
    }
  }

  /// 取消消息重试
  void _cancelRetry(String messageId) {
    _retryTimers[messageId]?.cancel();
    _retryTimers.remove(messageId);
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

      // 注意：本地消息状态的更新应该由 WebSocket 的 handleReadReceipt 来处理
      // 因为已读回执影响的是"自己发送的消息"的状态，而不是"接收到的消息"的状态
      // 服务器会广播已读回执事件，然后 handleReadReceipt 会更新自己发送的消息为已读状态

      markChatAsRead(roomId);
    } catch (e) {
      debugPrint('Failed to mark messages as read: $e');
    }
  }

  /// 清除房间消息
  void clearRoomMessages(String roomId) {
    _messagesByRoom.remove(roomId);
    _clearMessageReadersForRoom(roomId);
    _pinnedMessageIds.remove(roomId);
    unawaited(_messageStorage.clear(roomId));
    notifyListeners();
  }

  Future<void> handleGroupDissolved(String roomId) async {
    if (roomId.isEmpty) return;

    final existed = _chats.any((chat) => chat.roomId == roomId);
    _chats.removeWhere((chat) => chat.roomId == roomId);
    _messagesByRoom.remove(roomId);
    _pendingMessages.remove(roomId);
    _pendingPayloads.remove(roomId);
    _clearMessageReadersForRoom(roomId);
    _roomMemberCountCache.remove(roomId);
    _pinnedMessageIds.remove(roomId);

    _syncWebSocketSubscriptions();
    notifyListeners();

    if (existed) {
      unawaited(_messageStorage.clear(roomId));
    }
  }

  Future<void> handleGroupOwnerTransferred(
    String roomId,
    String newOwnerId,
  ) async {
    final index = _chats.indexWhere((chat) => chat.roomId == roomId);
    if (index < 0) return;

    final chat = _chats[index];
    final extras = <String, dynamic>{
      if (chat.extra != null) ...chat.extra!,
      'owner_id': newOwnerId,
    };

    try {
      final session = await _tokenStorage.readSession();
      final isOwner = session?.user.id == newOwnerId;
      extras['is_owner'] = isOwner;
      extras['isOwner'] = isOwner;
    } catch (_) {
      // ignore
    }

    _chats[index] = chat.copyWith(extra: extras);
    notifyListeners();
  }

  /// 更新群头像
  Future<void> updateRoomAvatar({
    required String roomId,
    required String avatarObjectKey,
    String? localAvatarPath,
  }) async {
    final index = _chats.indexWhere((chat) => chat.roomId == roomId);
    if (index < 0) {
      debugPrint('[MessageService] 未找到 roomId=$roomId 的聊天，无法更新头像');
      return;
    }

    final chat = _chats[index];
    final keyChanged = chat.avatarObjectKey != avatarObjectKey;

    // 如果 key 变化，清理旧缓存
    if (keyChanged) {
      await AvatarCache.instance.clearRoom(roomId);
    }

    // 若未提供本地路径，则尝试拉取并缓存
    var resolvedPath = localAvatarPath;
    if (resolvedPath == null || resolvedPath.isEmpty) {
      final roomAvatarService = RoomAvatarService(tokenStorage: _tokenStorage);
      resolvedPath = await roomAvatarService.loadAndCacheAvatar(
        roomId: roomId,
        avatarObjectKey: avatarObjectKey,
      );
    }

    _chats[index] = chat.copyWith(
      avatarObjectKey: avatarObjectKey,
      localAvatarPath: resolvedPath,
    );

    debugPrint(
      '[MessageService] 已更新 roomId=$roomId 的头像: key=$avatarObjectKey, path=$resolvedPath',
    );
    notifyListeners();
  }

  /// 清除所有数据
  Future<void> clearAll() async {
    // 取消所有重试定时器
    for (final timer in _retryTimers.values) {
      timer?.cancel();
    }
    _retryTimers.clear();

    _messagesByRoom.clear();
    _pendingMessages.clear();
    _pendingPayloads.clear();
    _chats.clear();
    _messageReadersCache.clear();
    _roomMemberCountCache.clear();
    _pinnedMessageIds.clear();
    try {
      WebSocketService.instance.ensureRoomsSubscribed(
        const <String>[],
        pruneMissing: true,
      );
    } catch (_) {
      // 忽略清理期间的异常
    }
    notifyListeners();

    try {
      await _messageStorage.clearAll();
    } catch (e) {
      debugPrint('Failed to clear persisted messages: $e');
    }
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

    // 解析对方用户的头像信息（单聊）
    final friendAvatarObjectKey = _readString(json, const [
      'friend_avatar_object_key',
      'friendAvatarObjectKey',
    ]);

    // 群头像 object key（后端字段名 room_avatar_object_key）
    final roomAvatarObjectKey = _readString(json, const [
      'room_avatar_object_key',
      'roomAvatarObjectKey',
    ]);

    // 兼容早期字段 avatar_object_key / avatarObjectKey
    final legacyAvatarObjectKey = _readString(json, const [
      'avatar_object_key',
      'avatarObjectKey',
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
      'friend_user_id': _readString(json, const [
        'friend_user_id',
        'friendUserId',
      ]),
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

    final isPinned =
        chatType == ChatType.favorite ||
        _readBool(json, const ['is_pinned', 'isPinned']);

    final isMuted =
        _readBool(json, const ['is_muted', 'isMuted']) ||
        _readInt(
              json,
              const ['notification_settings', 'notificationSettings'],
              defaultValue: 0,
            ) ==
            2;

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

    final avatarObjectKey = chatType == ChatType.group
        ? (roomAvatarObjectKey ?? legacyAvatarObjectKey)
        : (friendAvatarObjectKey ?? legacyAvatarObjectKey);

    return Chat(
      id: roomId,
      roomId: roomId,
      name: name,
      avatar: effectiveAvatar,
      avatarObjectKey: avatarObjectKey,
      type: chatType,
      lastMessage: lastMessageText,
      lastMessageTime: lastMessageTime,
      unreadCount: effectiveUnread,
      isPinned: isPinned,
      isMuted: isMuted,
      extra: extra.isEmpty ? null : extra,
    );
  }

  /// 按收藏、置顶与时间排序
  void _sortChats() {
    _chats.sort((a, b) {
      // 收藏夹始终排在最前面
      final aIsFavorite = a.type == ChatType.favorite;
      final bIsFavorite = b.type == ChatType.favorite;
      if (aIsFavorite && !bIsFavorite) return -1;
      if (!aIsFavorite && bIsFavorite) return 1;
      // 置顶的排在前面
      if (a.isPinned != b.isPinned) {
        return a.isPinned ? -1 : 1;
      }
      // 按时间排序
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

  static bool _readBool(
    Map<String, dynamic> source,
    List<String> keys, {
    bool defaultValue = false,
  }) {
    for (final key in keys) {
      if (!source.containsKey(key)) continue;
      final value = source[key];
      if (value is bool) return value;
      if (value is num) return value.toInt() != 0;
      if (value is String) {
        final normalized = value.trim().toLowerCase();
        if (normalized == 'true' ||
            normalized == '1' ||
            normalized == 'yes') {
          return true;
        }
        if (normalized == 'false' ||
            normalized == '0' ||
            normalized == 'no') {
          return false;
        }
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
    MessageStatus? overrideStatus,
  }) {
    final type = _mapMessageType(response.messageType);
    final isSelf = response.senderId == currentUserId;
    final quoted = response.quotedMessage == null
        ? null
        : _quotedMessageFromResponse(response.quotedMessage!);
    final computedStatus =
        overrideStatus ??
        response.status ??
        (isSelf ? MessageStatus.sent : MessageStatus.delivered);

    final extra = <String, dynamic>{
      if (response.senderNickname != null &&
          response.senderNickname!.isNotEmpty)
        'sender_nickname': response.senderNickname,
    };
    ForwardInfo? forwardInfo;
    if (response.forwardMessage != null &&
        response.forwardMessage!.messageId.isNotEmpty) {
      forwardInfo = _forwardInfoFromResponse(response.forwardMessage!);
      extra['forward'] = forwardInfo.toCacheJson();
    }

    if (response.isDeleted) {
      extra['is_deleted'] = true;
      if (response.deletedAt != null) {
        extra['deleted_at'] = response.deletedAt!.toIso8601String();
      }
    }

    if (response.isEdited && response.editedAt != null) {
      extra['is_edited'] = true;
      extra['edited_at'] = response.editedAt!.toIso8601String();
    }

    if (response.isPinned) {
      if (response.pinnedAt != null) {
        extra['pinned_at'] = response.pinnedAt!.toIso8601String();
      }
      if (response.pinnedBy != null) {
        extra['pinned_by'] = response.pinnedBy;
      }
    }

    final parts = response.parts
        .map(_messagePartFromResponse)
        .toList(growable: false);

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
      status: computedStatus,
      timestamp: response.createdAt,
      isSelf: isSelf,
      extra: extra.isEmpty ? null : extra,
      quotedMessage: quoted,
      forwardInfo: forwardInfo,
      isDeleted: response.isDeleted,
      isEdited: response.isEdited,
      editedAt: response.editedAt,
      pinnedAt: response.pinnedAt,
      parts: parts,
      reactions: response.reactions,
    );
  }

  Message _messageFromWebSocket(
    WebSocketMessage wsMessage,
    String currentUserId,
  ) {
    final type = _mapMessageType(wsMessage.messageType);
    final isSelf = wsMessage.senderId == currentUserId;
    final status = isSelf ? MessageStatus.sent : MessageStatus.delivered;
    final quoted = wsMessage.quotedMessage == null
        ? null
        : _quotedMessageFromWebSocket(wsMessage.quotedMessage!);

    final extra = wsMessage.extra != null
        ? Map<String, dynamic>.from(wsMessage.extra!)
        : <String, dynamic>{};
    ForwardInfo? forwardInfo;
    if (wsMessage.forwardMessage != null &&
        wsMessage.forwardMessage!.messageId.isNotEmpty) {
      forwardInfo = _forwardInfoFromWebSocket(wsMessage.forwardMessage!);
      extra['forward'] = forwardInfo.toCacheJson();
    } else {
      forwardInfo = _parseForwardInfo(extra);
    }
    final isDeleted = _parseIsDeleted(extra);
    final pinnedAt = _parsePinnedAt(extra);

    final parts = wsMessage.parts
        .map(_messagePartFromWebSocket)
        .toList(growable: false);

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
      extra: extra.isEmpty ? null : extra,
      quotedMessage: quoted,
      forwardInfo: forwardInfo,
      isDeleted: isDeleted,
      pinnedAt: pinnedAt,
      parts: parts,
    );
  }

  MessageType _mapMessageType(String raw) {
    switch (raw.toLowerCase()) {
      case 'image':
        return MessageType.image;
      case 'voice':
      case 'audio':
        return MessageType.audio;
      case 'video':
        return MessageType.video;
      case 'file':
        return MessageType.file;
      case 'system':
        return MessageType.system;
      case 'mixed':
        return MessageType.mixed;
      case 'text':
      default:
        return MessageType.text;
    }
  }

  MessagePart _messagePartFromResponse(MessagePartResponse response) {
    final type = _mapMessagePartType(response.partType);
    MessageAttachment? attachment;
    final attachmentResponse = response.attachment;
    if (attachmentResponse != null && attachmentResponse.key.isNotEmpty) {
      attachment = MessageAttachment(
        key: attachmentResponse.key,
        name: attachmentResponse.name,
        mime: attachmentResponse.mime,
        size: attachmentResponse.size,
        width: attachmentResponse.width,
        height: attachmentResponse.height,
        durationMs: attachmentResponse.durationMs,
        thumbnailKey: attachmentResponse.thumbnailKey,
      );
    }

    return MessagePart(
      position: response.position,
      type: type,
      text: response.text,
      attachment: attachment,
    );
  }

  MessagePart _messagePartFromWebSocket(WebSocketMessagePart part) {
    final type = _mapMessagePartType(part.partType);
    MessageAttachment? attachment;
    final attachmentData = part.attachment;
    if (attachmentData != null && attachmentData.key.isNotEmpty) {
      attachment = MessageAttachment(
        key: attachmentData.key,
        name: attachmentData.name,
        mime: attachmentData.mime,
        size: attachmentData.size,
        width: attachmentData.width,
        height: attachmentData.height,
        durationMs: attachmentData.durationMs,
        thumbnailKey: attachmentData.thumbnailKey,
      );
    }

    return MessagePart(
      position: part.position,
      type: type,
      text: part.text,
      attachment: attachment,
    );
  }

  MessagePartType _mapMessagePartType(String raw) {
    switch (raw.toLowerCase()) {
      case 'image':
        return MessagePartType.image;
      case 'video':
        return MessagePartType.video;
      case 'audio':
      case 'voice':
        return MessagePartType.audio;
      case 'file':
        return MessagePartType.file;
      case 'text':
      default:
        return MessagePartType.text;
    }
  }

  QuotedMessage _quotedMessageFromResponse(QuotedMessageResponse response) {
    final displayName = response.senderNickname?.isNotEmpty == true
        ? response.senderNickname!
        : response.senderUsername;

    // 转换 parts
    final parts = response.parts
        .map(_messagePartFromResponse)
        .toList(growable: false);

    return QuotedMessage(
      id: response.id,
      roomId: response.roomId,
      senderId: response.senderId,
      senderUsername: response.senderUsername,
      senderName: displayName,
      senderAvatar: response.senderAvatarUrl,
      content: response.content,
      type: _mapMessageType(response.messageType),
      createdAt: response.createdAt,
      isDeleted: response.isDeleted,
      parts: parts,
    );
  }

  QuotedMessage _quotedMessageFromWebSocket(WebSocketQuotedMessage quoted) {
    final username = quoted.senderUsername?.isNotEmpty == true
        ? quoted.senderUsername!
        : quoted.senderId;
    final displayName = quoted.senderNickname?.isNotEmpty == true
        ? quoted.senderNickname!
        : username;

    // 转换 parts
    final parts = quoted.parts
        .map(_messagePartFromWebSocket)
        .toList(growable: false);

    return QuotedMessage(
      id: quoted.id,
      roomId: quoted.roomId,
      senderId: quoted.senderId,
      senderUsername: username,
      senderName: displayName,
      senderAvatar: quoted.senderAvatarUrl,
      content: quoted.content,
      type: _mapMessageType(quoted.messageType),
      createdAt: quoted.createdAt,
      isDeleted: quoted.isDeleted,
      parts: parts,
    );
  }

  ForwardInfo _forwardInfoFromResponse(ForwardMessageResponse forward) {
    final originSenderName = forward.senderNickname?.isNotEmpty == true
        ? forward.senderNickname!
        : (forward.senderUsername?.isNotEmpty == true
              ? forward.senderUsername!
              : forward.senderId);

    return ForwardInfo(
      sourceType: ForwardSourceType.unknown,
      sourceId: forward.roomId,
      sourceName: originSenderName,
      sourceAvatar: null,
      originMessageId: forward.messageId,
      originRoomId: forward.roomId,
      originSenderId: forward.senderId,
      originSenderName: originSenderName,
    );
  }

  ForwardInfo _forwardInfoFromWebSocket(WebSocketForwardMessage forward) {
    final originSenderName = forward.senderNickname?.isNotEmpty == true
        ? forward.senderNickname!
        : (forward.senderUsername?.isNotEmpty == true
              ? forward.senderUsername!
              : forward.senderId);

    return ForwardInfo(
      sourceType: ForwardSourceType.unknown,
      sourceId: forward.roomId,
      sourceName: originSenderName,
      sourceAvatar: null,
      originMessageId: forward.messageId,
      originRoomId: forward.roomId,
      originSenderId: forward.senderId,
      originSenderName: originSenderName,
    );
  }

  /// 更新聊天信息（包括头像）
  Future<void> updateChatInfo(String roomId, ChatType chatType) async {
    try {
      final chatIndex = _chats.indexWhere((c) => c.roomId == roomId);
      if (chatIndex < 0) return;

      final chat = _chats[chatIndex];

      if (chatType == ChatType.group) {
        // 更新群聊信息
        final roomService = RoomService(tokenStorage: _tokenStorage);
        final roomDetail = await roomService.fetchRoomDetail(roomId);

        if (roomDetail != null) {
          final newAvatarObjectKey = roomDetail['avatar_object_key'] as String?;
          final oldAvatarObjectKey = chat.avatarObjectKey;
          String? localAvatarPath;

          // 检查头像key是否发生变化
          final avatarKeyChanged = newAvatarObjectKey != oldAvatarObjectKey;

          if (newAvatarObjectKey != null && newAvatarObjectKey.isNotEmpty) {
            final roomAvatarService = RoomAvatarService(
              tokenStorage: _tokenStorage,
            );

            if (avatarKeyChanged) {
              // 如果头像key发生变化，先清除旧缓存
              await AvatarCache.instance.clearRoom(roomId);
              debugPrint(
                'Room $roomId avatar key changed from $oldAvatarObjectKey to $newAvatarObjectKey, clearing cache',
              );
            }

            // 加载新头像（如果key变化了会重新下载）
            localAvatarPath = await roomAvatarService.loadAndCacheAvatar(
              roomId: roomId,
              avatarObjectKey: newAvatarObjectKey,
            );
          } else if (avatarKeyChanged && oldAvatarObjectKey != null) {
            // 如果新的avatarObjectKey为空但旧的不为空，清除缓存
            await AvatarCache.instance.clearRoom(roomId);
            debugPrint('Room $roomId avatar removed, clearing cache');
          }

          // 更新聊天信息
          _chats[chatIndex] = chat.copyWith(
            name: roomDetail['name'] as String? ?? chat.name,
            avatarObjectKey: newAvatarObjectKey,
            localAvatarPath: localAvatarPath,
          );

          notifyListeners();
          unawaited(_chatCache.saveChats(_chats));
        }
        // 如果拉取详情失败，降级为强制刷新会话列表，确保头像/名称同步
        else {
          unawaited(fetchChats(force: true));
        }
      } else if (chatType == ChatType.single) {
        // 更新单聊信息（用户信息）
        final userId =
            chat.extra?['friend_user_id'] as String? ??
            chat.extra?['friendUserId'] as String? ??
            roomId;

        final userService = UserService(tokenStorage: _tokenStorage);
        final userDetail = await userService.fetchUserDetail(userId);

        if (userDetail != null) {
          final newAvatarObjectKey = userDetail['avatar_object_key'] as String?;
          final oldAvatarObjectKey = chat.avatarObjectKey;
          String? localAvatarPath;

          // 检查头像key是否发生变化
          final avatarKeyChanged = newAvatarObjectKey != oldAvatarObjectKey;

          if (newAvatarObjectKey != null && newAvatarObjectKey.isNotEmpty) {
            final userAvatarService = UserAvatarService(
              tokenStorage: _tokenStorage,
            );

            if (avatarKeyChanged) {
              // 如果头像key发生变化，先清除旧缓存
              await AvatarCache.instance.clearUser(userId);
              debugPrint(
                'User $userId avatar key changed from $oldAvatarObjectKey to $newAvatarObjectKey, clearing cache',
              );
            }

            // 加载新头像（如果key变化了会重新下载）
            localAvatarPath = await userAvatarService.loadAndCacheAvatar(
              userId: userId,
              avatarObjectKey: newAvatarObjectKey,
            );
          } else if (avatarKeyChanged && oldAvatarObjectKey != null) {
            // 如果新的avatarObjectKey为空但旧的不为空，清除缓存
            await AvatarCache.instance.clearUser(userId);
            debugPrint('User $userId avatar removed, clearing cache');
          }

          // 更新聊天信息
          _chats[chatIndex] = chat.copyWith(
            avatarObjectKey: newAvatarObjectKey,
            localAvatarPath: localAvatarPath,
          );

          notifyListeners();
          unawaited(_chatCache.saveChats(_chats));
        }
      }
    } catch (e) {
      debugPrint('Failed to update chat info: $e');
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
  final MessageStatus? status;
  final QuotedMessageResponse? quotedMessage;
  final ForwardMessageResponse? forwardMessage;
  final bool isDeleted;
  final DateTime? deletedAt;
  final bool isEdited;
  final DateTime? editedAt;
  final bool isPinned;
  final DateTime? pinnedAt;
  final String? pinnedBy;
  final List<MessagePartResponse> parts;
  final List<MessageReactionSummary>? reactions;

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
    required this.status,
    required this.quotedMessage,
    required this.forwardMessage,
    required this.isDeleted,
    required this.deletedAt,
    this.isEdited = false,
    this.editedAt,
    required this.isPinned,
    required this.pinnedAt,
    required this.pinnedBy,
    required this.parts,
    this.reactions,
  });

  factory MessageResponse.fromJson(Map<String, dynamic> json) {
    QuotedMessageResponse? quoted;
    final quotedRaw = json['quoted_message'];
    if (quotedRaw is Map<String, dynamic>) {
      quoted = QuotedMessageResponse.fromJson(quotedRaw);
    } else if (quotedRaw is Map) {
      final map = <String, dynamic>{};
      quotedRaw.forEach((key, value) {
        map[key.toString()] = value;
      });
      quoted = QuotedMessageResponse.fromJson(map);
    }

    ForwardMessageResponse? forward;
    final forwardRaw = json['forward_message'];
    if (forwardRaw is Map<String, dynamic>) {
      forward = ForwardMessageResponse.fromJson(forwardRaw);
    } else if (forwardRaw is Map) {
      final map = <String, dynamic>{};
      forwardRaw.forEach((key, value) {
        map[key.toString()] = value;
      });
      forward = ForwardMessageResponse.fromJson(map);
    }

    bool parseBool(dynamic value) {
      if (value is bool) return value;
      if (value is num) return value != 0;
      if (value is String) {
        final lowered = value.toLowerCase();
        return lowered == 'true' || lowered == '1';
      }
      return false;
    }

    final parts = <MessagePartResponse>[];
    final rawParts = json['parts'];
    if (rawParts is List) {
      for (final item in rawParts) {
        if (item is Map<String, dynamic>) {
          parts.add(MessagePartResponse.fromJson(item));
        } else if (item is Map) {
          final normalized = <String, dynamic>{};
          item.forEach((key, value) {
            normalized[key.toString()] = value;
          });
          parts.add(MessagePartResponse.fromJson(normalized));
        }
      }
    }

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
      status: _parseMessageStatusFromApi(json['status']),
      quotedMessage: quoted,
      forwardMessage: forward,
      isDeleted: parseBool(json['is_deleted']),
      deletedAt:
          json['deleted_at'] != null && json['deleted_at'].toString().isNotEmpty
          ? DateTime.tryParse(json['deleted_at'].toString())
          : null,
      isEdited: parseBool(json['is_edited']),
      editedAt:
          json['edited_at'] != null && json['edited_at'].toString().isNotEmpty
          ? DateTime.tryParse(json['edited_at'].toString())
          : null,
      isPinned: parseBool(json['is_pinned']),
      pinnedAt:
          json['pinned_at'] != null && json['pinned_at'].toString().isNotEmpty
          ? DateTime.tryParse(json['pinned_at'].toString())
          : null,
      pinnedBy: json['pinned_by']?.toString(),
      parts: parts,
      reactions: _parseReactionsFromJson(json['reactions']),
    );
  }

  static List<MessageReactionSummary>? _parseReactionsFromJson(dynamic raw) {
    if (raw == null) return null;
    if (raw is List) {
      return raw.map((item) {
        if (item is Map<String, dynamic>) {
          return MessageReactionSummary.fromJson(item);
        } else if (item is Map) {
          final normalized = <String, dynamic>{};
          item.forEach((key, value) {
            normalized[key.toString()] = value;
          });
          return MessageReactionSummary.fromJson(normalized);
        }
        return MessageReactionSummary(
          reactionKey: '',
          count: 0,
          userIds: [],
          hasSelf: false,
        );
      }).toList();
    }
    return null;
  }

  String get displayName {
    if (senderNickname != null && senderNickname!.isNotEmpty) {
      return senderNickname!;
    }
    return senderUsername;
  }
}

/// 反应响应
class _ReactionResponse {
  final bool success;
  final String message;
  final List<MessageReactionSummary> summaries;

  _ReactionResponse({
    required this.success,
    required this.message,
    required this.summaries,
  });

  factory _ReactionResponse.fromJson(Map<String, dynamic> json) {
    final summariesRaw = json['summaries'];
    List<MessageReactionSummary> summaries = [];
    if (summariesRaw is List) {
      summaries = summariesRaw.map((item) {
        if (item is Map<String, dynamic>) {
          return MessageReactionSummary.fromJson(item);
        } else if (item is Map) {
          final normalized = <String, dynamic>{};
          item.forEach((key, value) {
            normalized[key.toString()] = value;
          });
          return MessageReactionSummary.fromJson(normalized);
        }
        return MessageReactionSummary(
          reactionKey: '',
          count: 0,
          userIds: [],
          hasSelf: false,
        );
      }).toList();
    }

    return _ReactionResponse(
      success: json['success'] as bool? ?? false,
      message: json['message']?.toString() ?? '',
      summaries: summaries,
    );
  }
}

class MessagePartResponse {
  MessagePartResponse({
    required this.position,
    required this.partType,
    this.text,
    this.attachment,
  });

  final int position;
  final String partType;
  final String? text;
  final MessageAttachmentResponse? attachment;

  factory MessagePartResponse.fromJson(Map<String, dynamic> json) {
    int parseInt(dynamic value, {int defaultValue = 0}) {
      if (value is int) return value;
      if (value is num) return value.toInt();
      if (value is String) {
        final parsed = int.tryParse(value);
        if (parsed != null) return parsed;
      }
      return defaultValue;
    }

    MessageAttachmentResponse? attachment;
    final attachmentRaw = json['attachment'];
    if (attachmentRaw is Map<String, dynamic>) {
      attachment = MessageAttachmentResponse.fromJson(attachmentRaw);
    } else if (attachmentRaw is Map) {
      final normalized = <String, dynamic>{};
      attachmentRaw.forEach((key, value) {
        normalized[key.toString()] = value;
      });
      attachment = MessageAttachmentResponse.fromJson(normalized);
    }

    return MessagePartResponse(
      position: parseInt(json['position']),
      partType:
          json['part_type']?.toString() ?? json['type']?.toString() ?? 'text',
      text: json['text']?.toString(),
      attachment: attachment,
    );
  }
}

class MessageAttachmentResponse {
  MessageAttachmentResponse({
    required this.key,
    this.name,
    this.mime,
    this.size,
    this.width,
    this.height,
    this.durationMs,
    this.thumbnailKey,
  });

  final String key;
  final String? name;
  final String? mime;
  final int? size;
  final int? width;
  final int? height;
  final int? durationMs;
  final String? thumbnailKey;

  factory MessageAttachmentResponse.fromJson(Map<String, dynamic> json) {
    int? parseInt(dynamic value) {
      if (value is int) return value;
      if (value is num) return value.toInt();
      if (value is String) return int.tryParse(value);
      return null;
    }

    return MessageAttachmentResponse(
      key: json['key']?.toString() ?? '',
      name: json['name']?.toString(),
      mime: json['mime']?.toString(),
      size: parseInt(json['size']),
      width: parseInt(json['width']),
      height: parseInt(json['height']),
      durationMs: parseInt(json['duration_ms']),
      thumbnailKey: json['thumbnail_key']?.toString(),
    );
  }
}

class _AttachmentSignatureResult {
  const _AttachmentSignatureResult({
    required this.key,
    required this.signature,
  });

  final String key;
  final DirectUploadSignature? signature;
}

class _AttachmentMultipartInitiateResult {
  const _AttachmentMultipartInitiateResult({
    required this.key,
    required this.sessionId,
    required this.partSize,
    required this.totalParts,
  });

  final String key;
  final String? sessionId;
  final int? partSize;
  final int? totalParts;
}

class _MultipartCompletedPart {
  const _MultipartCompletedPart({
    required this.partNumber,
    required this.etag,
  });

  final int partNumber;
  final String etag;
}

class _AttachmentUploadPlan {
  _AttachmentUploadPlan({
    required this.index,
    required this.messageId,
    required this.roomId,
    required this.draft,
    required this.key,
    required this.signature,
    required this.multipartSessionId,
    required this.multipartPartSize,
    required this.multipartTotalParts,
    required this.hashValue,
    required this.hashAlg,
    required this.contentType,
    required this.file,
    required this.size,
    this.width,
    this.height,
    this.durationMs,
  });

  final int index;
  final String messageId;
  final String roomId;
  final MessageAttachmentDraft draft;
  final String key;
  final DirectUploadSignature? signature;
  final String? multipartSessionId;
  final int? multipartPartSize;
  final int? multipartTotalParts;
  final String? hashValue;
  final int? hashAlg;
  final String contentType;
  final File file;
  final int size;
  final int? width;
  final int? height;
  final int? durationMs;
}

class _PendingMessagePayload {
  _PendingMessagePayload({
    required this.roomId,
    required this.content,
    required this.parts,
    this.quotedMessageId,
  });

  final String roomId;
  final String? content;
  final List<Map<String, dynamic>> parts;
  final String? quotedMessageId;
}

class ForwardMessageResponse {
  ForwardMessageResponse({
    required this.messageId,
    required this.roomId,
    required this.senderId,
    this.senderUsername,
    this.senderNickname,
  });

  final String messageId;
  final String roomId;
  final String senderId;
  final String? senderUsername;
  final String? senderNickname;

  factory ForwardMessageResponse.fromJson(Map<String, dynamic> json) {
    return ForwardMessageResponse(
      messageId: json['message_id']?.toString() ?? '',
      roomId: json['room_id']?.toString() ?? '',
      senderId: json['sender_id']?.toString() ?? '',
      senderUsername: json['sender_username']?.toString(),
      senderNickname: json['sender_nickname']?.toString(),
    );
  }
}

class PinMessageServerResponse {
  PinMessageServerResponse({
    required this.roomId,
    required this.isPinned,
    this.message,
    this.pinnedAt,
    this.pinnedBy,
  });

  final String roomId;
  final bool isPinned;
  final MessageResponse? message;
  final DateTime? pinnedAt;
  final String? pinnedBy;

  factory PinMessageServerResponse.fromJson(Map<String, dynamic> json) {
    MessageResponse? message;
    final messageRaw = json['message'];
    if (messageRaw is Map<String, dynamic>) {
      message = MessageResponse.fromJson(messageRaw);
    } else if (messageRaw is Map) {
      final map = <String, dynamic>{};
      messageRaw.forEach((key, value) {
        map[key.toString()] = value;
      });
      message = MessageResponse.fromJson(map);
    }

    DateTime? pinnedAt;
    final pinnedAtRaw = json['pinned_at']?.toString();
    if (pinnedAtRaw != null && pinnedAtRaw.isNotEmpty) {
      pinnedAt = DateTime.tryParse(pinnedAtRaw);
    }

    bool parseBool(dynamic value) {
      if (value is bool) return value;
      if (value is num) return value != 0;
      if (value is String) {
        final lowered = value.toLowerCase();
        return lowered == 'true' || lowered == '1';
      }
      return false;
    }

    return PinMessageServerResponse(
      roomId: json['room_id']?.toString() ?? '',
      isPinned: parseBool(json['is_pinned']),
      message: message,
      pinnedAt: pinnedAt,
      pinnedBy: json['pinned_by']?.toString(),
    );
  }
}

class QuotedMessageResponse {
  QuotedMessageResponse({
    required this.id,
    required this.roomId,
    required this.senderId,
    required this.senderUsername,
    this.senderNickname,
    this.senderAvatarUrl,
    this.content,
    required this.messageType,
    this.createdAt,
    required this.isDeleted,
    this.parts = const [],
  });

  final String id;
  final String roomId;
  final String senderId;
  final String senderUsername;
  final String? senderNickname;
  final String? senderAvatarUrl;
  final String? content;
  final String messageType;
  final DateTime? createdAt;
  final bool isDeleted;
  final List<MessagePartResponse> parts;

  factory QuotedMessageResponse.fromJson(Map<String, dynamic> json) {
    bool parseDeleted(dynamic value) {
      if (value is bool) return value;
      if (value is num) return value != 0;
      if (value is String) {
        final lowered = value.toLowerCase();
        return lowered == 'true' || lowered == '1';
      }
      return false;
    }

    // 解析 parts
    final partsRaw = json['parts'];
    final parts = <MessagePartResponse>[];
    if (partsRaw is List) {
      for (final item in partsRaw) {
        if (item is Map<String, dynamic>) {
          parts.add(MessagePartResponse.fromJson(item));
        } else if (item is Map) {
          final normalized = <String, dynamic>{};
          item.forEach((key, value) {
            normalized[key.toString()] = value;
          });
          parts.add(MessagePartResponse.fromJson(normalized));
        }
      }
    }

    return QuotedMessageResponse(
      id: json['id']?.toString() ?? '',
      roomId: json['room_id']?.toString() ?? '',
      senderId: json['sender_id']?.toString() ?? '',
      senderUsername: json['sender_username']?.toString() ?? '',
      senderNickname: json['sender_nickname'] as String?,
      senderAvatarUrl: json['sender_avatar_url'] as String?,
      content: json['content'] as String?,
      messageType: json['message_type']?.toString() ?? 'text',
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
      isDeleted: parseDeleted(json['is_deleted']),
      parts: parts,
    );
  }
}

MessageStatus? _parseMessageStatusFromApi(dynamic raw) {
  if (raw == null) return null;
  final value = raw.toString().toLowerCase();
  switch (value) {
    case 'sending':
      return MessageStatus.sending;
    case 'delivered':
      return MessageStatus.delivered;
    case 'read':
      return MessageStatus.read;
    case 'failed':
      return MessageStatus.failed;
    case 'sent':
      return MessageStatus.sent;
    default:
      return null;
  }
}
