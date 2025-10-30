import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as ws_status;
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:uuid/uuid.dart' as uuid_pkg;

import '../constants/app_config.dart';
import '../storage/token_storage.dart';
import 'message_service.dart';
import 'friend_store.dart';
import 'friend_service.dart';
import '../../features/contacts/models/friend_models.dart';
import '../../features/auth/models/auth_user.dart';
import '../../proto/ws.pb.dart' as ws;

/// WebSocket连接状态
enum ConnectionStatus {
  connecting,
  connected,
  authenticated,
  disconnected,
  error,
}

/// WebSocket服务 - 管理WebSocket连接和消息
class WebSocketService with ChangeNotifier {
  WebSocketService({TokenStorage? tokenStorage, MessageService? messageService})
    : _tokenStorage = tokenStorage ?? const TokenStorage(),
      _messageService = messageService ?? MessageService.instance;

  final TokenStorage _tokenStorage;
  final MessageService _messageService;

  // WebSocket相关
  WebSocketChannel? _channel;
  StreamSubscription? _messageSubscription;
  StreamSubscription? _connectivitySubscription;

  // 状态管理
  ConnectionStatus _status = ConnectionStatus.disconnected;
  ConnectionStatus get status => _status;

  String? _connectionId;
  String? get connectionId => _connectionId;

  final Set<String> _subscribedRooms = {};
  Set<String> get subscribedRooms => Set.from(_subscribedRooms);

  final Set<String> _desiredRooms = {};
  Set<String> get desiredRooms => Set.from(_desiredRooms);

  final Set<String> _pendingJoinRooms = {};

  int _pendingFriendRequestCount = 0;
  int get pendingFriendRequestCount => _pendingFriendRequestCount;

  // 重连相关
  Timer? _reconnectTimer;
  Timer? _pingTimer;
  int _reconnectAttempts = 0;
  static const int _maxReconnectAttempts = 5;
  static const Duration _reconnectDelay = Duration(seconds: 3);
  static const Duration _pingInterval = Duration(seconds: 30);

  // 单例模式
  static WebSocketService? _instance;
  static WebSocketService get instance {
    _instance ??= WebSocketService();
    return _instance!;
  }

  /// 连接WebSocket
  Future<void> connect() async {
    if (_status == ConnectionStatus.connected ||
        _status == ConnectionStatus.authenticated) {
      debugPrint('WebSocket already connected');
      return;
    }

    _setStatus(ConnectionStatus.connecting);

    try {
      // 获取认证token
      final session = await _tokenStorage.readSession();
      if (session == null || session.token.isEmpty) {
        throw Exception('No authentication token available');
      }

      // 建立WebSocket连接
      final wsUrl = AppConfig.wsUrl;
      final baseUri = Uri.parse(wsUrl);
      final mergedParams = Map<String, String>.from(baseUri.queryParameters);
      mergedParams['format'] = 'proto';
      final wsUri = baseUri.replace(queryParameters: mergedParams);
      debugPrint('Connecting to WebSocket: $wsUri');

      _channel = WebSocketChannel.connect(wsUri);

      // 监听消息
      _messageSubscription?.cancel();
      _messageSubscription = _channel!.stream.listen(
        _handleIncomingFrame,
        onError: _handleError,
        onDone: _handleDisconnect,
        cancelOnError: false,
      );

      _setStatus(ConnectionStatus.connected);

      // 发送认证消息
      await _authenticate(session.token);

      // 启动心跳
      _startPingTimer();

      // 监听网络状态
      _startConnectivityMonitor();

      _reconnectAttempts = 0;
    } catch (e) {
      debugPrint('WebSocket connection failed: $e');
      _setStatus(ConnectionStatus.error);
      _scheduleReconnect();
    }
  }

  /// 断开连接
  Future<void> disconnect() async {
    debugPrint('Disconnecting WebSocket');

    _cancelTimers();
    _messageSubscription?.cancel();
    _connectivitySubscription?.cancel();

    await _channel?.sink.close(ws_status.normalClosure);
    _channel = null;

    _subscribedRooms.clear();
    _desiredRooms.clear();
    _pendingJoinRooms.clear();
    _connectionId = null;

    _setStatus(ConnectionStatus.disconnected);
  }

  /// 发送认证消息
  Future<void> _authenticate(String token) async {
    final event = ws.ClientEvent(auth: ws.ClientAuth(token: token));
    _sendClientEvent(event);
  }

  /// 加入房间
  Future<void> joinRoom(String roomId) async {
    if (roomId.isEmpty) return;

    _desiredRooms.add(roomId);

    if (!_isAuthenticated) {
      debugPrint('Defer join until authenticated: $roomId');
      return;
    }

    if (_subscribedRooms.contains(roomId)) {
      debugPrint('Already subscribed to room: $roomId');
      return;
    }

    if (_pendingJoinRooms.contains(roomId)) {
      debugPrint('Join already pending: $roomId');
      return;
    }

    final event = ws.ClientEvent(join: ws.ClientJoin(roomId: roomId));
    _pendingJoinRooms.add(roomId);

    _sendClientEvent(event);
  }

  /// 离开房间
  Future<void> leaveRoom(String roomId) async {
    if (roomId.isEmpty) return;

    _desiredRooms.remove(roomId);

    if (!_isAuthenticated) {
      debugPrint('Defer leave until authenticated: $roomId');
      _subscribedRooms.remove(roomId);
      _pendingJoinRooms.remove(roomId);
      return;
    }

    if (!_subscribedRooms.contains(roomId) &&
        !_pendingJoinRooms.contains(roomId)) {
      debugPrint('Not subscribed to room: $roomId');
      return;
    }

    final event = ws.ClientEvent(leave: ws.ClientLeave(roomId: roomId));
    _pendingJoinRooms.remove(roomId);

    _sendClientEvent(event);
  }

  /// 确保订阅指定房间；可选是否解除不在列表中的房间
  void ensureRoomsSubscribed(
    Iterable<String> roomIds, {
    bool pruneMissing = false,
  }) {
    final targets = roomIds
        .map((roomId) => roomId.trim())
        .where((roomId) => roomId.isNotEmpty)
        .toSet();

    if (targets.isEmpty) {
      if (pruneMissing && _desiredRooms.isNotEmpty) {
        // 需要清空但没有目标房间时直接全部移除
        for (final roomId in List<String>.from(_desiredRooms)) {
          leaveRoom(roomId);
        }
      }
      return;
    }

    if (pruneMissing) {
      final removed = _desiredRooms.difference(targets);
      for (final roomId in removed) {
        leaveRoom(roomId);
      }
    }

    for (final roomId in targets) {
      if (!_desiredRooms.contains(roomId)) {
        _desiredRooms.add(roomId);
      }

      if (_subscribedRooms.contains(roomId) ||
          _pendingJoinRooms.contains(roomId)) {
        continue;
      }

      if (!_isAuthenticated) {
        debugPrint('Defer join until authenticated: $roomId');
        continue;
      }

      final event = ws.ClientEvent(join: ws.ClientJoin(roomId: roomId));
      _pendingJoinRooms.add(roomId);
      _sendClientEvent(event);
    }
  }

  /// 发送 protobuf 客户端事件
  void _sendClientEvent(ws.ClientEvent event) {
    if (_channel == null) {
      debugPrint('Cannot send message: WebSocket not connected');
      return;
    }

    try {
      final bytes = event.writeToBuffer();
      _channel!.sink.add(bytes);
      debugPrint('Sent WebSocket client event: ${event.whichPayload()}');
    } catch (e) {
      debugPrint('Failed to send WebSocket client event: $e');
    }
  }

  void _handleIncomingFrame(dynamic data) {
    if (data is String) {
      _handleJsonFrame(data);
    } else if (data is Uint8List) {
      _handleBinaryMessage(data);
    } else if (data is List<int>) {
      _handleBinaryMessage(Uint8List.fromList(data));
    } else {
      debugPrint('Unknown WebSocket payload type: ${data.runtimeType}');
    }
  }

  void _handleJsonFrame(String data) {
    try {
      final decoded = jsonDecode(data);
      if (decoded is Map<String, dynamic>) {
        _handleMapMessage(decoded);
      } else {
        debugPrint('Unexpected JSON payload: $decoded');
      }
    } catch (e) {
      debugPrint('Failed to handle WebSocket JSON message: $e');
    }
  }

  void _handleBinaryMessage(Uint8List data) {
    try {
      final event = ws.ServerEvent.create()..mergeFromBuffer(data);
      final mapped = _serverEventToMap(event);
      if (mapped != null) {
        _handleMapMessage(mapped);
      } else {
        debugPrint('Ignored protobuf event: ${event.whichPayload()}');
      }
    } catch (e) {
      debugPrint('Failed to handle protobuf WebSocket message: $e');
    }
  }

  Map<String, dynamic>? _serverEventToMap(ws.ServerEvent event) {
    switch (event.whichPayload()) {
      case ws.ServerEvent_Payload.authed:
        final payload = event.authed;
        return {
          'type': 'authed',
          'user_id': payload.userId,
          'conn_id': payload.connId,
        };
      case ws.ServerEvent_Payload.joined:
        return {'type': 'joined', 'room_id': event.joined.roomId};
      case ws.ServerEvent_Payload.left:
        return {'type': 'left', 'room_id': event.left.roomId};
      case ws.ServerEvent_Payload.message:
        final payload = event.message;
        final map = <String, dynamic>{
          'type': 'message',
          'id': payload.id,
          'message_id': payload.messageId,
          'room_id': payload.roomId,
          'sender_id': payload.senderId,
          'sender_username': _nullIfEmpty(payload.senderUsername),
          'sender_nickname': _nullIfEmpty(payload.senderNickname),
          'sender_avatar_url': _nullIfEmpty(payload.senderAvatarUrl),
          'content': payload.content,
          'message_type': payload.messageType,
          'timestamp': payload.timestamp,
        };

        if (payload.hasQuotedMessage()) {
          final quoted = payload.quotedMessage;
          map['quoted_message'] = {
            'id': quoted.id,
            'room_id': quoted.roomId,
            'sender_id': quoted.senderId,
            'sender_username': _nullIfEmpty(quoted.senderUsername),
            'sender_nickname': _nullIfEmpty(quoted.senderNickname),
            'sender_avatar_url': _nullIfEmpty(quoted.senderAvatarUrl),
            'content': _nullIfEmpty(quoted.content),
            'message_type': quoted.messageType,
            'created_at': _nullIfEmpty(quoted.createdAt),
            'is_deleted': quoted.isDeleted,
          };
        } else {
          map['quoted_message'] = null;
        }

        if (payload.hasForwardMessage()) {
          final forward = payload.forwardMessage;
          map['forward_message'] = {
            'message_id': forward.messageId,
            'room_id': forward.roomId,
            'sender_id': forward.senderId,
            'sender_username': _nullIfEmpty(forward.senderUsername),
            'sender_nickname': _nullIfEmpty(forward.senderNickname),
          };
        } else {
          map['forward_message'] = null;
        }

        return map;
      case ws.ServerEvent_Payload.messageRead:
        final payload = event.messageRead;
        return {
          'type': 'message_read',
          'room_id': payload.roomId,
          'message_id': payload.messageId,
          'reader_id': payload.readerId,
          'read_at': payload.readAt,
        };
      case ws.ServerEvent_Payload.messageUpdate:
        final payload = event.messageUpdate;
        return {
          'type': 'message_update',
          'room_id': payload.roomId,
          'message_id': payload.messageId,
          'is_deleted': payload.isDeleted,
          'deleted_at': _nullIfEmpty(payload.deletedAt),
        };
      case ws.ServerEvent_Payload.pinUpdate:
        final payload = event.pinUpdate;
        return {
          'type': 'pin_update',
          'room_id': payload.roomId,
          'message_id': _nullIfEmpty(payload.messageId),
          'is_pinned': payload.isPinned,
          'pinned_at': _nullIfEmpty(payload.pinnedAt),
          'pinned_by': _nullIfEmpty(payload.pinnedBy),
        };
      case ws.ServerEvent_Payload.error:
        return {'type': 'error', 'message': event.error.message};
      case ws.ServerEvent_Payload.pong:
        return {'type': 'pong'};
      case ws.ServerEvent_Payload.friendRequestUpdate:
        return {
          'type': 'friend_request_update',
          'pending_count': event.friendRequestUpdate.pendingCount,
        };
      case ws.ServerEvent_Payload.roomCreated:
        final payload = event.roomCreated;
        return {
          'type': 'room_created',
          'room_id': payload.roomId,
          'room_name': payload.roomName,
          'room_type': payload.roomType,
          'initiator_id': payload.initiatorId,
          'owner_id': payload.ownerId,
          'description': _nullIfEmpty(payload.description),
          'avatar_url': _nullIfEmpty(payload.avatarUrl),
          'created_at': _nullIfEmpty(payload.createdAt),
        };
      case ws.ServerEvent_Payload.notSet:
        return null;
    }
  }

  String? _nullIfEmpty(String value) => value.isEmpty ? null : value;

  /// 处理接收到的消息
  void _handleMapMessage(Map<String, dynamic> message) {
    try {
      debugPrint('Received WebSocket message: ${message['type']}');

      switch (message['type']) {
        case 'authed':
          _handleAuthed(message);
          break;
        case 'joined':
          _handleJoined(message);
          break;
        case 'left':
          _handleLeft(message);
          break;
        case 'message':
          _handleNewMessage(message);
          break;
        case 'message_update':
          _handleMessageUpdate(message);
          break;
        case 'pin_update':
          _handlePinUpdate(message);
          break;
        case 'message_read':
          _handleMessageRead(message);
          break;
        case 'error':
          _handleServerError(message);
          break;
        case 'pong':
          // 心跳响应
          debugPrint('Received pong');
          break;
        case 'friend_request_update':
          _handleFriendRequestUpdate(message);
          break;
        // 好友增量事件（服务端命名可能不同，做多别名兼容）
        case 'friendship.created':
        case 'friendship_created':
          _handleFriendshipCreated(message);
          break;
        case 'friendship.deleted':
        case 'friendship_deleted':
          _handleFriendshipDeleted(message);
          break;
        case 'friend.updated':
        case 'friend_profile_updated':
          _handleFriendProfileUpdated(message);
          break;
        case 'friends.version':
        case 'friends_version':
          _handleFriendsVersion(message);
          break;
        case 'room.created':
        case 'room_created':
          _handleRoomCreated(message);
          break;
        default:
          debugPrint('Unknown message type: ${message['type']}');
      }
    } catch (e) {
      debugPrint('Failed to handle WebSocket message: $e');
    }
  }

  /// 处理认证成功
  void _handleAuthed(Map<String, dynamic> message) {
    _connectionId = message['conn_id'];
    _setStatus(ConnectionStatus.authenticated);
    debugPrint('WebSocket authenticated: $_connectionId');

    // 重新订阅期待的房间
    final rooms = List<String>.from(_desiredRooms);
    _subscribedRooms.clear();
    _pendingJoinRooms.clear();
    for (final roomId in rooms) {
      if (roomId.isEmpty) continue;
      final event = ws.ClientEvent(join: ws.ClientJoin(roomId: roomId));
      _pendingJoinRooms.add(roomId);
      _sendClientEvent(event);
    }

    // 认证成功后刷新：
    // 1) 会话列表，确保聊天页立即展示数据
    unawaited(_messageService.fetchChats());
    // 2) 好友列表（一次全量），联系人页依赖 WS 增量 + 首屏 HTTP
    unawaited(_refreshFriendsOnce());
  }

  /// 处理加入房间成功
  void _handleJoined(Map<String, dynamic> message) {
    final roomId = (message['room_id'] as String?) ?? '';
    if (roomId.isEmpty) return;
    _pendingJoinRooms.remove(roomId);
    _subscribedRooms.add(roomId);
    debugPrint('Joined room: $roomId');
  }

  /// 处理离开房间成功
  void _handleLeft(Map<String, dynamic> message) {
    final roomId = (message['room_id'] as String?) ?? '';
    if (roomId.isEmpty) return;
    _subscribedRooms.remove(roomId);
    _pendingJoinRooms.remove(roomId);
    _desiredRooms.remove(roomId);
    debugPrint('Left room: $roomId');
  }

  /// 处理新消息
  void _handleNewMessage(Map<String, dynamic> message) {
    try {
      // 转换为消息模型并通知MessageService
      final wsMessage = WebSocketMessage.fromJson(message);
      unawaited(_messageService.handleWebSocketMessage(wsMessage));
    } catch (e) {
      debugPrint('Failed to process new message: $e');
    }
  }

  void _handleMessageRead(Map<String, dynamic> payload) {
    final roomId = payload['room_id']?.toString() ?? '';
    final messageId = payload['message_id']?.toString() ?? '';
    final readerId = payload['reader_id']?.toString() ?? '';

    if (roomId.isEmpty || messageId.isEmpty || readerId.isEmpty) {
      debugPrint('Invalid read receipt payload: $payload');
      return;
    }

    unawaited(
      _messageService.handleReadReceipt(
        roomId: roomId,
        messageId: messageId,
        readerId: readerId,
      ),
    );
  }

  void _handleMessageUpdate(Map<String, dynamic> payload) {
    final roomId = payload['room_id']?.toString() ?? '';
    final messageId = payload['message_id']?.toString() ?? '';
    if (roomId.isEmpty || messageId.isEmpty) {
      debugPrint('Invalid message update payload: $payload');
      return;
    }

    final isDeletedRaw = payload['is_deleted'];
    final isDeleted = isDeletedRaw is bool
        ? isDeletedRaw
        : isDeletedRaw?.toString().toLowerCase() == 'true';

    DateTime? deletedAt;
    final deletedAtRaw = payload['deleted_at']?.toString();
    if (deletedAtRaw != null && deletedAtRaw.isNotEmpty) {
      deletedAt = DateTime.tryParse(deletedAtRaw);
    }

    unawaited(
      _messageService.handleMessageUpdate(
        roomId: roomId,
        messageId: messageId,
        isDeleted: isDeleted,
        deletedAt: deletedAt,
      ),
    );
  }

  void _handlePinUpdate(Map<String, dynamic> payload) {
    final roomId = payload['room_id']?.toString() ?? '';
    if (roomId.isEmpty) {
      debugPrint('Invalid pin update payload: $payload');
      return;
    }

    final messageId = payload['message_id']?.toString();
    final isPinnedRaw = payload['is_pinned'];
    final isPinned = isPinnedRaw is bool
        ? isPinnedRaw
        : isPinnedRaw?.toString().toLowerCase() == 'true';

    DateTime? pinnedAt;
    final pinnedAtRaw = payload['pinned_at']?.toString();
    if (pinnedAtRaw != null && pinnedAtRaw.isNotEmpty) {
      pinnedAt = DateTime.tryParse(pinnedAtRaw);
    }

    final pinnedBy = payload['pinned_by']?.toString();

    unawaited(
      _messageService.handlePinUpdate(
        roomId: roomId,
        messageId: messageId,
        isPinned: isPinned,
        pinnedAt: pinnedAt,
        pinnedBy: pinnedBy,
      ),
    );
  }

  void _handleFriendRequestUpdate(Map<String, dynamic> message) {
    final rawCount = message['pending_count'];
    final count = rawCount is num ? rawCount.toInt() : 0;
    _setPendingFriendRequestCount(count);
    FriendStore.instance.setPendingIncoming(count);
    // 好友请求状态变更后，尝试刷新会话列表，确保“被同意”一侧也能看到新会话
    unawaited(_messageService.fetchChats());
  }

  // =============== 好友相关 ===============
  Future<void> _refreshFriendsOnce() async {
    try {
      final list = await FriendService().fetchFriends();
      FriendStore.instance.setFriends(list);
    } catch (e) {
      debugPrint('Refresh friends failed: $e');
    }
  }

  void _handleFriendshipCreated(Map<String, dynamic> message) {
    try {
      final data = message['friend'] ?? message['user'];
      if (data is Map<String, dynamic>) {
        final user = AuthUser.fromJson(data);
        // 如果缺少 id，用 username 兜底不处理
        if (user.id.isEmpty) return;
        FriendStore.instance.upsertFriend(
          FriendInfo(id: user.id, user: user, createdAt: DateTime.now()),
        );

        // 确保双方设备都立即拥有单聊会话：
        // 1) 尝试通过 HTTP 确保/获取单聊房间
        // 2) 订阅该房间的 WS
        // 3) 刷新会话列表以出现在聊天页
        unawaited(() async {
          try {
            final ensure = await FriendService().ensurePrivateChat(user.id);
            await joinRoom(ensure.roomId);
            await _messageService.fetchChats();
          } catch (e) {
            debugPrint(
              'ensure/join/fetch chats after friendship created failed: $e',
            );
          }
        }());
      } else {
        // 无可用 payload，回退全量同步
        unawaited(_refreshFriendsOnce());
        unawaited(_messageService.fetchChats());
      }
    } catch (e) {
      debugPrint('handle friendship.created error: $e');
    }
  }

  void _handleFriendshipDeleted(Map<String, dynamic> message) {
    try {
      final id = message['user_id'] ?? message['friend_user_id'];
      if (id is String && id.isNotEmpty) {
        FriendStore.instance.removeFriendByUserId(id);
      } else {
        unawaited(_refreshFriendsOnce());
      }
    } catch (e) {
      debugPrint('handle friendship.deleted error: $e');
    }
  }

  void _handleFriendProfileUpdated(Map<String, dynamic> message) {
    try {
      final id = message['user_id'] as String?;
      if (id == null || id.isEmpty) return;
      FriendStore.instance.updateFriendProfile(
        userId: id,
        username: message['username'] as String?,
        nickname: message['nickname'] as String?,
        avatarUrl: message['avatar_url'] as String?,
      );
    } catch (e) {
      debugPrint('handle friend.updated error: $e');
    }
  }

  void _handleFriendsVersion(Map<String, dynamic> message) {
    final serverVersion = message['version']?.toString();
    if (serverVersion == null) return;
    if (FriendStore.instance.version == null ||
        FriendStore.instance.version != serverVersion) {
      // 版本不一致，做一次全量纠偏
      unawaited(_refreshFriendsOnce());
    }
  }

  void _handleRoomCreated(Map<String, dynamic> message) {
    final roomId = message['room_id']?.toString() ?? '';
    if (roomId.isEmpty) {
      debugPrint('room_created payload missing room_id: $message');
      return;
    }

    final roomName = message['room_name']?.toString() ?? '';
    final roomType = message['room_type']?.toString();
    final avatarUrl = message['avatar_url']?.toString();
    final description = message['description']?.toString();
    final initiatorId = message['initiator_id']?.toString();
    final createdAtRaw = message['created_at']?.toString();
    DateTime? createdAt;
    if (createdAtRaw != null && createdAtRaw.isNotEmpty) {
      createdAt = DateTime.tryParse(createdAtRaw);
    }

    _messageService.ensureRoomPlaceholder(
      roomId: roomId,
      name: roomName,
      roomType: roomType,
      avatarUrl: avatarUrl,
      description: description,
      initiatorId: initiatorId,
      createdAt: createdAt,
    );

    // 立即订阅房间，避免错过后续消息
    unawaited(joinRoom(roomId));
    // 更新聊天列表
    unawaited(_messageService.fetchChats());
  }

  /// 处理服务器错误
  void _handleServerError(Map<String, dynamic> message) {
    final error = message['message'] ?? 'Unknown error';
    debugPrint('Server error: $error');
  }

  /// 处理连接错误
  void _handleError(dynamic error) {
    debugPrint('WebSocket error: $error');
    _setStatus(ConnectionStatus.error);
    _scheduleReconnect();
  }

  /// 处理连接断开
  void _handleDisconnect() {
    debugPrint('WebSocket disconnected');

    if (_status != ConnectionStatus.disconnected) {
      _setStatus(ConnectionStatus.disconnected);
      _scheduleReconnect();
    }
  }

  /// 安排重连
  void _scheduleReconnect() {
    if (_reconnectAttempts >= _maxReconnectAttempts) {
      debugPrint('Max reconnect attempts reached');
      return;
    }

    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(_reconnectDelay, () {
      _reconnectAttempts++;
      debugPrint('Reconnecting... (attempt $_reconnectAttempts)');
      connect();
    });
  }

  /// 启动心跳定时器
  void _startPingTimer() {
    _pingTimer?.cancel();
    _pingTimer = Timer.periodic(_pingInterval, (_) {
      if (_isAuthenticated) {
        _sendClientEvent(ws.ClientEvent(ping: ws.ClientPing()));
      }
    });
  }

  /// 监听网络连接状态
  void _startConnectivityMonitor() {
    _connectivitySubscription?.cancel();
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((
      ConnectivityResult result,
    ) {
      final hasInternet =
          result != ConnectivityResult.none &&
          result != ConnectivityResult.bluetooth;

      if (hasInternet && _status == ConnectionStatus.disconnected) {
        debugPrint('Network available, reconnecting...');
        connect();
      }
    });
  }

  /// 取消所有定时器
  void _cancelTimers() {
    _reconnectTimer?.cancel();
    _pingTimer?.cancel();
  }

  /// 设置连接状态
  void _setStatus(ConnectionStatus newStatus) {
    if (_status != newStatus) {
      _status = newStatus;
      notifyListeners();
    }
  }

  /// 是否已认证
  bool get _isAuthenticated => _status == ConnectionStatus.authenticated;

  /// 是否已连接
  bool get isConnected =>
      _status == ConnectionStatus.connected ||
      _status == ConnectionStatus.authenticated;

  void _setPendingFriendRequestCount(int count) {
    if (count < 0) return;
    if (_pendingFriendRequestCount != count) {
      _pendingFriendRequestCount = count;
      notifyListeners();
    }
  }

  void syncPendingFriendRequestCount(int count) {
    _setPendingFriendRequestCount(count);
  }

  @override
  void dispose() {
    disconnect();
    super.dispose();
  }
}

/// WebSocket消息模型
class WebSocketMessage {
  final String id;
  final String roomId;
  final String senderId;
  final String? senderUsername;
  final String? senderNickname;
  final String? senderAvatarUrl;
  final String content;
  final String messageType;
  final DateTime timestamp;
  final Map<String, dynamic>? extra;
  final WebSocketQuotedMessage? quotedMessage;
  final WebSocketForwardMessage? forwardMessage;

  WebSocketMessage({
    required this.id,
    required this.roomId,
    required this.senderId,
    required this.senderUsername,
    required this.senderNickname,
    required this.senderAvatarUrl,
    required this.content,
    required this.messageType,
    required this.timestamp,
    required this.extra,
    required this.quotedMessage,
    required this.forwardMessage,
  });

  factory WebSocketMessage.fromJson(Map<String, dynamic> json) {
    // 生成或使用消息ID
    String messageId;
    if (json.containsKey('id') && json['id'] != null) {
      messageId = json['id'];
    } else if (json.containsKey('message_id') && json['message_id'] != null) {
      messageId = json['message_id'];
    } else {
      // 如果没有ID，生成一个临时ID
      messageId = const uuid_pkg.Uuid().v4();
    }

    Map<String, dynamic>? extra;
    final rawExtra = json['extra'];
    if (rawExtra is Map) {
      extra = Map<String, dynamic>.from(rawExtra.cast<String, dynamic>());
    }

    WebSocketQuotedMessage? quotedMessage;
    WebSocketForwardMessage? forwardMessage;
    final quotedRaw = json['quoted_message'];
    if (quotedRaw is Map<String, dynamic>) {
      quotedMessage = WebSocketQuotedMessage.fromJson(quotedRaw);
    } else if (quotedRaw is Map) {
      final map = <String, dynamic>{};
      quotedRaw.forEach((key, value) {
        map[key.toString()] = value;
      });
      quotedMessage = WebSocketQuotedMessage.fromJson(map);
    }

    final forwardRaw = json['forward_message'];
    if (forwardRaw is Map<String, dynamic>) {
      forwardMessage = WebSocketForwardMessage.fromJson(forwardRaw);
    } else if (forwardRaw is Map) {
      final map = <String, dynamic>{};
      forwardRaw.forEach((key, value) {
        map[key.toString()] = value;
      });
      forwardMessage = WebSocketForwardMessage.fromJson(map);
    }

    return WebSocketMessage(
      id: messageId,
      roomId: json['room_id'] ?? '',
      senderId: json['sender_id'] ?? '',
      senderUsername: json['sender_username'] as String?,
      senderNickname: json['sender_nickname'] as String?,
      senderAvatarUrl: json['sender_avatar_url'] as String?,
      content: json['content'] ?? '',
      messageType: json['message_type'] ?? 'text',
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'])
          : DateTime.now(),
      extra: extra,
      quotedMessage: quotedMessage,
      forwardMessage: forwardMessage,
    );
  }

  String get displayName {
    if (senderNickname != null && senderNickname!.isNotEmpty) {
      return senderNickname!;
    }
    if (senderUsername != null && senderUsername!.isNotEmpty) {
      return senderUsername!;
    }
    return senderId;
  }
}

class WebSocketForwardMessage {
  WebSocketForwardMessage({
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

  factory WebSocketForwardMessage.fromJson(Map<String, dynamic> json) {
    return WebSocketForwardMessage(
      messageId: json['message_id']?.toString() ?? '',
      roomId: json['room_id']?.toString() ?? '',
      senderId: json['sender_id']?.toString() ?? '',
      senderUsername: json['sender_username']?.toString(),
      senderNickname: json['sender_nickname']?.toString(),
    );
  }
}

class WebSocketQuotedMessage {
  WebSocketQuotedMessage({
    required this.id,
    required this.roomId,
    required this.senderId,
    this.senderUsername,
    this.senderNickname,
    this.senderAvatarUrl,
    this.content,
    required this.messageType,
    this.createdAt,
    required this.isDeleted,
  });

  final String id;
  final String roomId;
  final String senderId;
  final String? senderUsername;
  final String? senderNickname;
  final String? senderAvatarUrl;
  final String? content;
  final String messageType;
  final DateTime? createdAt;
  final bool isDeleted;

  factory WebSocketQuotedMessage.fromJson(Map<String, dynamic> json) {
    bool parseDeleted(dynamic value) {
      if (value is bool) return value;
      if (value is num) return value != 0;
      if (value is String) {
        final lowered = value.toLowerCase();
        return lowered == 'true' || lowered == '1';
      }
      return false;
    }

    return WebSocketQuotedMessage(
      id: json['id']?.toString() ?? '',
      roomId: json['room_id']?.toString() ?? '',
      senderId: json['sender_id']?.toString() ?? '',
      senderUsername: json['sender_username']?.toString(),
      senderNickname: json['sender_nickname']?.toString(),
      senderAvatarUrl: json['sender_avatar_url']?.toString(),
      content: json['content']?.toString(),
      messageType: json['message_type']?.toString() ?? 'text',
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
      isDeleted: parseDeleted(json['is_deleted']),
    );
  }
}
