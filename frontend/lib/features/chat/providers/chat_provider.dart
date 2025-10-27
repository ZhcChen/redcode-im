import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../../core/services/message_service.dart';
import '../../../core/services/websocket_service.dart';
import '../models/message_model.dart';
import '../models/chat_model.dart';
import '../models/message_reader.dart';

/// 聊天提供者 - 管理聊天状态
class ChatProvider with ChangeNotifier {
  ChatProvider({
    MessageService? messageService,
    WebSocketService? webSocketService,
  }) : _messageService = messageService ?? MessageService.instance,
       _webSocketService = webSocketService ?? WebSocketService.instance {
    _init();
  }

  final MessageService _messageService;
  final WebSocketService _webSocketService;

  // 当前房间ID
  String? _currentRoomId;
  String? get currentRoomId => _currentRoomId;

  // 当前聊天信息
  Chat? _currentChat;
  Chat? get currentChat => _currentChat;

  // 消息列表
  List<Message> _messages = [];
  List<Message> get messages => _messages;

  // 已读同步状态
  String? _lastReadMessageId;
  bool _isMarkingRead = false;

  // 聊天列表
  List<Chat> _chats = [];
  List<Chat> get chats => _chats;

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
    // 初始化当前会话与列表为消息服务已有数据（避免进入页面即触发HTTP拉取）
    _chats = _messageService.chats;
    notifyListeners();
  }

  /// 进入聊天室
  Future<void> enterChatRoom(String roomId, Chat chat) async {
    if (_currentRoomId == roomId) return;

    _currentRoomId = roomId;
    _currentChat = chat;
    _messages = [];
    _lastReadMessageId = null;
    _isMarkingRead = false;
    notifyListeners();

    await _messageService.loadCachedMessages(roomId);

    // 加入WebSocket房间
    await _webSocketService.joinRoom(roomId);

    // 加载历史消息
    await loadMessages(showLoading: false);

    if (chat.type == ChatType.group) {
      unawaited(_ensureMemberCount(roomId));
    }

    _primeReadReceiptStateIfNeeded();
    await _syncReadState();
  }

  /// 离开聊天室
  Future<void> leaveChatRoom() async {
    if (_currentRoomId == null) return;

    await _syncReadState();

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

    _isLoading = true;
    if (showLoading) {
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
    if (_currentRoomId == null || _isLoading || _messages.isEmpty) return;

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

  /// 发送文本消息
  Future<void> sendTextMessage(String content) async {
    if (_currentRoomId == null || content.trim().isEmpty || _isSending) return;

    _isSending = true;
    notifyListeners();

    try {
      await _messageService.sendTextMessage(_currentRoomId!, content);
    } catch (e) {
      debugPrint('Failed to send message: $e');
      // 可以显示错误提示
    } finally {
      _isSending = false;
      notifyListeners();
    }
  }

  /// 发送图片消息
  Future<void> sendImageMessage(String imagePath) async {
    if (_currentRoomId == null || _isSending) return;

    _isSending = true;
    notifyListeners();

    try {
      await _messageService.sendImageMessage(_currentRoomId!, imagePath);
    } catch (e) {
      debugPrint('Failed to send image: $e');
    } finally {
      _isSending = false;
      notifyListeners();
    }
  }

  /// 重发消息
  Future<void> resendMessage(String messageId) async {
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

  /// 删除聊天
  Future<void> deleteChat(String chatId) async {
    final index = _chats.indexWhere((chat) => chat.id == chatId);
    if (index < 0) return;

    final chat = _chats[index];
    if (chat.type == ChatType.favorite) {
      debugPrint('收藏夹会话不可删除');
      return;
    }

    _chats.removeAt(index);
    notifyListeners();

    // TODO: 调用API删除
  }

  /// 置顶聊天
  Future<void> pinChat(String chatId, bool isPinned) async {
    final index = _chats.indexWhere((chat) => chat.id == chatId);
    if (index >= 0) {
      final chat = _chats[index];
      if (chat.type == ChatType.favorite) {
        if (!chat.isPinned) {
          _chats[index] = chat.copyWith(isPinned: true);
          notifyListeners();
        }
        return;
      }
      _chats[index] = chat.copyWith(isPinned: isPinned);
      _sortChats();
      notifyListeners();
    }

    // TODO: 调用API更新
  }

  /// 静音聊天
  Future<void> muteChat(String chatId, bool isMuted) async {
    final index = _chats.indexWhere((chat) => chat.id == chatId);
    if (index >= 0) {
      _chats[index] = _chats[index].copyWith(isMuted: isMuted);
      notifyListeners();
    }

    // TODO: 调用API更新
  }

  /// 清空聊天消息
  Future<void> clearChatMessages(String roomId) async {
    if (roomId == _currentRoomId) {
      _messages = [];
      notifyListeners();
    }
    _messageService.clearRoomMessages(roomId);

    // TODO: 调用API清空
  }

  /// 消息服务变化回调
  void _onMessageServiceChanged() {
    if (_currentRoomId != null) {
      _messages = _messageService.getMessages(_currentRoomId!);
      _primeReadReceiptStateIfNeeded();
      unawaited(_syncReadState());
    }
    _chats = _messageService.chats;
    notifyListeners();
  }

  /// WebSocket状态变化回调
  void _onWebSocketStatusChanged() {
    final status = _webSocketService.status;
    debugPrint('WebSocket status changed: $status');

    if (status == ConnectionStatus.authenticated && _currentRoomId != null) {
      // 重新订阅当前房间
      _webSocketService.joinRoom(_currentRoomId!);
    }
  }

  /// 排序聊天列表
  void _sortChats() {
    _chats.sort((a, b) {
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
    _messageService.removeListener(_onMessageServiceChanged);
    _webSocketService.removeListener(_onWebSocketStatusChanged);
    super.dispose();
  }
}
