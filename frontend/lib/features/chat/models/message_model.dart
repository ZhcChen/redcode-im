import '../../../core/services/message_service.dart';

/// 消息类型
enum MessageType { text, image, voice, video, file, system }

/// 消息模型
class Message {
  final String id;
  final String roomId;
  final String senderId;
  final String senderUsername;
  final String senderName;
  final String? senderAvatar;
  final String content;
  final MessageType type;
  final MessageStatus status;
  final DateTime timestamp;
  final bool isSelf;
  final Map<String, dynamic>? extra;

  Message({
    required this.id,
    required this.roomId,
    required this.senderId,
    required this.senderUsername,
    required this.senderName,
    this.senderAvatar,
    required this.content,
    required this.type,
    required this.status,
    required this.timestamp,
    required this.isSelf,
    this.extra,
  });

  /// 复制并修改部分字段
  Message copyWith({
    String? id,
    String? roomId,
    String? senderId,
    String? senderUsername,
    String? senderName,
    String? senderAvatar,
    String? content,
    MessageType? type,
    MessageStatus? status,
    DateTime? timestamp,
    bool? isSelf,
    Map<String, dynamic>? extra,
  }) {
    return Message(
      id: id ?? this.id,
      roomId: roomId ?? this.roomId,
      senderId: senderId ?? this.senderId,
      senderUsername: senderUsername ?? this.senderUsername,
      senderName: senderName ?? this.senderName,
      senderAvatar: senderAvatar ?? this.senderAvatar,
      content: content ?? this.content,
      type: type ?? this.type,
      status: status ?? this.status,
      timestamp: timestamp ?? this.timestamp,
      isSelf: isSelf ?? this.isSelf,
      extra: extra ?? this.extra,
    );
  }

  /// 获取显示时间
  String get displayTime {
    final now = DateTime.now();
    final local = timestamp.toLocal();
    final isSameDay =
        now.year == local.year &&
        now.month == local.month &&
        now.day == local.day;

    if (isSameDay) {
      return '';
    }

    final isSameYear = now.year == local.year;
    if (isSameYear) {
      return '${local.month}月${local.day}日';
    }

    return '${local.year}年${local.month}月${local.day}日';
  }

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  /// 是否显示时间戳
  bool shouldShowTimestamp(Message? previousMessage) {
    if (previousMessage == null) return true;

    final diff = timestamp.difference(previousMessage.timestamp);
    return diff.inMinutes >= 5;
  }

  /// 是否显示头像
  bool shouldShowAvatar(Message? nextMessage) {
    if (nextMessage == null) return true;
    if (nextMessage.senderId != senderId) return true;

    final diff = nextMessage.timestamp.difference(timestamp);
    return diff.inMinutes >= 5;
  }

  /// 展示名称（备注 > 昵称 > 用户名 > ID）
  String get displaySenderName {
    final fromExtra = _readExtraString(extra, const [
      'remark',
      'friend_remark',
      'friendRemark',
      'friend_nickname',
      'friendNickname',
      'sender_remark',
      'senderRemark',
      'sender_display_name',
      'senderDisplayName',
      'sender_nickname',
      'senderNickname',
      'nickname',
      'display_name',
      'displayName',
    ]);
    if (fromExtra != null && fromExtra.isNotEmpty) {
      return fromExtra;
    }
    if (senderName.trim().isNotEmpty) return senderName.trim();
    if (senderUsername.trim().isNotEmpty) return senderUsername.trim();
    return senderId;
  }

  Map<String, dynamic> toCacheJson() {
    return {
      'id': id,
      'roomId': roomId,
      'senderId': senderId,
      'senderUsername': senderUsername,
      'senderName': senderName,
      'senderAvatar': senderAvatar,
      'content': content,
      'type': type.name,
      'status': status.name,
      'timestamp': timestamp.toIso8601String(),
      'isSelf': isSelf,
      'extra': extra,
    };
  }

  factory Message.fromCacheJson(Map<String, dynamic> json) {
    final typeString = json['type'] as String?;
    final statusString = json['status'] as String?;
    final timestampString = json['timestamp'] as String?;
    final extraRaw = json['extra'];
    Map<String, dynamic>? extra;
    if (extraRaw is Map) {
      final map = <String, dynamic>{};
      extraRaw.forEach((key, value) {
        map[key.toString()] = value;
      });
      extra = map;
    }

    return Message(
      id: json['id'] as String? ?? '',
      roomId: json['roomId'] as String? ?? '',
      senderId: json['senderId'] as String? ?? '',
      senderUsername: json['senderUsername'] as String? ?? '',
      senderName: json['senderName'] as String? ?? '',
      senderAvatar: json['senderAvatar'] as String?,
      content: json['content'] as String? ?? '',
      type: _parseMessageType(typeString),
      status: _parseMessageStatus(statusString),
      timestamp:
          DateTime.tryParse(timestampString ?? '') ?? DateTime.now(),
      isSelf: json['isSelf'] as bool? ?? false,
      extra: extra,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Message && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  static String? _readExtraString(
    Map<String, dynamic>? map,
    List<String> keys,
  ) {
    if (map == null || map.isEmpty) return null;
    for (final key in keys) {
      if (!map.containsKey(key)) continue;
      final value = map[key];
      if (value == null) continue;
      if (value is String && value.trim().isNotEmpty) {
        return value.trim();
      }
      if (value is num || value is bool) {
        return value.toString();
      }
    }
    return null;
  }

  static MessageType _parseMessageType(String? value) {
    if (value == null) return MessageType.text;
    return MessageType.values.firstWhere(
      (type) => type.name == value,
      orElse: () => MessageType.text,
    );
  }

  static MessageStatus _parseMessageStatus(String? value) {
    if (value == null) return MessageStatus.sent;
    return MessageStatus.values.firstWhere(
      (status) => status.name == value,
      orElse: () => MessageStatus.sent,
    );
  }
}
