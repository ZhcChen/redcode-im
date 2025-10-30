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

String? _asOptionalString(String? value) =>
    value == null || value.isEmpty ? null : value;

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
    if (data is Uint8List) {
      _handleBinaryMessage(data);
    } else if (data is List<int>) {
      _handleBinaryMessage(Uint8List.fromList(data));
    } else if (data is String) {
      _handleJsonFrame(data);
    } else {
      debugPrint('Unknown WebSocket payload type: ${data.runtimeType}');
    }
  }

  void _handleJsonFrame(String data) {
    try {
      final decoded = jsonDecode(data);
      if (decoded is Map<String, dynamic>) {
        final event = _eventFromLegacyMap(decoded);
        if (event != null) {
          _dispatchEvent(event);
        } else {
          debugPrint('Ignored legacy WebSocket event: ${decoded['type']}');
        }
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
      final parsed = _eventFromProto(event);
      if (parsed != null) {
        _dispatchEvent(parsed);
      } else {
        debugPrint('Ignored protobuf event: ${event.whichPayload()}');
      }
    } catch (e) {
      debugPrint('Failed to handle protobuf WebSocket message: $e');
    }
  }

  String? _nullIfEmpty(String? value) =>
      value == null || value.isEmpty ? null : value;

  _WsEvent? _eventFromProto(ws.ServerEvent event) {
    switch (event.whichPayload()) {
      case ws.ServerEvent_Payload.authed:
        final payload = event.authed;
        if (payload.userId.isEmpty || payload.connId.isEmpty) {
          return null;
        }
        return _AuthedEvent(
          userId: payload.userId,
          connectionId: payload.connId,
        );
      case ws.ServerEvent_Payload.joined:
        final roomId = event.joined.roomId;
        if (roomId.isEmpty) return null;
        return _JoinedEvent(roomId: roomId);
      case ws.ServerEvent_Payload.left:
        final roomId = event.left.roomId;
        if (roomId.isEmpty) return null;
        return _LeftEvent(roomId: roomId);
      case ws.ServerEvent_Payload.message:
        try {
          final message = WebSocketMessage.fromProto(event.message);
          return _MessageEvent(message: message);
        } catch (e) {
          debugPrint('Failed to convert message proto: $e');
          return null;
        }
      case ws.ServerEvent_Payload.messageRead:
        final payload = event.messageRead;
        if (payload.roomId.isEmpty ||
            payload.messageId.isEmpty ||
            payload.readerId.isEmpty) {
          return null;
        }
        return _MessageReadEvent(
          roomId: payload.roomId,
          messageId: payload.messageId,
          readerId: payload.readerId,
        );
      case ws.ServerEvent_Payload.messageUpdate:
        final payload = event.messageUpdate;
        if (payload.roomId.isEmpty || payload.messageId.isEmpty) {
          return null;
        }
        return _MessageUpdateEvent(
          roomId: payload.roomId,
          messageId: payload.messageId,
          isDeleted: payload.isDeleted,
          deletedAt: _parseDateTime(_nullIfEmpty(payload.deletedAt)),
        );
      case ws.ServerEvent_Payload.pinUpdate:
        final payload = event.pinUpdate;
        if (payload.roomId.isEmpty) {
          return null;
        }
        return _PinUpdateEvent(
          roomId: payload.roomId,
          messageId: _nullIfEmpty(payload.messageId),
          isPinned: payload.isPinned,
          pinnedAt: _parseDateTime(_nullIfEmpty(payload.pinnedAt)),
          pinnedBy: _nullIfEmpty(payload.pinnedBy),
        );
      case ws.ServerEvent_Payload.friendRequestUpdate:
        return _FriendRequestUpdateEvent(
          pendingCount: event.friendRequestUpdate.pendingCount,
        );
      case ws.ServerEvent_Payload.roomCreated:
        final payload = event.roomCreated;
        return _RoomCreatedEvent(
          roomId: payload.roomId,
          roomName: payload.roomName,
          roomType: _nullIfEmpty(payload.roomType),
          avatarUrl: _nullIfEmpty(payload.avatarUrl),
          description: _nullIfEmpty(payload.description),
          initiatorId: _nullIfEmpty(payload.initiatorId),
          createdAt: _parseDateTime(_nullIfEmpty(payload.createdAt)),
        );
      case ws.ServerEvent_Payload.error:
        return _ErrorEvent(message: event.error.message);
      case ws.ServerEvent_Payload.pong:
        return const _PongEvent();
      case ws.ServerEvent_Payload.notSet:
        return null;
    }
  }

  _WsEvent? _eventFromLegacyMap(Map<String, dynamic> message) {
    final rawType = message['type'];
    if (rawType == null) return null;
    final type = rawType.toString().toLowerCase();

    switch (type) {
      case 'authed':
        final userId = message['user_id']?.toString();
        final connId = message['conn_id']?.toString();
        if (userId == null ||
            userId.isEmpty ||
            connId == null ||
            connId.isEmpty) {
          return null;
        }
        return _AuthedEvent(userId: userId, connectionId: connId);
      case 'joined':
        final roomId = message['room_id']?.toString() ?? '';
        if (roomId.isEmpty) return null;
        return _JoinedEvent(roomId: roomId);
      case 'left':
        final roomId = message['room_id']?.toString() ?? '';
        if (roomId.isEmpty) return null;
        return _LeftEvent(roomId: roomId);
      case 'message':
        try {
          final msg = WebSocketMessage.fromJson(message);
          return _MessageEvent(message: msg);
        } catch (e) {
          debugPrint('Failed to parse legacy message event: $e');
          return null;
        }
      case 'message_read':
        final roomId = message['room_id']?.toString() ?? '';
        final messageId = message['message_id']?.toString() ?? '';
        final readerId = message['reader_id']?.toString() ?? '';
        if (roomId.isEmpty || messageId.isEmpty || readerId.isEmpty) {
          return null;
        }
        return _MessageReadEvent(
          roomId: roomId,
          messageId: messageId,
          readerId: readerId,
        );
      case 'message_update':
        final roomId = message['room_id']?.toString() ?? '';
        final messageId = message['message_id']?.toString() ?? '';
        if (roomId.isEmpty || messageId.isEmpty) {
          return null;
        }
        final rawDeleted = message['is_deleted'];
        final isDeleted = rawDeleted is bool
            ? rawDeleted
            : rawDeleted?.toString().toLowerCase() == 'true';
        final deletedAt = _parseDateTime(message['deleted_at']?.toString());
        return _MessageUpdateEvent(
          roomId: roomId,
          messageId: messageId,
          isDeleted: isDeleted,
          deletedAt: deletedAt,
        );
      case 'pin_update':
        final roomId = message['room_id']?.toString() ?? '';
        if (roomId.isEmpty) return null;
        final rawPinned = message['is_pinned'];
        final isPinned = rawPinned is bool
            ? rawPinned
            : rawPinned?.toString().toLowerCase() == 'true';
        final pinnedAt = _parseDateTime(message['pinned_at']?.toString());
        final messageId = message['message_id']?.toString();
        final pinnedBy = message['pinned_by']?.toString();
        return _PinUpdateEvent(
          roomId: roomId,
          messageId: _nullIfEmpty(messageId),
          isPinned: isPinned,
          pinnedAt: pinnedAt,
          pinnedBy: _nullIfEmpty(pinnedBy),
        );
      case 'error':
        final msg = message['message']?.toString() ?? 'Unknown error';
        return _ErrorEvent(message: msg);
      case 'pong':
        return const _PongEvent();
      case 'friend_request_update':
        final rawCount = message['pending_count'];
        final count = rawCount is num ? rawCount.toInt() : 0;
        return _FriendRequestUpdateEvent(pendingCount: count);
      case 'room_created':
      case 'room.created':
        final roomId = message['room_id']?.toString() ?? '';
        if (roomId.isEmpty) return null;
        return _RoomCreatedEvent(
          roomId: roomId,
          roomName: message['room_name']?.toString() ?? '',
          roomType: _nullIfEmpty(message['room_type']?.toString()),
          avatarUrl: _nullIfEmpty(message['avatar_url']?.toString()),
          description: _nullIfEmpty(message['description']?.toString()),
          initiatorId: _nullIfEmpty(message['initiator_id']?.toString()),
          createdAt: _parseDateTime(message['created_at']?.toString()),
        );
      case 'friendship.created':
      case 'friendship_created':
        final data = message['friend'] ?? message['user'];
        AuthUser? user;
        if (data is Map<String, dynamic>) {
          try {
            user = AuthUser.fromJson(Map<String, dynamic>.from(data));
          } catch (e) {
            debugPrint('Failed to parse friendship.created payload: $e');
          }
        }
        return _FriendshipCreatedEvent(user: user);
      case 'friendship.deleted':
      case 'friendship_deleted':
        final id = message['user_id'] ?? message['friend_user_id'];
        return _FriendshipDeletedEvent(
          userId: id is String ? id : id?.toString(),
        );
      case 'friend.updated':
      case 'friend_profile_updated':
        final userId = message['user_id']?.toString();
        if (userId == null || userId.isEmpty) return null;
        return _FriendProfileUpdatedEvent(
          userId: userId,
          username: _nullIfEmpty(message['username']?.toString()),
          nickname: _nullIfEmpty(message['nickname']?.toString()),
          avatarUrl: _nullIfEmpty(message['avatar_url']?.toString()),
        );
      case 'friends.version':
      case 'friends_version':
        final version = message['version']?.toString();
        return _FriendsVersionEvent(version: version);
      default:
        return null;
    }
  }

  void _dispatchEvent(_WsEvent event) {
    if (event is _AuthedEvent) {
      _handleAuthed(event);
    } else if (event is _JoinedEvent) {
      _handleJoined(event);
    } else if (event is _LeftEvent) {
      _handleLeft(event);
    } else if (event is _MessageEvent) {
      _handleNewMessage(event.message);
    } else if (event is _MessageReadEvent) {
      _handleMessageRead(event);
    } else if (event is _MessageUpdateEvent) {
      _handleMessageUpdate(event);
    } else if (event is _PinUpdateEvent) {
      _handlePinUpdate(event);
    } else if (event is _FriendRequestUpdateEvent) {
      _handleFriendRequestUpdate(event);
    } else if (event is _RoomCreatedEvent) {
      _handleRoomCreated(event);
    } else if (event is _FriendshipCreatedEvent) {
      _handleFriendshipCreated(event);
    } else if (event is _FriendshipDeletedEvent) {
      _handleFriendshipDeleted(event);
    } else if (event is _FriendProfileUpdatedEvent) {
      _handleFriendProfileUpdated(event);
    } else if (event is _FriendsVersionEvent) {
      _handleFriendsVersion(event);
    } else if (event is _ErrorEvent) {
      _handleServerError(event.message);
    } else if (event is _PongEvent) {
      debugPrint('Received pong');
    }
  }

  DateTime? _parseDateTime(String? value) {
    if (value == null || value.isEmpty) return null;
    return DateTime.tryParse(value);
  }

  /// 处理认证成功
  void _handleAuthed(_AuthedEvent event) {
    _connectionId = event.connectionId;
    _setStatus(ConnectionStatus.authenticated);
    debugPrint('WebSocket authenticated: $_connectionId');

    // 重新订阅期待的房间
    final rooms = List<String>.from(_desiredRooms);
    _subscribedRooms.clear();
    _pendingJoinRooms.clear();
    for (final roomId in rooms) {
      if (roomId.isEmpty) continue;
      final joinEvent = ws.ClientEvent(join: ws.ClientJoin(roomId: roomId));
      _pendingJoinRooms.add(roomId);
      _sendClientEvent(joinEvent);
    }

    // 认证成功后刷新：
    // 1) 会话列表，确保聊天页立即展示数据
    unawaited(_messageService.fetchChats());
    // 2) 好友列表（一次全量），联系人页依赖 WS 增量 + 首屏 HTTP
    unawaited(_refreshFriendsOnce());
  }

  /// 处理加入房间成功
  void _handleJoined(_JoinedEvent event) {
    final roomId = event.roomId;
    _pendingJoinRooms.remove(roomId);
    _subscribedRooms.add(roomId);
    debugPrint('Joined room: $roomId');
  }

  /// 处理离开房间成功
  void _handleLeft(_LeftEvent event) {
    final roomId = event.roomId;
    _subscribedRooms.remove(roomId);
    _pendingJoinRooms.remove(roomId);
    _desiredRooms.remove(roomId);
    debugPrint('Left room: $roomId');
  }

  /// 处理新消息
  void _handleNewMessage(WebSocketMessage message) {
    try {
      unawaited(_messageService.handleWebSocketMessage(message));
    } catch (e) {
      debugPrint('Failed to process new message: $e');
    }
  }

  void _handleMessageRead(_MessageReadEvent event) {
    unawaited(
      _messageService.handleReadReceipt(
        roomId: event.roomId,
        messageId: event.messageId,
        readerId: event.readerId,
      ),
    );
  }

  void _handleMessageUpdate(_MessageUpdateEvent event) {
    unawaited(
      _messageService.handleMessageUpdate(
        roomId: event.roomId,
        messageId: event.messageId,
        isDeleted: event.isDeleted,
        deletedAt: event.deletedAt,
      ),
    );
  }

  void _handlePinUpdate(_PinUpdateEvent event) {
    unawaited(
      _messageService.handlePinUpdate(
        roomId: event.roomId,
        messageId: event.messageId,
        isPinned: event.isPinned,
        pinnedAt: event.pinnedAt,
        pinnedBy: event.pinnedBy,
      ),
    );
  }

  void _handleFriendRequestUpdate(_FriendRequestUpdateEvent event) {
    _setPendingFriendRequestCount(event.pendingCount);
    FriendStore.instance.setPendingIncoming(event.pendingCount);
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

  void _handleFriendshipCreated(_FriendshipCreatedEvent event) {
    final user = event.user;
    if (user == null || user.id.isEmpty) {
      unawaited(_refreshFriendsOnce());
      unawaited(_messageService.fetchChats());
      return;
    }

    FriendStore.instance.upsertFriend(
      FriendInfo(id: user.id, user: user, createdAt: DateTime.now()),
    );

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
  }

  void _handleFriendshipDeleted(_FriendshipDeletedEvent event) {
    final userId = event.userId;
    if (userId != null && userId.isNotEmpty) {
      FriendStore.instance.removeFriendByUserId(userId);
    } else {
      unawaited(_refreshFriendsOnce());
    }
  }

  void _handleFriendProfileUpdated(_FriendProfileUpdatedEvent event) {
    final userId = event.userId;
    if (userId == null || userId.isEmpty) return;
    FriendStore.instance.updateFriendProfile(
      userId: userId,
      username: event.username,
      nickname: event.nickname,
      avatarUrl: event.avatarUrl,
    );
  }

  void _handleFriendsVersion(_FriendsVersionEvent event) {
    final version = event.version;
    if (version == null) return;
    if (FriendStore.instance.version == null ||
        FriendStore.instance.version != version) {
      unawaited(_refreshFriendsOnce());
    }
  }

  void _handleRoomCreated(_RoomCreatedEvent event) {
    final roomId = event.roomId;
    if (roomId.isEmpty) {
      debugPrint('room_created payload missing room_id');
      return;
    }

    _messageService.ensureRoomPlaceholder(
      roomId: roomId,
      name: event.roomName,
      roomType: event.roomType,
      avatarUrl: event.avatarUrl,
      description: event.description,
      initiatorId: event.initiatorId,
      createdAt: event.createdAt,
    );

    unawaited(joinRoom(roomId));
    unawaited(_messageService.fetchChats());
  }

  /// 处理服务器错误
  void _handleServerError(String message) {
    debugPrint('Server error: $message');
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

  factory WebSocketMessage.fromProto(ws.ServerMessage proto) {
    final generatedId = proto.id.isNotEmpty
        ? proto.id
        : proto.messageId.isNotEmpty
        ? proto.messageId
        : const uuid_pkg.Uuid().v4();

    final quotedMessage = proto.hasQuotedMessage()
        ? WebSocketQuotedMessage.fromProto(proto.quotedMessage)
        : null;

    final forwardMessage = proto.hasForwardMessage()
        ? WebSocketForwardMessage.fromProto(proto.forwardMessage)
        : null;

    final timestamp = proto.timestamp.isNotEmpty
        ? DateTime.tryParse(proto.timestamp) ?? DateTime.now()
        : DateTime.now();

    return WebSocketMessage(
      id: generatedId,
      roomId: proto.roomId,
      senderId: proto.senderId,
      senderUsername: _asOptionalString(proto.senderUsername),
      senderNickname: _asOptionalString(proto.senderNickname),
      senderAvatarUrl: _asOptionalString(proto.senderAvatarUrl),
      content: proto.content,
      messageType: proto.messageType.isNotEmpty ? proto.messageType : 'text',
      timestamp: timestamp,
      extra: null,
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

  factory WebSocketForwardMessage.fromProto(ws.ForwardMessage proto) {
    return WebSocketForwardMessage(
      messageId: proto.messageId,
      roomId: proto.roomId,
      senderId: proto.senderId,
      senderUsername: _asOptionalString(proto.senderUsername),
      senderNickname: _asOptionalString(proto.senderNickname),
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

  factory WebSocketQuotedMessage.fromProto(ws.QuotedMessage proto) {
    return WebSocketQuotedMessage(
      id: proto.id,
      roomId: proto.roomId,
      senderId: proto.senderId,
      senderUsername: _asOptionalString(proto.senderUsername),
      senderNickname: _asOptionalString(proto.senderNickname),
      senderAvatarUrl: _asOptionalString(proto.senderAvatarUrl),
      content: _asOptionalString(proto.content),
      messageType: proto.messageType.isNotEmpty ? proto.messageType : 'text',
      createdAt: proto.createdAt.isNotEmpty
          ? DateTime.tryParse(proto.createdAt)
          : null,
      isDeleted: proto.isDeleted,
    );
  }
}

abstract class _WsEvent {
  const _WsEvent();
}

class _AuthedEvent extends _WsEvent {
  const _AuthedEvent({required this.userId, required this.connectionId});
  final String userId;
  final String connectionId;
}

class _JoinedEvent extends _WsEvent {
  const _JoinedEvent({required this.roomId});
  final String roomId;
}

class _LeftEvent extends _WsEvent {
  const _LeftEvent({required this.roomId});
  final String roomId;
}

class _MessageEvent extends _WsEvent {
  const _MessageEvent({required this.message});
  final WebSocketMessage message;
}

class _MessageReadEvent extends _WsEvent {
  const _MessageReadEvent({
    required this.roomId,
    required this.messageId,
    required this.readerId,
  });
  final String roomId;
  final String messageId;
  final String readerId;
}

class _MessageUpdateEvent extends _WsEvent {
  const _MessageUpdateEvent({
    required this.roomId,
    required this.messageId,
    required this.isDeleted,
    this.deletedAt,
  });
  final String roomId;
  final String messageId;
  final bool isDeleted;
  final DateTime? deletedAt;
}

class _PinUpdateEvent extends _WsEvent {
  const _PinUpdateEvent({
    required this.roomId,
    required this.isPinned,
    this.messageId,
    this.pinnedAt,
    this.pinnedBy,
  });
  final String roomId;
  final bool isPinned;
  final String? messageId;
  final DateTime? pinnedAt;
  final String? pinnedBy;
}

class _FriendRequestUpdateEvent extends _WsEvent {
  const _FriendRequestUpdateEvent({required this.pendingCount});
  final int pendingCount;
}

class _RoomCreatedEvent extends _WsEvent {
  const _RoomCreatedEvent({
    required this.roomId,
    required this.roomName,
    this.roomType,
    this.avatarUrl,
    this.description,
    this.initiatorId,
    this.createdAt,
  });
  final String roomId;
  final String roomName;
  final String? roomType;
  final String? avatarUrl;
  final String? description;
  final String? initiatorId;
  final DateTime? createdAt;
}

class _FriendshipCreatedEvent extends _WsEvent {
  const _FriendshipCreatedEvent({this.user});
  final AuthUser? user;
}

class _FriendshipDeletedEvent extends _WsEvent {
  const _FriendshipDeletedEvent({this.userId});
  final String? userId;
}

class _FriendProfileUpdatedEvent extends _WsEvent {
  const _FriendProfileUpdatedEvent({
    this.userId,
    this.username,
    this.nickname,
    this.avatarUrl,
  });
  final String? userId;
  final String? username;
  final String? nickname;
  final String? avatarUrl;
}

class _FriendsVersionEvent extends _WsEvent {
  const _FriendsVersionEvent({this.version});
  final String? version;
}

class _PongEvent extends _WsEvent {
  const _PongEvent();
}

class _ErrorEvent extends _WsEvent {
  const _ErrorEvent({required this.message});
  final String message;
}
