import '../../../core/services/message_service.dart';

/// 消息类型
enum MessageType { text, image, voice, video, file, system }

/// 引用消息模型
class QuotedMessage {
  QuotedMessage({
    required this.id,
    required this.roomId,
    required this.senderId,
    required this.senderUsername,
    required this.senderName,
    this.senderAvatar,
    this.content,
    required this.type,
    this.createdAt,
    required this.isDeleted,
  });

  final String id;
  final String roomId;
  final String senderId;
  final String senderUsername;
  final String senderName;
  final String? senderAvatar;
  final String? content;
  final MessageType type;
  final DateTime? createdAt;
  final bool isDeleted;

  factory QuotedMessage.fromCacheJson(Map<String, dynamic> json) {
    return QuotedMessage(
      id: json['id'] as String? ?? '',
      roomId: json['roomId'] as String? ?? '',
      senderId: json['senderId'] as String? ?? '',
      senderUsername: json['senderUsername'] as String? ?? '',
      senderName: json['senderName'] as String? ?? '',
      senderAvatar: json['senderAvatar'] as String?,
      content: json['content'] as String?,
      type: Message._parseMessageType(json['type'] as String?),
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? ''),
      isDeleted: json['isDeleted'] as bool? ?? false,
    );
  }

  factory QuotedMessage.fromMessage(Message message) {
    return QuotedMessage(
      id: message.id,
      roomId: message.roomId,
      senderId: message.senderId,
      senderUsername: message.senderUsername,
      senderName: message.displaySenderName,
      senderAvatar: message.senderAvatar,
      content: message.type == MessageType.text ? message.content : null,
      type: message.type,
      createdAt: message.timestamp,
      isDeleted: false,
    );
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
      'createdAt': createdAt?.toIso8601String(),
      'isDeleted': isDeleted,
    };
  }

  String get displaySenderName {
    if (senderName.trim().isNotEmpty) {
      return senderName.trim();
    }
    if (senderUsername.trim().isNotEmpty) {
      return senderUsername.trim();
    }
    return senderId;
  }

  String get previewText {
    if (isDeleted) {
      return '引用的消息已删除';
    }

    final normalized = content?.trim();
    if (normalized != null && normalized.isNotEmpty) {
      return normalized.replaceAll(RegExp(r'\s+'), ' ');
    }

    switch (type) {
      case MessageType.image:
        return '[图片]';
      case MessageType.voice:
        return '[语音]';
      case MessageType.video:
        return '[视频]';
      case MessageType.file:
        return '[文件]';
      case MessageType.system:
        return '[系统消息]';
      case MessageType.text:
        return '[消息]';
    }
  }
}

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
  final QuotedMessage? quotedMessage;

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
    this.quotedMessage,
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
    QuotedMessage? quotedMessage,
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
      quotedMessage: quotedMessage ?? this.quotedMessage,
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
      'quoted': quotedMessage?.toCacheJson(),
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
      timestamp: DateTime.tryParse(timestampString ?? '') ?? DateTime.now(),
      isSelf: json['isSelf'] as bool? ?? false,
      extra: extra,
      quotedMessage: _parseQuotedFromCache(json['quoted']),
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

  static QuotedMessage? _parseQuotedFromCache(dynamic raw) {
    if (raw == null) return null;
    if (raw is QuotedMessage) return raw;
    if (raw is Map<String, dynamic>) {
      return QuotedMessage.fromCacheJson(raw);
    }
    if (raw is Map) {
      final map = <String, dynamic>{};
      raw.forEach((key, value) {
        map[key.toString()] = value;
      });
      return QuotedMessage.fromCacheJson(map);
    }
    return null;
  }
}
