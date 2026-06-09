import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as ws_status;
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:uuid/uuid.dart' as uuid_pkg;

import '../constants/app_config.dart';
import '../auth/auth_state.dart';
import '../storage/token_storage.dart';
import 'message_service.dart';
import 'friend_store.dart';
import 'friend_service.dart';
import 'room_subscription_manager.dart';
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

/// 群设置更新事件（公开）
class GroupSettingsUpdatedEvent {
  const GroupSettingsUpdatedEvent({
    required this.roomId,
    required this.globalMuteEnabled,
    this.globalMuteReason,
    this.globalMuteUntil,
    this.globalMuteSetBy,
  });

  final String roomId;
  final bool globalMuteEnabled;
  final String? globalMuteReason;
  final String? globalMuteUntil;
  final String? globalMuteSetBy;
}

/// 群成员变更事件（公开）
class GroupMemberChangedEvent {
  const GroupMemberChangedEvent({
    required this.roomId,
    required this.memberId,
    required this.changeType,
    this.newRole,
    this.operatorId,
    this.reason,
    this.until,
  });

  final String roomId;
  final String memberId;
  final String changeType; // role_changed, muted, unmuted, kicked, joined, left
  final String? newRole;
  final String? operatorId;
  final String? reason;
  final String? until;
}

/// 正在输入事件（公开）
class TypingUpdateEvent {
  const TypingUpdateEvent({
    required this.roomId,
    required this.userId,
    required this.isTyping,
    required this.expiresInMs,
  });

  final String roomId;
  final String userId;
  final bool isTyping;
  final int expiresInMs;
}

/// WebSocket服务 - 管理WebSocket连接和消息
class WebSocketService with ChangeNotifier {
  WebSocketService({TokenStorage? tokenStorage, MessageService? messageService})
    : _tokenStorage = tokenStorage ?? const TokenStorage(),
      _messageService = messageService ?? MessageService.instance {
    _initRoomManager();
  }

  final TokenStorage _tokenStorage;
  final MessageService _messageService;

  // 房间订阅管理器
  late final RoomSubscriptionManager _roomManager;

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

  // 群设置更新事件流
  final StreamController<GroupSettingsUpdatedEvent> _groupSettingsUpdatedController =
      StreamController<GroupSettingsUpdatedEvent>.broadcast();
  Stream<GroupSettingsUpdatedEvent> get onGroupSettingsUpdated =>
      _groupSettingsUpdatedController.stream;

  // 群成员变更事件流
  final StreamController<GroupMemberChangedEvent> _groupMemberChangedController =
      StreamController<GroupMemberChangedEvent>.broadcast();
  Stream<GroupMemberChangedEvent> get onGroupMemberChanged =>
      _groupMemberChangedController.stream;

  // 正在输入事件流
  final StreamController<TypingUpdateEvent> _typingUpdateController =
      StreamController<TypingUpdateEvent>.broadcast();
  Stream<TypingUpdateEvent> get onTypingUpdate => _typingUpdateController.stream;

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

  /// 初始化房间管理器
  void _initRoomManager() {
    _roomManager = RoomSubscriptionManager(
      maxActiveRooms: 20, // 最多保持20个活跃房间
      roomExpirationMinutes: 60, // 1小时后过期
    );

    // 设置订阅/取消订阅回调
    _roomManager.onRoomSubscribe = (roomId) {
      if (_isAuthenticated && !_subscribedRooms.contains(roomId)) {
        _actualJoinRoom(roomId);
      }
    };

    _roomManager.onRoomUnsubscribe = (roomId) {
      if (_subscribedRooms.contains(roomId)) {
        _actualLeaveRoom(roomId);
      }
    };

    _roomManager.init();
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

    // 清理房间管理器
    _roomManager.clearAll();

    _setStatus(ConnectionStatus.disconnected);
  }

  /// 发送认证消息
  Future<void> _authenticate(String token) async {
    final event = ws.ClientEvent(auth: ws.ClientAuth(token: token));
    _sendClientEvent(event);
  }

  /// 加入房间（使用智能管理）
  Future<void> joinRoom(String roomId) async {
    if (roomId.isEmpty) return;

    // 通过房间管理器管理订阅
    _roomManager.markRoomActive(roomId);
    _desiredRooms.add(roomId);

    if (!_isAuthenticated) {
      debugPrint('Defer join until authenticated: $roomId');
      return;
    }

    if (_subscribedRooms.contains(roomId)) {
      debugPrint('Already subscribed to room: $roomId');
      // 即使已订阅，也要更新活跃状态
      _roomManager.markRoomActive(roomId);
      return;
    }

    if (_pendingJoinRooms.contains(roomId)) {
      debugPrint('Join already pending: $roomId');
      return;
    }

    _actualJoinRoom(roomId);
  }

  /// 实际执行加入房间
  void _actualJoinRoom(String roomId) {
    if (!_isAuthenticated || roomId.isEmpty) return;

    final event = ws.ClientEvent(join: ws.ClientJoin(roomId: roomId));
    _pendingJoinRooms.add(roomId);
    _sendClientEvent(event);
    debugPrint(
      'Joining room: $roomId (active rooms: ${_roomManager.getActiveRooms().length})',
    );
  }

  /// 离开房间
  Future<void> leaveRoom(String roomId) async {
    if (roomId.isEmpty) return;

    _desiredRooms.remove(roomId);
    _roomManager.removeRoom(roomId);

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

    _actualLeaveRoom(roomId);
  }

  /// 实际执行离开房间
  void _actualLeaveRoom(String roomId) {
    if (roomId.isEmpty) return;

    final event = ws.ClientEvent(leave: ws.ClientLeave(roomId: roomId));
    _pendingJoinRooms.remove(roomId);
    _sendClientEvent(event);
    debugPrint('Leaving room: $roomId');
  }

  /// 设置正在输入状态（仅已认证且已订阅的房间）
  void setTyping(String roomId, bool isTyping) {
    if (roomId.isEmpty) return;
    if (!_isAuthenticated) return;
    if (!_subscribedRooms.contains(roomId)) return;

    final event = ws.ClientEvent(
      typing: ws.ClientTyping(roomId: roomId, isTyping: isTyping),
    );
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
          updateType: _nullIfEmpty(payload.updateType),
          editedAt: _parseDateTime(_nullIfEmpty(payload.editedAt)),
          content: _nullIfEmpty(payload.content),
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
      case ws.ServerEvent_Payload.reactionUpdate:
        final payload = event.reactionUpdate;
        if (payload.roomId.isEmpty ||
            payload.messageId.isEmpty ||
            payload.reactionKey.isEmpty ||
            payload.userId.isEmpty) {
          return null;
        }
        return _ReactionUpdateEvent(
          roomId: payload.roomId,
          messageId: payload.messageId,
          reactionKey: payload.reactionKey,
          userId: payload.userId,
          action: _nullIfEmpty(payload.action) ?? 'add',
        );
      case ws.ServerEvent_Payload.typingUpdate:
        final payload = event.typingUpdate;
        if (payload.roomId.isEmpty || payload.userId.isEmpty) {
          return null;
        }
        return _TypingUpdateEvent(
          roomId: payload.roomId,
          userId: payload.userId,
          isTyping: payload.isTyping,
          expiresInMs: payload.expiresInMs,
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
      case ws.ServerEvent_Payload.roomUpdated:
        final payload = event.roomUpdated;
        if (payload.roomId.isEmpty) return null;
        return _RoomUpdatedEvent(
          roomId: payload.roomId,
          roomName: payload.roomName,
          roomType: _nullIfEmpty(payload.roomType),
          avatarUrl: _nullIfEmpty(payload.avatarUrl),
          avatarObjectKey: _nullIfEmpty(payload.avatarObjectKey),
          description: _nullIfEmpty(payload.description),
        );
      case ws.ServerEvent_Payload.error:
        return _ErrorEvent(message: event.error.message);
      case ws.ServerEvent_Payload.pong:
        return const _PongEvent();
      case ws.ServerEvent_Payload.userBanned:
        return _UserBannedEvent(
          userId: event.userBanned.userId,
          reason: event.userBanned.reason,
        );
      case ws.ServerEvent_Payload.groupDissolved:
        final roomId = event.groupDissolved.roomId;
        if (roomId.isEmpty) return null;
        return _GroupDissolvedEvent(roomId: roomId);
      case ws.ServerEvent_Payload.groupOwnerTransferred:
        final payload = event.groupOwnerTransferred;
        if (payload.roomId.isEmpty || payload.newOwnerId.isEmpty) {
          return null;
        }
        return _GroupOwnerTransferredEvent(
          roomId: payload.roomId,
          oldOwnerId: _nullIfEmpty(payload.oldOwnerId),
          newOwnerId: payload.newOwnerId,
        );
      case ws.ServerEvent_Payload.groupSettingsUpdated:
        final payload = event.groupSettingsUpdated;
        if (payload.roomId.isEmpty) return null;
        return _GroupSettingsUpdatedEvent(
          roomId: payload.roomId,
          globalMuteEnabled: payload.globalMuteEnabled,
          globalMuteReason: payload.hasGlobalMuteReason() ? payload.globalMuteReason : null,
          globalMuteUntil: payload.hasGlobalMuteUntil() ? payload.globalMuteUntil : null,
          globalMuteSetBy: payload.hasGlobalMuteSetBy() ? payload.globalMuteSetBy : null,
        );
      case ws.ServerEvent_Payload.groupMemberChanged:
        final payload = event.groupMemberChanged;
        if (payload.roomId.isEmpty || payload.memberId.isEmpty || payload.changeType.isEmpty) {
          return null;
        }
        return _GroupMemberChangedEvent(
          roomId: payload.roomId,
          memberId: payload.memberId,
          changeType: payload.changeType,
          newRole: payload.hasNewRole() ? payload.newRole : null,
          operatorId: payload.hasOperatorId() ? payload.operatorId : null,
          reason: payload.hasReason() ? payload.reason : null,
          until: payload.hasUntil() ? payload.until : null,
        );
      case ws.ServerEvent_Payload.friendProfileUpdated:
        final payload = event.friendProfileUpdated;
        final uid = _nullIfEmpty(payload.userId);
        if (uid == null) return null;
        return _FriendProfileUpdatedEvent(
          userId: uid,
          username: _nullIfEmpty(payload.username),
          nickname: _nullIfEmpty(payload.nickname),
          avatarUrl: _nullIfEmpty(payload.avatarUrl),
          avatarObjectKey: _nullIfEmpty(payload.avatarObjectKey),
        );
      case ws.ServerEvent_Payload.roomHistoryCleared:
        final payload = event.roomHistoryCleared;
        if (payload.roomId.isEmpty) return null;
        return _RoomHistoryClearedEvent(
          roomId: payload.roomId,
          clearedBy: _nullIfEmpty(payload.clearedBy),
          clearedAt: _parseDateTime(_nullIfEmpty(payload.clearedAt)),
        );
      case ws.ServerEvent_Payload.friendshipDeleted:
        final payload = event.friendshipDeleted;
        final userId = _nullIfEmpty(payload.userId);
        return _FriendshipDeletedEvent(userId: userId);
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
        final updateType = _nullIfEmpty(message['update_type']?.toString());
        final editedAt = _parseDateTime(message['edited_at']?.toString());
        final content = _nullIfEmpty(message['content']?.toString());
        return _MessageUpdateEvent(
          roomId: roomId,
          messageId: messageId,
          isDeleted: isDeleted,
          deletedAt: deletedAt,
          updateType: updateType,
          editedAt: editedAt,
          content: content,
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
      case 'reaction_update':
      case 'reaction.update':
        final roomId = message['room_id']?.toString() ?? '';
        final messageId = message['message_id']?.toString() ?? '';
        final reactionKey = message['reaction_key']?.toString() ?? '';
        final userId = message['user_id']?.toString() ?? '';
        final action = message['action']?.toString() ?? 'add';
        if (roomId.isEmpty || messageId.isEmpty || reactionKey.isEmpty) {
          return null;
        }
        return _ReactionUpdateEvent(
          roomId: roomId,
          messageId: messageId,
          reactionKey: reactionKey,
          userId: userId,
          action: action,
        );
      case 'typing_update':
      case 'typingupdate':
        final roomId = message['room_id']?.toString() ?? '';
        final userId = message['user_id']?.toString() ?? '';
        if (roomId.isEmpty || userId.isEmpty) return null;
        final rawTyping = message['is_typing'];
        final isTyping = rawTyping is bool
            ? rawTyping
            : rawTyping?.toString().toLowerCase() == 'true';
        final rawExpires = message['expires_in_ms'];
        final expiresInMs = rawExpires is num
            ? rawExpires.toInt()
            : int.tryParse(rawExpires?.toString() ?? '') ?? 0;
        return _TypingUpdateEvent(
          roomId: roomId,
          userId: userId,
          isTyping: isTyping,
          expiresInMs: expiresInMs,
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
      case 'room_updated':
      case 'room.updated':
        final roomId = message['room_id']?.toString() ?? '';
        if (roomId.isEmpty) return null;
        return _RoomUpdatedEvent(
          roomId: roomId,
          roomName: message['room_name']?.toString() ?? '',
          roomType: _nullIfEmpty(message['room_type']?.toString()),
          avatarUrl: _nullIfEmpty(message['avatar_url']?.toString()),
          avatarObjectKey: _nullIfEmpty(
            message['avatar_object_key']?.toString(),
          ),
          description: _nullIfEmpty(message['description']?.toString()),
        );
      case 'room_history_cleared':
      case 'roomhistorycleared':
        final roomId = message['room_id']?.toString() ?? '';
        if (roomId.isEmpty) return null;
        return _RoomHistoryClearedEvent(
          roomId: roomId,
          clearedBy: _nullIfEmpty(message['cleared_by']?.toString()),
          clearedAt: _parseDateTime(message['cleared_at']?.toString()),
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
      case 'user_banned':
        final userId = message['user_id']?.toString() ?? '';
        final reason = message['reason']?.toString() ?? '管理员封禁';
        return _UserBannedEvent(userId: userId, reason: reason);
      case 'group_dissolved':
      case 'groupdissolved':
        final roomId = message['room_id']?.toString() ?? '';
        if (roomId.isEmpty) return null;
        return _GroupDissolvedEvent(roomId: roomId);
      case 'group_owner_transferred':
      case 'groupownertransferred':
        final roomId = message['room_id']?.toString() ?? '';
        final newOwnerId = message['new_owner_id']?.toString() ?? '';
        if (roomId.isEmpty || newOwnerId.isEmpty) return null;
        final oldOwnerId = _nullIfEmpty(message['old_owner_id']?.toString());
        return _GroupOwnerTransferredEvent(
          roomId: roomId,
          oldOwnerId: oldOwnerId,
          newOwnerId: newOwnerId,
        );
      case 'group_settings_updated':
      case 'groupsettingsupdated':
        final roomId = message['room_id']?.toString() ?? '';
        if (roomId.isEmpty) return null;
        final rawEnabled = message['global_mute_enabled'];
        final enabled = rawEnabled is bool
            ? rawEnabled
            : rawEnabled?.toString().toLowerCase() == 'true';
        return _GroupSettingsUpdatedEvent(
          roomId: roomId,
          globalMuteEnabled: enabled,
          globalMuteReason: _nullIfEmpty(message['global_mute_reason']?.toString()),
          globalMuteUntil: _nullIfEmpty(message['global_mute_until']?.toString()),
          globalMuteSetBy: _nullIfEmpty(message['global_mute_set_by']?.toString()),
        );
      case 'group_member_changed':
      case 'groupmemberchanged':
        final roomId = message['room_id']?.toString() ?? '';
        final memberId = message['member_id']?.toString() ?? '';
        final changeType = message['change_type']?.toString() ?? '';
        if (roomId.isEmpty || memberId.isEmpty || changeType.isEmpty) return null;
        return _GroupMemberChangedEvent(
          roomId: roomId,
          memberId: memberId,
          changeType: changeType,
          newRole: _nullIfEmpty(message['new_role']?.toString()),
          operatorId: _nullIfEmpty(message['operator_id']?.toString()),
          reason: _nullIfEmpty(message['reason']?.toString()),
          until: _nullIfEmpty(message['until']?.toString()),
        );
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
    } else if (event is _ReactionUpdateEvent) {
      _handleReactionUpdate(event);
    } else if (event is _TypingUpdateEvent) {
      _handleTypingUpdate(event);
    } else if (event is _FriendRequestUpdateEvent) {
      _handleFriendRequestUpdate(event);
    } else if (event is _RoomCreatedEvent) {
      _handleRoomCreated(event);
    } else if (event is _RoomUpdatedEvent) {
      _handleRoomUpdated(event);
    } else if (event is _RoomHistoryClearedEvent) {
      _handleRoomHistoryCleared(event);
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
    } else if (event is _UserBannedEvent) {
      _handleUserBanned(event);
    } else if (event is _GroupDissolvedEvent) {
      _handleGroupDissolved(event);
    } else if (event is _GroupOwnerTransferredEvent) {
      _handleGroupOwnerTransferred(event);
    } else if (event is _GroupSettingsUpdatedEvent) {
      _handleGroupSettingsUpdated(event);
    } else if (event is _GroupMemberChangedEvent) {
      _handleGroupMemberChanged(event);
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

    // 清空已订阅状态，准备重新加入
    _subscribedRooms.clear();
    _pendingJoinRooms.clear();

    // 重新加入所有 desiredRooms 中的房间
    if (_desiredRooms.isNotEmpty) {
      for (final roomId in _desiredRooms) {
        if (roomId.isNotEmpty) {
          final joinEvent = ws.ClientEvent(
            join: ws.ClientJoin(roomId: roomId),
          );
          _pendingJoinRooms.add(roomId);
          _sendClientEvent(joinEvent);
        }
      }
      debugPrint('Rejoining ${_desiredRooms.length} rooms after auth');
    }

    // 认证成功后刷新：
    // 1) 会话列表，确保聊天页立即展示数据
    unawaited(() async {
      try {
        await _messageService.fetchChats();
      } catch (e) {
        debugPrint('Failed to fetch chats after auth: $e');
      }
      await _messageService.syncOfflineMessages();
    }());
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
        updateType: event.updateType,
        editedAt: event.editedAt,
        content: event.content,
      ),
    );
  }

  void _handleReactionUpdate(_ReactionUpdateEvent event) {
    unawaited(
      _messageService.handleReactionUpdate(
        roomId: event.roomId,
        messageId: event.messageId,
        reactionKey: event.reactionKey,
        userId: event.userId,
        action: event.action,
      ),
    );
  }

  void _handleTypingUpdate(_TypingUpdateEvent event) {
    _typingUpdateController.add(
      TypingUpdateEvent(
        roomId: event.roomId,
        userId: event.userId,
        isTyping: event.isTyping,
        expiresInMs: event.expiresInMs,
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
      avatarObjectKey: event.avatarObjectKey,
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

  void _handleRoomUpdated(_RoomUpdatedEvent event) {
    final roomId = event.roomId;
    if (roomId.isEmpty) return;

    // 群信息更新属于“系统提示”，不归属于普通文字消息
    final chatsSnapshot = _messageService.chats;
    final currentChatIndex = chatsSnapshot.indexWhere((c) => c.roomId == roomId);
    final currentChat =
        currentChatIndex >= 0 ? chatsSnapshot[currentChatIndex] : null;

    final changes = <String>[];

    final newAvatarKey = event.avatarObjectKey;
    if (newAvatarKey != null && newAvatarKey.isNotEmpty) {
      final oldAvatarKey = currentChat?.avatarObjectKey;
      if (oldAvatarKey == null || oldAvatarKey != newAvatarKey) {
        changes.add('群头像已更新');
      }
    }

    final newRoomName = event.roomName.trim();
    if (newRoomName.isNotEmpty) {
      final oldRoomName = currentChat?.name.trim();
      if (oldRoomName == null || oldRoomName != newRoomName) {
        changes.add('群名称已改为“$newRoomName”');
      }
    }

    if (changes.isNotEmpty) {
      _messageService.insertSystemMessage(
        roomId: roomId,
        content: changes.join('，'),
      );
    }

    _messageService.ensureRoomPlaceholder(
      roomId: roomId,
      name: event.roomName,
      roomType: event.roomType,
      avatarUrl: event.avatarUrl,
      description: event.description,
    );

    if (event.avatarObjectKey != null && event.avatarObjectKey!.isNotEmpty) {
      _messageService.updateRoomAvatar(
        roomId: roomId,
        avatarObjectKey: event.avatarObjectKey!,
        localAvatarPath: null,
      );
    }

    // 轻量强制刷新会话列表，确保其他字段也同步
    unawaited(_messageService.fetchChats(force: true));
  }

  void _handleRoomHistoryCleared(_RoomHistoryClearedEvent event) {
    final roomId = event.roomId;
    if (roomId.isEmpty) return;
    _messageService.clearRoomMessages(roomId);
    unawaited(_messageService.fetchChats(force: true));
  }

  /// 处理服务器错误
  void _handleServerError(String message) {
    debugPrint('Server error: $message');
  }

  /// 处理用户封禁事件
  void _handleUserBanned(_UserBannedEvent event) {
    debugPrint('User banned: ${event.userId}, reason: ${event.reason}');

    // 获取当前用户信息
    unawaited(() async {
      try {
        final session = await _tokenStorage.readSession();
        if (session != null && session.user.id == event.userId) {
          // 当前用户被封禁，清除token并断开连接
          debugPrint('Current user banned, logging out...');
          await _tokenStorage.clear();
          await disconnect();

          // 广播全局认证状态，触发导航回登录页
          AuthStateBus.emit(AuthState.unauthenticated);

          // 通知应用跳转到登录页面
          // 这里可以通过事件总线或其他方式通知应用
          debugPrint('User banned notification sent');
        }
      } catch (e) {
        debugPrint('Error handling user banned event: $e');
      }
    }());
  }

  void _handleGroupDissolved(_GroupDissolvedEvent event) {
    debugPrint('Group dissolved: ${event.roomId}');
    unawaited(_messageService.handleGroupDissolved(event.roomId));
    unawaited(leaveRoom(event.roomId));
  }

  void _handleGroupOwnerTransferred(_GroupOwnerTransferredEvent event) {
    debugPrint(
      'Group owner transferred: ${event.roomId} -> ${event.newOwnerId}',
    );
    unawaited(
      _messageService.handleGroupOwnerTransferred(
        event.roomId,
        event.newOwnerId,
      ),
    );
  }

  void _handleGroupSettingsUpdated(_GroupSettingsUpdatedEvent event) {
    debugPrint(
      'Group settings updated: ${event.roomId}, mute=${event.globalMuteEnabled}',
    );
    // 发送到公开的事件流，让页面可以监听
    _groupSettingsUpdatedController.add(GroupSettingsUpdatedEvent(
      roomId: event.roomId,
      globalMuteEnabled: event.globalMuteEnabled,
      globalMuteReason: event.globalMuteReason,
      globalMuteUntil: event.globalMuteUntil,
      globalMuteSetBy: event.globalMuteSetBy,
    ));
  }

  void _handleGroupMemberChanged(_GroupMemberChangedEvent event) {
    debugPrint(
      'Group member changed: ${event.roomId}, member=${event.memberId}, type=${event.changeType}',
    );
    // 发送到公开的事件流，让页面可以监听
    _groupMemberChangedController.add(GroupMemberChangedEvent(
      roomId: event.roomId,
      memberId: event.memberId,
      changeType: event.changeType,
      newRole: event.newRole,
      operatorId: event.operatorId,
      reason: event.reason,
      until: event.until,
    ));
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
    _roomManager.dispose();
    _groupSettingsUpdatedController.close();
    _groupMemberChangedController.close();
    _typingUpdateController.close();
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
  final List<WebSocketMessagePart> parts;

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
    required this.parts,
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

    final parts = <WebSocketMessagePart>[];
    final rawParts = json['parts'];
    if (rawParts is List) {
      for (final item in rawParts) {
        if (item is Map<String, dynamic>) {
          parts.add(WebSocketMessagePart.fromJson(item));
        } else if (item is Map) {
          final normalized = <String, dynamic>{};
          item.forEach((key, value) {
            normalized[key.toString()] = value;
          });
          parts.add(WebSocketMessagePart.fromJson(normalized));
        }
      }
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
      parts: parts,
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

    // 解析消息 parts（附件等）
    final parts = <WebSocketMessagePart>[];
    for (final part in proto.parts) {
      parts.add(WebSocketMessagePart.fromProto(part));
    }

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
      parts: parts,
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

class WebSocketMessagePart {
  WebSocketMessagePart({
    required this.position,
    required this.partType,
    this.text,
    this.attachment,
  });

  final int position;
  final String partType;
  final String? text;
  final WebSocketMessageAttachment? attachment;

  factory WebSocketMessagePart.fromJson(Map<String, dynamic> json) {
    int parseInt(dynamic value, {int defaultValue = 0}) {
      if (value is int) return value;
      if (value is num) return value.toInt();
      if (value is String) {
        final parsed = int.tryParse(value);
        if (parsed != null) return parsed;
      }
      return defaultValue;
    }

    WebSocketMessageAttachment? attachment;
    final attachmentRaw = json['attachment'];
    if (attachmentRaw is Map<String, dynamic>) {
      attachment = WebSocketMessageAttachment.fromJson(attachmentRaw);
    } else if (attachmentRaw is Map) {
      final normalized = <String, dynamic>{};
      attachmentRaw.forEach((key, value) {
        normalized[key.toString()] = value;
      });
      attachment = WebSocketMessageAttachment.fromJson(normalized);
    }

    return WebSocketMessagePart(
      position: parseInt(json['position']),
      partType:
          json['part_type']?.toString() ?? json['type']?.toString() ?? 'text',
      text: json['text']?.toString(),
      attachment: attachment,
    );
  }

  factory WebSocketMessagePart.fromProto(ws.MessagePart proto) {
    WebSocketMessageAttachment? attachment;
    if (proto.hasAttachment() && proto.attachment.key.isNotEmpty) {
      attachment = WebSocketMessageAttachment.fromProto(proto.attachment);
    }

    return WebSocketMessagePart(
      position: proto.position,
      partType: proto.partType.isNotEmpty ? proto.partType : 'text',
      text: _asOptionalString(proto.text),
      attachment: attachment,
    );
  }
}

class WebSocketMessageAttachment {
  WebSocketMessageAttachment({
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

  factory WebSocketMessageAttachment.fromJson(Map<String, dynamic> json) {
    int? parseInt(dynamic value) {
      if (value is int) return value;
      if (value is num) return value.toInt();
      if (value is String) return int.tryParse(value);
      return null;
    }

    return WebSocketMessageAttachment(
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

  factory WebSocketMessageAttachment.fromProto(ws.MessageAttachment proto) {
    return WebSocketMessageAttachment(
      key: proto.key,
      name: _asOptionalString(proto.name),
      mime: _asOptionalString(proto.mime),
      size: proto.size.toInt(),
      width: proto.width > 0 ? proto.width : null,
      height: proto.height > 0 ? proto.height : null,
      durationMs: proto.durationMs > 0 ? proto.durationMs : null,
      thumbnailKey: _asOptionalString(proto.thumbnailKey),
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
    this.parts = const [],
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
  final List<WebSocketMessagePart> parts;

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

    // 解析 parts
    final parts = <WebSocketMessagePart>[];
    final rawParts = json['parts'];
    if (rawParts is List) {
      for (final item in rawParts) {
        if (item is Map<String, dynamic>) {
          parts.add(WebSocketMessagePart.fromJson(item));
        } else if (item is Map) {
          final normalized = <String, dynamic>{};
          item.forEach((key, value) {
            normalized[key.toString()] = value;
          });
          parts.add(WebSocketMessagePart.fromJson(normalized));
        }
      }
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
      parts: parts,
    );
  }

  factory WebSocketQuotedMessage.fromProto(ws.QuotedMessage proto) {
    // 解析 parts
    final parts = <WebSocketMessagePart>[];
    for (final part in proto.parts) {
      parts.add(WebSocketMessagePart.fromProto(part));
    }

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
      parts: parts,
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
    this.updateType,
    this.editedAt,
    this.content,
  });
  final String roomId;
  final String messageId;
  final bool isDeleted;
  final DateTime? deletedAt;
  final String? updateType;
  final DateTime? editedAt;
  final String? content;
}

class _ReactionUpdateEvent extends _WsEvent {
  const _ReactionUpdateEvent({
    required this.roomId,
    required this.messageId,
    required this.reactionKey,
    required this.userId,
    required this.action,
  });
  final String roomId;
  final String messageId;
  final String reactionKey;
  final String userId;
  final String action; // "add" | "remove"
}

class _TypingUpdateEvent extends _WsEvent {
  const _TypingUpdateEvent({
    required this.roomId,
    required this.userId,
    required this.isTyping,
    required this.expiresInMs,
  });

  final String roomId;
  final String userId;
  final bool isTyping;
  final int expiresInMs;
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

class _RoomUpdatedEvent extends _WsEvent {
  const _RoomUpdatedEvent({
    required this.roomId,
    required this.roomName,
    this.roomType,
    this.avatarUrl,
    this.avatarObjectKey,
    this.description,
  });

  final String roomId;
  final String roomName;
  final String? roomType;
  final String? avatarUrl;
  final String? avatarObjectKey;
  final String? description;
}

class _RoomHistoryClearedEvent extends _WsEvent {
  const _RoomHistoryClearedEvent({
    required this.roomId,
    this.clearedBy,
    this.clearedAt,
  });

  final String roomId;
  final String? clearedBy;
  final DateTime? clearedAt;
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
    this.avatarObjectKey,
  });
  final String? userId;
  final String? username;
  final String? nickname;
  final String? avatarUrl;
  final String? avatarObjectKey;
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

class _UserBannedEvent extends _WsEvent {
  const _UserBannedEvent({required this.userId, required this.reason});
  final String userId;
  final String reason;
}

class _GroupDissolvedEvent extends _WsEvent {
  const _GroupDissolvedEvent({required this.roomId});
  final String roomId;
}

class _GroupOwnerTransferredEvent extends _WsEvent {
  const _GroupOwnerTransferredEvent({
    required this.roomId,
    required this.newOwnerId,
    this.oldOwnerId,
  });

  final String roomId;
  final String newOwnerId;
  final String? oldOwnerId;
}

class _GroupSettingsUpdatedEvent extends _WsEvent {
  const _GroupSettingsUpdatedEvent({
    required this.roomId,
    required this.globalMuteEnabled,
    this.globalMuteReason,
    this.globalMuteUntil,
    this.globalMuteSetBy,
  });

  final String roomId;
  final bool globalMuteEnabled;
  final String? globalMuteReason;
  final String? globalMuteUntil;
  final String? globalMuteSetBy;
}

class _GroupMemberChangedEvent extends _WsEvent {
  const _GroupMemberChangedEvent({
    required this.roomId,
    required this.memberId,
    required this.changeType,
    this.newRole,
    this.operatorId,
    this.reason,
    this.until,
  });

  final String roomId;
  final String memberId;
  final String changeType;
  final String? newRole;
  final String? operatorId;
  final String? reason;
  final String? until;
}
