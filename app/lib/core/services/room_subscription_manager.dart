import 'dart:async';
import 'dart:collection';
import 'package:flutter/foundation.dart';

/// 房间订阅管理器 - 使用 LRU 策略管理活跃房间
class RoomSubscriptionManager {
  RoomSubscriptionManager({
    this.maxActiveRooms = 20,
    this.roomExpirationMinutes = 60,
  });

  /// 最大活跃房间数
  final int maxActiveRooms;

  /// 房间过期时间（分钟）
  final int roomExpirationMinutes;

  /// 活跃房间队列（LRU）
  final LinkedHashMap<String, DateTime> _activeRooms = LinkedHashMap();

  /// 房间订阅回调
  Function(String roomId)? onRoomSubscribe;
  Function(String roomId)? onRoomUnsubscribe;

  /// 定期清理定时器
  Timer? _cleanupTimer;

  /// 初始化
  void init() {
    // 每 10 分钟清理一次过期房间
    _cleanupTimer?.cancel();
    _cleanupTimer = Timer.periodic(
      const Duration(minutes: 10),
      (_) => _cleanupExpiredRooms(),
    );
  }

  /// 标记房间为活跃
  void markRoomActive(String roomId) {
    if (roomId.isEmpty) return;

    // 如果房间已存在，移到队尾（最近使用）
    if (_activeRooms.containsKey(roomId)) {
      _activeRooms.remove(roomId);
    }

    // 添加到队尾
    _activeRooms[roomId] = DateTime.now();

    // 如果超过最大数量，移除最旧的房间
    if (_activeRooms.length > maxActiveRooms) {
      final oldestRoom = _activeRooms.keys.first;
      _removeRoom(oldestRoom);
      debugPrint('LRU evicted room: $oldestRoom');
    }

    // 触发订阅回调
    onRoomSubscribe?.call(roomId);
  }

  /// 检查房间是否活跃
  bool isRoomActive(String roomId) {
    if (!_activeRooms.containsKey(roomId)) {
      return false;
    }

    final lastActive = _activeRooms[roomId]!;
    final now = DateTime.now();
    final expiration = Duration(minutes: roomExpirationMinutes);

    // 检查是否过期
    if (now.difference(lastActive) > expiration) {
      _removeRoom(roomId);
      return false;
    }

    return true;
  }

  /// 获取所有活跃房间
  List<String> getActiveRooms() {
    _cleanupExpiredRooms();
    return _activeRooms.keys.toList();
  }

  /// 获取最近活跃的房间（指定数量）
  List<String> getRecentRooms(int count) {
    _cleanupExpiredRooms();
    final rooms = _activeRooms.keys.toList();

    // 返回最后 N 个房间（最近使用的）
    if (rooms.length <= count) {
      return rooms;
    }

    return rooms.sublist(rooms.length - count);
  }

  /// 手动移除房间
  void removeRoom(String roomId) {
    _removeRoom(roomId);
  }

  /// 清空所有房间
  void clearAll() {
    final rooms = _activeRooms.keys.toList();
    for (final roomId in rooms) {
      onRoomUnsubscribe?.call(roomId);
    }
    _activeRooms.clear();
  }

  /// 内部移除房间
  void _removeRoom(String roomId) {
    if (_activeRooms.remove(roomId) != null) {
      onRoomUnsubscribe?.call(roomId);
      debugPrint('Room unsubscribed: $roomId');
    }
  }

  /// 清理过期房间
  void _cleanupExpiredRooms() {
    final now = DateTime.now();
    final expiration = Duration(minutes: roomExpirationMinutes);
    final expiredRooms = <String>[];

    _activeRooms.forEach((roomId, lastActive) {
      if (now.difference(lastActive) > expiration) {
        expiredRooms.add(roomId);
      }
    });

    for (final roomId in expiredRooms) {
      _removeRoom(roomId);
      debugPrint('Room expired and removed: $roomId');
    }
  }

  /// 销毁
  void dispose() {
    _cleanupTimer?.cancel();
    clearAll();
  }

  /// 获取统计信息
  Map<String, dynamic> getStats() {
    return {
      'activeRooms': _activeRooms.length,
      'maxActiveRooms': maxActiveRooms,
      'roomExpirationMinutes': roomExpirationMinutes,
      'oldestRoom': _activeRooms.isNotEmpty ? _activeRooms.keys.first : null,
      'newestRoom': _activeRooms.isNotEmpty ? _activeRooms.keys.last : null,
    };
  }
}
