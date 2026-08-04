import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart' as path_provider;
import '../../../core/constants/app_config.dart';
import '../../../core/services/app_config_service.dart';
import '../../../core/services/message_service.dart'
    show MessageAttachmentDraft, MessageService, MessageStatus;
import '../../../core/services/settings_service.dart'
    show MessageRuntimeSettings;
import '../../../core/services/websocket_service.dart';
import '../models/message_model.dart';
import '../models/chat_model.dart';
import '../models/message_reader.dart';

/// 聊天提供者 - 管理聊天状态
class ChatProvider with ChangeNotifier {
  ChatProvider({
    MessageService? messageService,
    WebSocketService? webSocketService,
    AppConfigService? appConfigService,
    http.Client? client,
  }) : _messageService = messageService ?? MessageService.instance,
       _webSocketService = webSocketService ?? WebSocketService.instance,
       _appConfigService = appConfigService ?? AppConfigService.instance,
       _client = client ?? http.Client(),
       _ownsClient = client == null {
    _init();
  }

  final MessageService _messageService;
  final WebSocketService _webSocketService;
  WebSocketService get webSocketService => _webSocketService;

  Stream<GroupMemberChangedEvent> get groupMemberChanges =>
      _webSocketService.onGroupMemberChanged;
  Stream<GroupSettingsUpdatedEvent> get groupSettingsUpdates =>
      _webSocketService.onGroupSettingsUpdated;
  final AppConfigService _appConfigService;
  final http.Client _client;
  final bool _ownsClient;

  bool get isRelayOnlyMode =>
      _appConfigService.currentMessageRuntime.isRelayOnly;
  MessageRuntimeSettings get currentMessageRuntime =>
      _appConfigService.currentMessageRuntime;

  // 当前房间ID
  String? _currentRoomId;
  String? get currentRoomId => _currentRoomId;

  // 当前聊天信息
  Chat? _currentChat;
  Chat? get currentChat => _currentChat;

  // 消息列表
  List<Message> _messages = [];
  List<Message> get messages => _messages;

  Message? get pinnedMessage => _currentRoomId == null
      ? null
      : _messageService.getPinnedMessage(_currentRoomId!);

  List<Message> get pinnedMessages => _currentRoomId == null
      ? []
      : _messageService.getPinnedMessages(_currentRoomId!);

  bool isMessagePinned(Message message) {
    return _messageService.isMessagePinned(message.roomId, message.id);
  }

  // 已读同步状态
  String? _lastReadMessageId;
  bool _isMarkingRead = false;
  bool _isDisposed = false;

  // 聊天列表
  List<Chat> _chats = [];
  List<Chat> get chats => _chats;

  // 搜索关键词
  String _searchKeyword = '';
  String get searchKeyword => _searchKeyword;

  // 过滤后的聊天列表
  List<Chat> get filteredChats {
    if (_searchKeyword.isEmpty) {
      return _chats;
    }
    final keyword = _searchKeyword.toLowerCase().trim();
    return _chats.where((chat) {
      // 匹配聊天名称
      if (chat.name.toLowerCase().contains(keyword)) {
        return true;
      }
      // 匹配备注/描述等附加信息
      final extra = chat.extra;
      final candidateFields = <String?>[
        extra?['friend_remark'] as String?,
        extra?['friendRemark'] as String?,
        extra?['friend_nickname'] as String?,
        extra?['friendNickname'] as String?,
        extra?['description'] as String?,
      ];
      for (final field in candidateFields) {
        if (field != null && field.toLowerCase().contains(keyword)) {
          return true;
        }
      }
      // 匹配最后消息内容
      if (chat.lastMessage.toLowerCase().contains(keyword)) {
        return true;
      }
      return false;
    }).toList();
  }

  // 加载状态
  bool _isLoading = false;
  bool get isLoading => _isLoading;

  bool _isChatsLoading = false;
  bool get isChatsLoading => _isChatsLoading;

  // 发送状态
  bool _isSending = false;
  bool get isSending => _isSending;

  /// 初始化
  void _init() {
    // 监听消息服务变化
    _messageService.addListener(_onMessageServiceChanged);
    // 监听WebSocket连接状态
    _webSocketService.addListener(_onWebSocketStatusChanged);
    // 监听运行模式变化，确保提示文案与能力开关及时刷新
    _appConfigService.addListener(_onAppConfigChanged);
    // 初始化当前会话与列表为消息服务已有数据（避免进入页面即触发HTTP拉取）
    _chats = _messageService.chats;
    notifyListeners();
  }

  /// 进入聊天室
  Future<void> enterChatRoom(
    String roomId,
    Chat chat, {
    bool delayHistoryLoad = false,
  }) async {
    if (_currentRoomId == roomId) return;

    _currentRoomId = roomId;
    _currentChat = chat;
    _lastReadMessageId = null;
    _isMarkingRead = false;

    _messages = _messageService.getMessages(roomId);
    _isLoading = true;
    notifyListeners();

    await _messageService.loadCachedMessages(roomId);

    _messages = _messageService.getMessages(roomId);
    _isLoading = false;
    notifyListeners();

    // 加入WebSocket房间
    await _webSocketService.joinRoom(roomId);

    // 异步更新聊天信息（包括头像）
    unawaited(_messageService.updateChatInfo(roomId, chat.type));

    if (delayHistoryLoad) {
      _scheduleInitialHistoryLoad();
    } else {
      await _loadInitialHistory();
    }

    if (chat.type == ChatType.group) {
      unawaited(_ensureMemberCount(roomId));
    }
  }

  /// 离开聊天室
  Future<void> leaveChatRoom() async {
    if (_currentRoomId == null || _isDisposed) return;

    await _syncReadState();

    if (_isDisposed) return;

    _currentRoomId = null;
    _currentChat = null;
    _messages = [];
    _lastReadMessageId = null;
    _isMarkingRead = false;
    notifyListeners();
  }

  /// 加载消息
  Future<void> loadMessages({int limit = 50, bool showLoading = true}) async {
    if (_currentRoomId == null || _isLoading) return;

    if (isRelayOnlyMode) {
      _messages = _messageService.getMessages(_currentRoomId!);
      _primeReadReceiptStateIfNeeded();
      notifyListeners();
      return;
    }

    _isLoading = true;
    if (showLoading || _messages.isEmpty) {
      notifyListeners();
    }

    try {
      await _messageService.loadMessages(_currentRoomId!, limit: limit);
      _messages = _messageService.getMessages(_currentRoomId!);
      _primeReadReceiptStateIfNeeded();
    } catch (e) {
      debugPrint('Failed to load messages: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 加载更多消息
  Future<void> loadMoreMessages({int limit = 50}) async {
    if (_currentRoomId == null ||
        _isLoading ||
        _messages.isEmpty ||
        isRelayOnlyMode) {
      return;
    }

    _isLoading = true;
    notifyListeners();

    try {
      final beforeId = _messages.first.id;
      final fetched = await _messageService.loadMessages(
        _currentRoomId!,
        limit: limit,
        beforeId: beforeId,
      );
      if (fetched.isNotEmpty) {
        _messages = _messageService.getMessages(_currentRoomId!);
        _primeReadReceiptStateIfNeeded();
      }
    } catch (e) {
      debugPrint('Failed to load more messages: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 加载消息直到找到目标消息
  /// 返回 true 表示找到了目标消息，false 表示已加载所有历史但未找到
  Future<bool> loadMessagesUntilFound(
    String targetMessageId, {
    int maxAttempts = 5,
    int limitPerRequest = 50,
  }) async {
    debugPrint('[loadMessagesUntilFound] 开始查找消息: $targetMessageId');
    debugPrint('[loadMessagesUntilFound] 当前房间ID: $_currentRoomId');

    if (_currentRoomId == null) {
      debugPrint('[loadMessagesUntilFound] 房间ID为空，返回false');
      return false;
    }

    if (isRelayOnlyMode) {
      return _messages.any((m) => m.id == targetMessageId);
    }

    // 先检查消息是否已经在列表中
    if (_messages.any((m) => m.id == targetMessageId)) {
      debugPrint('[loadMessagesUntilFound] 消息已在列表中');
      return true;
    }

    debugPrint('[loadMessagesUntilFound] 消息不在当前列表中，当前消息数: ${_messages.length}');

    if (_isLoading || _messages.isEmpty) {
      debugPrint('[loadMessagesUntilFound] 正在加载或列表为空，等待100ms');
      // 等待初始加载完成后再检查
      await Future.delayed(const Duration(milliseconds: 100));
      if (_messages.any((m) => m.id == targetMessageId)) {
        debugPrint('[loadMessagesUntilFound] 等待后消息已在列表中');
        return true;
      }
    }

    // 尝试加载更多历史消息
    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      debugPrint('[loadMessagesUntilFound] 第 ${attempt + 1} 次尝试加载更多消息');

      if (_messages.isEmpty) {
        debugPrint('[loadMessagesUntilFound] 消息列表为空，停止');
        break;
      }

      final beforeId = _messages.first.id;
      final previousCount = _messages.length;
      debugPrint(
        '[loadMessagesUntilFound] beforeId: $beforeId, 当前消息数: $previousCount',
      );

      _isLoading = true;
      notifyListeners();

      try {
        final fetched = await _messageService.loadMessages(
          _currentRoomId!,
          limit: limitPerRequest,
          beforeId: beforeId,
        );

        debugPrint('[loadMessagesUntilFound] 加载完成，获取到 ${fetched.length} 条消息');

        _messages = _messageService.getMessages(_currentRoomId!);
        debugPrint('[loadMessagesUntilFound] 更新后消息数: ${_messages.length}');

        // 检查是否找到了目标消息
        if (_messages.any((m) => m.id == targetMessageId)) {
          debugPrint('[loadMessagesUntilFound] 找到目标消息！');
          _isLoading = false;
          notifyListeners();
          return true;
        }

        // 如果没有加载到新消息，说明已到达历史起点
        if (fetched.isEmpty || _messages.length == previousCount) {
          debugPrint('[loadMessagesUntilFound] 没有更多消息了，已到达历史起点');
          _isLoading = false;
          notifyListeners();
          return false;
        }
      } catch (e) {
        debugPrint('[loadMessagesUntilFound] 加载失败: $e');
        _isLoading = false;
        notifyListeners();
        return false;
      }
    }

    debugPrint('[loadMessagesUntilFound] 达到最大尝试次数，仍未找到');
    _isLoading = false;
    notifyListeners();
    return false;
  }

  /// 发送文本消息
  Future<void> sendTextMessage(String content, {Message? quotedMessage}) async {
    await sendRichMessage(text: content, quotedMessage: quotedMessage);
  }

  Future<void> sendRichMessage({
    String? text,
    List<MessageAttachmentDraft> attachments = const [],
    Message? quotedMessage,
  }) async {
    if (_currentRoomId == null || _isSending) {
      return;
    }

    final trimmed = text?.trim();
    if ((trimmed == null || trimmed.isEmpty) && attachments.isEmpty) {
      return;
    }

    _isSending = true;
    notifyListeners();

    try {
      await _messageService.sendRichMessage(
        roomId: _currentRoomId!,
        text: trimmed,
        attachments: attachments,
        quotedMessage: isRelayOnlyMode ? null : quotedMessage,
      );
    } catch (e) {
      debugPrint('Failed to send message: $e');
      rethrow;
    } finally {
      _isSending = false;
      notifyListeners();
    }
  }

  /// 发送语音消息
  Future<void> sendVoiceMessage({
    required String roomId,
    required List<int> fileBytes,
    required int duration,
    required String fileName,
  }) async {
    if (_isSending) {
      return;
    }

    // 创建临时文件
    final tempDir = await path_provider.getTemporaryDirectory();
    final tempFile = File('${tempDir.path}/$fileName');
    await tempFile.writeAsBytes(fileBytes);

    var sent = false;
    try {
      final attachment = MessageAttachmentDraft(
        type: MessagePartType.audio,
        file: tempFile,
        displayName: fileName,
        mime: 'audio/mp4',
        durationMs: duration,
      );

      await sendRichMessage(attachments: [attachment]);
      sent = true;
    } catch (e) {
      debugPrint('Failed to send voice message: $e');
      rethrow;
    } finally {
      // 失败消息仍需依赖本地录音执行手动重试。
      if (sent && await tempFile.exists()) {
        await tempFile.delete();
      }
    }
  }

  Future<void> forwardMessage(Message original, Chat targetChat) async {
    if (isRelayOnlyMode) {
      debugPrint('relay_only mode: forward message is disabled');
      return;
    }

    final forwardInfo = original.forwardInfo ?? _buildForwardInfo(original);

    try {
      await _messageService.forwardMessage(
        original: original,
        targetRoomId: targetChat.roomId,
        forwardInfo: forwardInfo,
      );
    } catch (e) {
      debugPrint('Failed to forward message: $e');
      rethrow;
    }
  }

  Future<void> pinMessage(Message message) async {
    if (isRelayOnlyMode) {
      debugPrint('relay_only mode: pin message is disabled');
      return;
    }
    await _messageService.pinMessage(message.roomId, message.id);
  }

  Future<void> unpinMessage(Message message) async {
    if (isRelayOnlyMode) {
      debugPrint('relay_only mode: unpin message is disabled');
      return;
    }
    await _messageService.unpinMessage(message.roomId, message.id);
  }

  Future<void> deleteMessage(Message message) async {
    if (isRelayOnlyMode || !message.isSelf || message.isDeleted) {
      debugPrint('delete message is disabled for current message state');
      return;
    }
    await _messageService.markMessageDeleted(message.roomId, message.id);
  }

  Future<void> editMessage(Message message, String content) async {
    if (isRelayOnlyMode ||
        !message.isSelf ||
        message.type != MessageType.text ||
        message.isDeleted) {
      return;
    }
    await _messageService.editMessage(
      roomId: message.roomId,
      messageId: message.id,
      content: content,
    );
  }

  Future<void> toggleReaction(Message message, String reactionKey) async {
    if (isRelayOnlyMode) {
      debugPrint('relay_only mode: reaction is disabled');
      return;
    }

    final existingReaction = message.reactions?.firstWhere(
      (reaction) => reaction.reactionKey == reactionKey,
      orElse: () => MessageReactionSummary(
        reactionKey: '',
        count: 0,
        userIds: const <String>[],
        hasSelf: false,
      ),
    );
    final hasSelf = existingReaction?.hasSelf ?? false;

    if (hasSelf) {
      await _messageService.removeReaction(
        roomId: message.roomId,
        messageId: message.id,
        reactionKey: reactionKey,
      );
      return;
    }

    await _messageService.addReaction(
      roomId: message.roomId,
      messageId: message.id,
      reactionKey: reactionKey,
    );
  }

  /// 重发消息
  Future<void> resendMessage(String messageId) async {
    final index = _messages.indexWhere((message) => message.id == messageId);
    if (index >= 0 &&
        _messages[index].extra?['e2ee_decryption_failed'] == true) {
      final roomId = _messages[index].roomId;
      await _messageService.retryEncryptedMessage(roomId, messageId);
      _messages = _messageService.getMessages(roomId);
      notifyListeners();
      return;
    }
    await _messageService.resendMessage(messageId);
  }

  bool shouldShowReadReceipts(Message message) {
    final chat = _currentChat;
    if (chat == null) return false;
    if (!message.isSelf || message.status != MessageStatus.read) return false;
    if (chat.type != ChatType.group) return false;
    final cached = _messageService.cachedRoomMemberCount(chat.roomId);
    if (cached != null) {
      return cached <= 100;
    }
    return true;
  }

  Future<List<Map<String, dynamic>>> getRoomMembers(String roomId) async {
    return await _messageService.fetchRoomMembers(roomId);
  }

  /// 上传群头像
  Future<String> uploadGroupAvatar(
    String roomId,
    String filePath,
    String contentType,
    int fileSize,
  ) async {
    try {
      final session = await _messageService.tokenStorage.readSession();
      if (session == null) {
        throw Exception('Not logged in');
      }

      final response = await _client.post(
        Uri.parse('${AppConfig.apiBaseUrl}/rooms/$roomId/avatar/direct-upload'),
        headers: {
          'Authorization': 'Bearer ${session.token}',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'content_type': contentType, 'file_size': fileSize}),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        if (data['success'] == true) {
          return data['key'] as String;
        } else {
          throw Exception('Failed to get upload signature: ${data['message']}');
        }
      } else {
        throw Exception('Failed to get upload signature: ${response.body}');
      }
    } catch (e) {
      debugPrint('Failed to get group avatar upload signature: $e');
      rethrow;
    }
  }

  /// 提交群头像上传
  Future<String> commitGroupAvatarUpload(
    String roomId,
    String uploadKey,
  ) async {
    try {
      final session = await _messageService.tokenStorage.readSession();
      if (session == null) {
        throw Exception('Not logged in');
      }

      final response = await _client.post(
        Uri.parse('${AppConfig.apiBaseUrl}/rooms/$roomId/avatar/commit'),
        headers: {
          'Authorization': 'Bearer ${session.token}',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'key': uploadKey}),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        if (data['success'] == true) {
          return data['avatar_url'] as String;
        } else {
          throw Exception('Failed to commit avatar upload: ${data['message']}');
        }
      } else {
        throw Exception('Failed to commit avatar upload: ${response.body}');
      }
    } catch (e) {
      debugPrint('Failed to commit group avatar upload: $e');
      rethrow;
    }
  }

  int? cachedMemberCount(String roomId) {
    return _messageService.cachedRoomMemberCount(roomId);
  }

  Future<int> getRoomMemberCount(String roomId, {bool forceRefresh = false}) {
    return _messageService.fetchRoomMemberCount(
      roomId,
      forceRefresh: forceRefresh,
    );
  }

  Future<List<MessageReader>> fetchMessageReaders(
    Message message, {
    bool forceRefresh = false,
  }) {
    return _messageService.fetchMessageReaders(
      message.roomId,
      message.id,
      forceRefresh: forceRefresh,
    );
  }

  /// 加载聊天列表
  Future<void> loadChats({bool refresh = false}) async {
    if (_isChatsLoading && !refresh) return;

    _isChatsLoading = true;
    notifyListeners();

    try {
      await _messageService.fetchChats();
      _chats = _messageService.chats;
    } catch (e) {
      debugPrint('Failed to load chats: $e');
    } finally {
      _isChatsLoading = false;
      notifyListeners();
    }
  }

  /// 将会话从当前用户的聊天收件箱归档，不删除消息或成员关系。
  Future<Chat?> archiveChat(String chatId) async {
    final index = _chats.indexWhere((chat) => chat.id == chatId);
    if (index < 0) return null;

    final chat = _chats[index];
    if (chat.type == ChatType.favorite) {
      debugPrint('收藏夹会话不可归档');
      return null;
    }

    // 乐观更新
    _chats.removeAt(index);
    notifyListeners();

    try {
      final session = await _messageService.tokenStorage.readSession();
      if (session == null) {
        throw Exception('Not logged in');
      }

      final response = await _client.delete(
        Uri.parse('${AppConfig.apiBaseUrl}/chats/${chat.roomId}'),
        headers: {'Authorization': 'Bearer ${session.token}'},
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to archive chat: ${response.body}');
      }
      return chat;
    } catch (e) {
      debugPrint('Failed to archive chat: $e');
      if (!_chats.any((candidate) => candidate.id == chat.id)) {
        _chats.insert(index.clamp(0, _chats.length), chat);
        notifyListeners();
      }
      rethrow;
    }
  }

  Future<void> deleteChat(String chatId) async {
    await archiveChat(chatId);
  }

  Future<void> restoreArchivedChat(Chat chat) async {
    if (_chats.any((candidate) => candidate.id == chat.id)) {
      return;
    }
    _chats.add(chat);
    _sortChats();
    notifyListeners();

    try {
      final session = await _messageService.tokenStorage.readSession();
      if (session == null) {
        throw Exception('Not logged in');
      }
      final response = await _client.post(
        Uri.parse('${AppConfig.apiBaseUrl}/chats/${chat.roomId}/restore'),
        headers: {'Authorization': 'Bearer ${session.token}'},
      );
      if (response.statusCode != 200) {
        throw Exception('Failed to restore chat: ${response.body}');
      }
    } catch (e) {
      final optimisticIndex = _chats.indexWhere(
        (candidate) => identical(candidate, chat),
      );
      if (optimisticIndex >= 0) {
        _chats.removeAt(optimisticIndex);
        notifyListeners();
      }
      rethrow;
    }
  }

  /// 置顶聊天
  Future<void> pinChat(String chatId, bool isPinned) async {
    final index = _chats.indexWhere((chat) => chat.id == chatId);
    if (index < 0) return;

    final chat = _chats[index];
    if (chat.type == ChatType.favorite) {
      if (!chat.isPinned) {
        _chats[index] = chat.copyWith(isPinned: true);
        notifyListeners();
      }
      return;
    }

    final oldPinned = chat.isPinned;
    // 乐观更新
    _chats[index] = chat.copyWith(isPinned: isPinned);
    _sortChats();
    notifyListeners();

    try {
      final session = await _messageService.tokenStorage.readSession();
      if (session == null) {
        throw Exception('Not logged in');
      }

      final response = isPinned
          ? await _client.post(
              Uri.parse('${AppConfig.apiBaseUrl}/rooms/${chat.roomId}/pin'),
              headers: {'Authorization': 'Bearer ${session.token}'},
            )
          : await _client.delete(
              Uri.parse('${AppConfig.apiBaseUrl}/rooms/${chat.roomId}/pin'),
              headers: {'Authorization': 'Bearer ${session.token}'},
            );

      if (response.statusCode != 200) {
        throw Exception('Failed to update pin status: ${response.body}');
      }
    } catch (e) {
      debugPrint('Failed to update pin status: $e');
      // 失败时回滚
      final rollbackIndex = _chats.indexWhere((c) => c.id == chatId);
      if (rollbackIndex >= 0) {
        _chats[rollbackIndex] = _chats[rollbackIndex].copyWith(
          isPinned: oldPinned,
        );
        _sortChats();
        notifyListeners();
      }
      rethrow;
    }
  }

  /// 静音聊天
  Future<void> muteChat(String chatId, bool isMuted) async {
    await setNotificationMode(
      chatId,
      isMuted ? ChatNotificationMode.muted : ChatNotificationMode.all,
    );
  }

  Future<void> setNotificationMode(
    String chatId,
    ChatNotificationMode mode,
  ) async {
    final index = _chats.indexWhere((chat) => chat.id == chatId);
    if (index < 0) return;

    final chat = _chats[index];
    final oldMode = chat.notificationMode;

    // 乐观更新
    _chats[index] = chat.copyWith(notificationMode: mode);
    notifyListeners();

    try {
      final session = await _messageService.tokenStorage.readSession();
      if (session == null) {
        throw Exception('Not logged in');
      }

      final response = await _client.post(
        Uri.parse(
          '${AppConfig.apiBaseUrl}/rooms/${chat.roomId}/notification-settings',
        ),
        headers: {
          'Authorization': 'Bearer ${session.token}',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'notification_settings': mode.apiValue}),
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to update mute status: ${response.body}');
      }
    } catch (e) {
      debugPrint('Failed to update mute status: $e');
      // 失败时回滚
      final rollbackIndex = _chats.indexWhere((c) => c.id == chatId);
      if (rollbackIndex >= 0 &&
          _chats[rollbackIndex].notificationMode == mode) {
        _chats[rollbackIndex] = _chats[rollbackIndex].copyWith(
          notificationMode: oldMode,
        );
        notifyListeners();
      }
      rethrow;
    }
  }

  /// 清空单个房间的聊天消息（仅本地缓存）
  /// 调用方如需同时清空服务器端历史记录，应先调用后端清空接口，再调用此方法同步本地状态。
  Future<void> clearChatMessages(String roomId) async {
    if (roomId == _currentRoomId) {
      _messages = [];
      notifyListeners();
    }
    _messageService.clearRoomMessages(roomId);
  }

  ForwardInfo _buildForwardInfo(Message original) {
    final forwarded = original.forwardInfo;
    if (forwarded != null) {
      return forwarded;
    }

    final sourceChat = _currentChat;
    final sourceType = sourceChat == null
        ? ForwardSourceType.unknown
        : _mapForwardSourceType(sourceChat.type);

    final sourceName = sourceChat?.name ?? original.displaySenderName;

    return ForwardInfo(
      sourceType: sourceType,
      sourceId: sourceChat?.roomId ?? original.roomId,
      sourceName: sourceName,
      sourceAvatar: sourceChat?.avatar,
      originMessageId: original.forwardInfo?.originMessageId ?? original.id,
      originRoomId: original.forwardInfo?.originRoomId ?? original.roomId,
      originSenderId: original.forwardInfo?.originSenderId ?? original.senderId,
      originSenderName:
          original.forwardInfo?.originSenderName ?? original.displaySenderName,
    );
  }

  ForwardSourceType _mapForwardSourceType(ChatType type) {
    switch (type) {
      case ChatType.group:
        return ForwardSourceType.group;
      case ChatType.favorite:
        return ForwardSourceType.favorite;
      case ChatType.single:
        return ForwardSourceType.user;
    }
  }

  Future<void> _loadInitialHistory() async {
    await loadMessages(showLoading: false);
    _primeReadReceiptStateIfNeeded();
    await _syncReadState();
  }

  void _scheduleInitialHistoryLoad() {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (_currentRoomId == null) return;
      await _loadInitialHistory();
    });
  }

  /// 消息服务变化回调
  void _onMessageServiceChanged() {
    if (_currentRoomId != null) {
      Chat? currentChat;
      for (final chat in _messageService.chats) {
        if (chat.roomId == _currentRoomId) {
          currentChat = chat;
          break;
        }
      }
      if (currentChat != null) {
        _currentChat = currentChat;
        _messages = _messageService.getMessages(_currentRoomId!);
        _primeReadReceiptStateIfNeeded();
        unawaited(_syncReadState());
      } else {
        _currentRoomId = null;
        _currentChat = null;
        _messages = [];
      }
    }
    _chats = _messageService.chats;
    notifyListeners();
  }

  void _onAppConfigChanged() {
    notifyListeners();
  }

  /// WebSocket状态变化回调
  void _onWebSocketStatusChanged() {
    final status = _webSocketService.status;
    debugPrint('WebSocket status changed: $status');

    if (status == ConnectionStatus.authenticated && _currentRoomId != null) {
      // 重新订阅当前房间
      _webSocketService.joinRoom(_currentRoomId!);

      // 刚重连完成后，补拉当前房间信息（头像/名称等可能在离线期间已更新）
      final roomId = _currentRoomId!;
      final chat = _currentChat;
      if (chat != null) {
        unawaited(_messageService.updateChatInfo(roomId, chat.type));
      }
    }
  }

  /// 设置搜索关键词
  void setSearchKeyword(String keyword) {
    if (_searchKeyword != keyword) {
      _searchKeyword = keyword;
      notifyListeners();
    }
  }

  /// 清空搜索
  void clearSearch() {
    if (_searchKeyword.isNotEmpty) {
      _searchKeyword = '';
      notifyListeners();
    }
  }

  /// 排序聊天列表
  void _sortChats() {
    _chats.sort((a, b) {
      // 收藏夹始终排在最前面
      final aIsFavorite = a.type == ChatType.favorite;
      final bIsFavorite = b.type == ChatType.favorite;
      if (aIsFavorite && !bIsFavorite) return -1;
      if (!aIsFavorite && bIsFavorite) return 1;
      // 置顶的排在前面
      if (a.isPinned && !b.isPinned) return -1;
      if (!a.isPinned && b.isPinned) return 1;
      // 按时间排序
      return b.lastMessageTime.compareTo(a.lastMessageTime);
    });
  }

  Future<void> _ensureMemberCount(
    String roomId, {
    bool forceRefresh = false,
  }) async {
    try {
      await _messageService.fetchRoomMemberCount(
        roomId,
        forceRefresh: forceRefresh,
      );
      notifyListeners();
    } catch (e) {
      debugPrint('Failed to load member count for $roomId: $e');
    }
  }

  void _primeReadReceiptStateIfNeeded() {
    if (_currentRoomId == null) return;
    if (_messages.isEmpty) return;
    if (_lastReadMessageId != null) return;

    for (var i = _messages.length - 1; i >= 0; i--) {
      final message = _messages[i];
      if (message.isSelf) continue;
      if (message.status == MessageStatus.read) {
        _lastReadMessageId = message.id;
      }
      break;
    }
  }

  Future<void> _syncReadState() async {
    final roomId = _currentRoomId;
    if (roomId == null) return;
    if (_isMarkingRead) return;
    if (_messages.isEmpty) return;

    Message? latestIncoming;
    for (var i = _messages.length - 1; i >= 0; i--) {
      final message = _messages[i];
      if (message.isSelf) continue;
      latestIncoming = message;
      break;
    }

    if (latestIncoming == null) return;

    if (latestIncoming.status == MessageStatus.read) {
      _lastReadMessageId = latestIncoming.id;
      return;
    }

    if (_lastReadMessageId == latestIncoming.id) {
      return;
    }

    if (isRelayOnlyMode) {
      _lastReadMessageId = latestIncoming.id;
      _messageService.markChatAsRead(roomId);
      return;
    }

    _isMarkingRead = true;
    try {
      await _messageService.markMessagesAsRead(roomId, latestIncoming.id);
      _lastReadMessageId = latestIncoming.id;
    } catch (e) {
      debugPrint('Failed to mark messages as read: $e');
    } finally {
      _isMarkingRead = false;
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    _messageService.removeListener(_onMessageServiceChanged);
    _webSocketService.removeListener(_onWebSocketStatusChanged);
    _appConfigService.removeListener(_onAppConfigChanged);
    if (_ownsClient) {
      _client.close();
    }
    super.dispose();
  }
}
