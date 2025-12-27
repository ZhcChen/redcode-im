import '../../../core/services/message_service.dart';

const Object _unset = Object();

/// 消息类型
enum MessageType { text, image, audio, video, file, system, mixed }

/// 转发来源类型
enum ForwardSourceType { user, group, favorite, unknown }

/// 转发信息
class ForwardInfo {
  ForwardInfo({
    required this.sourceType,
    required this.sourceId,
    required this.sourceName,
    this.sourceAvatar,
    this.originMessageId,
    this.originRoomId,
    this.originSenderId,
    this.originSenderName,
  });

  final ForwardSourceType sourceType;
  final String sourceId;
  final String sourceName;
  final String? sourceAvatar;
  final String? originMessageId;
  final String? originRoomId;
  final String? originSenderId;
  final String? originSenderName;

  factory ForwardInfo.fromCacheJson(Map<String, dynamic> json) {
    return ForwardInfo(
      sourceType: _parseSourceType(json['sourceType'] as String?),
      sourceId: json['sourceId'] as String? ?? '',
      sourceName: json['sourceName'] as String? ?? '',
      sourceAvatar: json['sourceAvatar'] as String?,
      originMessageId: json['originMessageId'] as String?,
      originRoomId: json['originRoomId'] as String?,
      originSenderId: json['originSenderId'] as String?,
      originSenderName: json['originSenderName'] as String?,
    );
  }

  Map<String, dynamic> toCacheJson() {
    return {
      'sourceType': sourceType.name,
      'sourceId': sourceId,
      'sourceName': sourceName,
      'sourceAvatar': sourceAvatar,
      'originMessageId': originMessageId,
      'originRoomId': originRoomId,
      'originSenderId': originSenderId,
      'originSenderName': originSenderName,
    };
  }

  String get displaySourceName {
    if (sourceName.trim().isNotEmpty) {
      return sourceName.trim();
    }
    if (sourceId.trim().isNotEmpty) {
      return sourceId.trim();
    }
    return '未知来源';
  }

  static ForwardSourceType _parseSourceType(String? raw) {
    switch ((raw ?? '').toLowerCase()) {
      case 'user':
      case 'single':
        return ForwardSourceType.user;
      case 'group':
        return ForwardSourceType.group;
      case 'favorite':
        return ForwardSourceType.favorite;
      default:
        return ForwardSourceType.unknown;
    }
  }
}

/// 引用消息模型
class QuotedMessage {
  QuotedMessage({
    required this.id,
    required this.roomId,
    required this.senderId,
    required this.senderUsername,
    required this.senderName,
    this.senderAvatar,
    this.senderAvatarObjectKey,
    this.content,
    required this.type,
    this.createdAt,
    required this.isDeleted,
    this.parts = const [],
  });

  final String id;
  final String roomId;
  final String senderId;
  final String senderUsername;
  final String senderName;
  final String? senderAvatar;
  final String? senderAvatarObjectKey;
  final String? content;
  final MessageType type;
  final DateTime? createdAt;
  final bool isDeleted;
  final List<MessagePart> parts;

  factory QuotedMessage.fromCacheJson(Map<String, dynamic> json) {
    // 解析 parts
    final partsRaw = json['parts'];
    List<MessagePart> parts = [];
    if (partsRaw is List) {
      parts = partsRaw.map((p) {
        if (p is Map<String, dynamic>) {
          return MessagePart.fromCacheJson(p);
        } else if (p is Map) {
          final normalized = <String, dynamic>{};
          p.forEach((key, value) {
            normalized[key.toString()] = value;
          });
          return MessagePart.fromCacheJson(normalized);
        }
        return MessagePart(position: 0, type: MessagePartType.text);
      }).toList();
    }

    return QuotedMessage(
      id: json['id'] as String? ?? '',
      roomId: json['roomId'] as String? ?? '',
      senderId: json['senderId'] as String? ?? '',
      senderUsername: json['senderUsername'] as String? ?? '',
      senderName: json['senderName'] as String? ?? '',
      senderAvatar: json['senderAvatar'] as String?,
      senderAvatarObjectKey: json['senderAvatarObjectKey'] as String?,
      content: json['content'] as String?,
      type: Message._parseMessageType(json['type'] as String?),
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? ''),
      isDeleted: json['isDeleted'] as bool? ?? false,
      parts: parts,
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
      senderAvatarObjectKey: message.senderAvatarObjectKey,
      content: message.type == MessageType.text ? message.content : null,
      type: message.type,
      createdAt: message.timestamp,
      isDeleted: false,
      parts: message.parts,
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
      'senderAvatarObjectKey': senderAvatarObjectKey,
      'content': content,
      'type': type.name,
      'createdAt': createdAt?.toIso8601String(),
      'isDeleted': isDeleted,
      if (parts.isNotEmpty) 'parts': parts.map((p) => p.toCacheJson()).toList(),
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
      case MessageType.audio:
        return '[语音]';
      case MessageType.video:
        return '[视频]';
      case MessageType.file:
        return '[文件]';
      case MessageType.system:
        return '[系统消息]';
      case MessageType.mixed:
        return '[多媒体消息]';
      case MessageType.text:
        return '[消息]';
    }
  }

  /// 获取图片附件（如果有）
  MessageAttachment? get imageAttachment {
    if (type != MessageType.image) return null;
    for (final part in parts) {
      if (part.type == MessagePartType.image && part.attachment != null) {
        return part.attachment;
      }
    }
    return null;
  }
}

/// 消息反应聚合结果
class MessageReactionSummary {
  MessageReactionSummary({
    required this.reactionKey,
    required this.count,
    required this.userIds,
    required this.hasSelf,
  });

  final String reactionKey;
  final int count;
  final List<String> userIds;
  final bool hasSelf;

  factory MessageReactionSummary.fromJson(Map<String, dynamic> json) {
    final userIdsRaw = json['user_ids'];
    List<String> userIds = [];
    if (userIdsRaw is List) {
      userIds = userIdsRaw.map((id) => id.toString()).toList();
    }

    return MessageReactionSummary(
      reactionKey: json['reaction_key']?.toString() ?? '',
      count: (json['count'] as num?)?.toInt() ?? 0,
      userIds: userIds,
      hasSelf: json['has_self'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'reaction_key': reactionKey,
      'count': count,
      'user_ids': userIds,
      'has_self': hasSelf,
    };
  }

  Map<String, dynamic> toCacheJson() {
    return toJson();
  }

  factory MessageReactionSummary.fromCacheJson(Map<String, dynamic> json) {
    final userIdsRaw = json['user_ids'];
    List<String> userIds = [];
    if (userIdsRaw is List) {
      userIds = userIdsRaw.map((id) => id.toString()).toList();
    }

    return MessageReactionSummary(
      reactionKey: json['reaction_key']?.toString() ?? '',
      count: (json['count'] as num?)?.toInt() ?? 0,
      userIds: userIds,
      hasSelf: json['has_self'] as bool? ?? false,
    );
  }
}

/// 消息分片类型
enum MessagePartType { text, image, video, audio, file }

/// 消息附件信息
class MessageAttachment {
  MessageAttachment({
    required this.key,
    this.name,
    this.mime,
    this.size,
    this.width,
    this.height,
    this.durationMs,
    this.thumbnailKey,
    this.localPath,
    this.localThumbnailPath,
    this.uploadProgress,
  });

  final String key;
  final String? name;
  final String? mime;
  final int? size;
  final int? width;
  final int? height;
  final int? durationMs;
  final String? thumbnailKey;
  final String? localPath;
  final String? localThumbnailPath;
  final double? uploadProgress;

  MessageAttachment copyWith({
    String? key,
    Object? name = _unset,
    Object? mime = _unset,
    Object? size = _unset,
    Object? width = _unset,
    Object? height = _unset,
    Object? durationMs = _unset,
    Object? thumbnailKey = _unset,
    Object? localPath = _unset,
    Object? localThumbnailPath = _unset,
    Object? uploadProgress = _unset,
  }) {
    return MessageAttachment(
      key: key ?? this.key,
      name: identical(name, _unset) ? this.name : name as String?,
      mime: identical(mime, _unset) ? this.mime : mime as String?,
      size: identical(size, _unset) ? this.size : size as int?,
      width: identical(width, _unset) ? this.width : width as int?,
      height: identical(height, _unset) ? this.height : height as int?,
      durationMs: identical(durationMs, _unset)
          ? this.durationMs
          : durationMs as int?,
      thumbnailKey: identical(thumbnailKey, _unset)
          ? this.thumbnailKey
          : thumbnailKey as String?,
      localPath: identical(localPath, _unset)
          ? this.localPath
          : localPath as String?,
      localThumbnailPath: identical(localThumbnailPath, _unset)
          ? this.localThumbnailPath
          : localThumbnailPath as String?,
      uploadProgress: identical(uploadProgress, _unset)
          ? this.uploadProgress
          : uploadProgress as double?,
    );
  }

  Map<String, dynamic> toCacheJson() {
    return {
      'key': key,
      if (name != null) 'name': name,
      if (mime != null) 'mime': mime,
      if (size != null) 'size': size,
      if (width != null) 'width': width,
      if (height != null) 'height': height,
      if (durationMs != null) 'duration_ms': durationMs,
      if (thumbnailKey != null) 'thumbnail_key': thumbnailKey,
      if (localPath != null) 'local_path': localPath,
      if (localThumbnailPath != null)
        'local_thumbnail_path': localThumbnailPath,
      if (uploadProgress != null) 'upload_progress': uploadProgress,
    };
  }

  factory MessageAttachment.fromCacheJson(Map<String, dynamic> json) {
    return MessageAttachment(
      key: json['key']?.toString() ?? '',
      name: json['name']?.toString(),
      mime: json['mime']?.toString(),
      size: _parseInt(json['size']),
      width: _parseInt(json['width']),
      height: _parseInt(json['height']),
      durationMs: _parseInt(json['duration_ms']),
      thumbnailKey: json['thumbnail_key']?.toString(),
      localPath: json['local_path']?.toString(),
      localThumbnailPath: json['local_thumbnail_path']?.toString(),
      uploadProgress: _parseDouble(json['upload_progress']),
    );
  }

  static int? _parseInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  static double? _parseDouble(dynamic value) {
    if (value is double) return value;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }
}

/// 消息分片
class MessagePart {
  MessagePart({
    required this.position,
    required this.type,
    this.text,
    this.attachment,
  });

  final int position;
  final MessagePartType type;
  final String? text;
  final MessageAttachment? attachment;

  MessagePart copyWith({
    int? position,
    MessagePartType? type,
    Object? text = _unset,
    Object? attachment = _unset,
  }) {
    return MessagePart(
      position: position ?? this.position,
      type: type ?? this.type,
      text: identical(text, _unset) ? this.text : text as String?,
      attachment: identical(attachment, _unset)
          ? this.attachment
          : attachment as MessageAttachment?,
    );
  }

  Map<String, dynamic> toCacheJson() {
    return {
      'position': position,
      'type': type.name,
      if (text != null) 'text': text,
      if (attachment != null) 'attachment': attachment!.toCacheJson(),
    };
  }

  factory MessagePart.fromCacheJson(Map<String, dynamic> json) {
    final attachmentRaw = json['attachment'];
    MessageAttachment? attachment;
    if (attachmentRaw is Map<String, dynamic>) {
      attachment = MessageAttachment.fromCacheJson(attachmentRaw);
    } else if (attachmentRaw is Map) {
      final normalized = <String, dynamic>{};
      attachmentRaw.forEach((key, value) {
        normalized[key.toString()] = value;
      });
      attachment = MessageAttachment.fromCacheJson(normalized);
    }

    return MessagePart(
      position: MessageAttachment._parseInt(json['position']) ?? 0,
      type: _parsePartType(json['type']?.toString()),
      text: json['text']?.toString(),
      attachment: attachment,
    );
  }

  static MessagePartType _parsePartType(String? raw) {
    switch ((raw ?? '').toLowerCase()) {
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
}

/// 消息模型
class Message {
  final String id;
  final String roomId;
  final String senderId;
  final String senderUsername;
  final String senderName;
  final String? senderAvatar;
  final String? senderAvatarObjectKey;
  final String content;
  final MessageType type;
  final MessageStatus status;
  final DateTime timestamp;
  final bool isSelf;
  final Map<String, dynamic>? extra;
  final QuotedMessage? quotedMessage;
  final ForwardInfo? forwardInfo;
  final bool isDeleted;
  final bool isEdited;
  final DateTime? editedAt;
  final DateTime? pinnedAt;
  final List<MessagePart> parts;
  final List<MessageReactionSummary>? reactions;

  Message({
    required this.id,
    required this.roomId,
    required this.senderId,
    required this.senderUsername,
    required this.senderName,
    this.senderAvatar,
    this.senderAvatarObjectKey,
    required this.content,
    required this.type,
    required this.status,
    required this.timestamp,
    required this.isSelf,
    this.extra,
    this.quotedMessage,
    this.forwardInfo,
    this.isDeleted = false,
    this.isEdited = false,
    this.editedAt,
    this.pinnedAt,
    List<MessagePart>? parts,
    this.reactions,
  }) : parts = parts ?? const [];

  /// 复制并修改部分字段
  Message copyWith({
    String? id,
    String? roomId,
    String? senderId,
    String? senderUsername,
    String? senderName,
    Object? senderAvatar = _unset,
    Object? senderAvatarObjectKey = _unset,
    String? content,
    MessageType? type,
    MessageStatus? status,
    DateTime? timestamp,
    bool? isSelf,
    Object? extra = _unset,
    Object? quotedMessage = _unset,
    Object? forwardInfo = _unset,
    bool? isDeleted,
    bool? isEdited,
    Object? editedAt = _unset,
    Object? pinnedAt = _unset,
    Object? parts = _unset,
    Object? reactions = _unset,
  }) {
    return Message(
      id: id ?? this.id,
      roomId: roomId ?? this.roomId,
      senderId: senderId ?? this.senderId,
      senderUsername: senderUsername ?? this.senderUsername,
      senderName: senderName ?? this.senderName,
      senderAvatar: identical(senderAvatar, _unset)
          ? this.senderAvatar
          : senderAvatar as String?,
      senderAvatarObjectKey: identical(senderAvatarObjectKey, _unset)
          ? this.senderAvatarObjectKey
          : senderAvatarObjectKey as String?,
      content: content ?? this.content,
      type: type ?? this.type,
      status: status ?? this.status,
      timestamp: timestamp ?? this.timestamp,
      isSelf: isSelf ?? this.isSelf,
      extra: identical(extra, _unset)
          ? this.extra
          : extra as Map<String, dynamic>?,
      quotedMessage: identical(quotedMessage, _unset)
          ? this.quotedMessage
          : quotedMessage as QuotedMessage?,
      forwardInfo: identical(forwardInfo, _unset)
          ? this.forwardInfo
          : forwardInfo as ForwardInfo?,
      isDeleted: isDeleted ?? this.isDeleted,
      isEdited: isEdited ?? this.isEdited,
      editedAt: identical(editedAt, _unset)
          ? this.editedAt
          : editedAt as DateTime?,
      pinnedAt: identical(pinnedAt, _unset)
          ? this.pinnedAt
          : pinnedAt as DateTime?,
      parts: identical(parts, _unset)
          ? this.parts
          : List<MessagePart>.from(parts as List<MessagePart>),
      reactions: identical(reactions, _unset)
          ? this.reactions
          : reactions as List<MessageReactionSummary>?,
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
      'senderAvatarObjectKey': senderAvatarObjectKey,
      'content': content,
      'type': type.name,
      'status': status.name,
      'timestamp': timestamp.toIso8601String(),
      'isSelf': isSelf,
      'extra': extra,
      'quoted': quotedMessage?.toCacheJson(),
      'forward': forwardInfo?.toCacheJson(),
      'isDeleted': isDeleted,
      'isEdited': isEdited,
      'editedAt': editedAt?.toIso8601String(),
      'pinnedAt': pinnedAt?.toIso8601String(),
      'parts': parts.map((part) => part.toCacheJson()).toList(),
      if (reactions != null && reactions!.isNotEmpty)
        'reactions': reactions!.map((r) => r.toCacheJson()).toList(),
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

    final parsedParts = <MessagePart>[];
    final rawParts = json['parts'];
    if (rawParts is List) {
      for (final item in rawParts) {
        if (item is Map<String, dynamic>) {
          parsedParts.add(MessagePart.fromCacheJson(item));
        } else if (item is Map) {
          final normalized = <String, dynamic>{};
          item.forEach((key, value) {
            normalized[key.toString()] = value;
          });
          parsedParts.add(MessagePart.fromCacheJson(normalized));
        }
      }
    }

    return Message(
      id: json['id'] as String? ?? '',
      roomId: json['roomId'] as String? ?? '',
      senderId: json['senderId'] as String? ?? '',
      senderUsername: json['senderUsername'] as String? ?? '',
      senderName: json['senderName'] as String? ?? '',
      senderAvatar: json['senderAvatar'] as String?,
      senderAvatarObjectKey: json['senderAvatarObjectKey'] as String?,
      content: json['content'] as String? ?? '',
      type: _parseMessageType(typeString),
      status: _parseMessageStatus(statusString),
      timestamp: DateTime.tryParse(timestampString ?? '') ?? DateTime.now(),
      isSelf: json['isSelf'] as bool? ?? false,
      extra: extra,
      quotedMessage: _parseQuotedFromCache(json['quoted']),
      forwardInfo: _parseForwardFromCache(json['forward']),
      isDeleted: json['isDeleted'] as bool? ?? false,
      isEdited: json['isEdited'] as bool? ?? false,
      editedAt: _parseTimestamp(json['editedAt']),
      pinnedAt: _parseTimestamp(json['pinnedAt']),
      parts: parsedParts,
      reactions: _parseReactionsFromCache(json['reactions']),
    );
  }

  static List<MessageReactionSummary>? _parseReactionsFromCache(dynamic raw) {
    if (raw == null) return null;
    if (raw is List) {
      return raw.map((item) {
        if (item is Map<String, dynamic>) {
          return MessageReactionSummary.fromCacheJson(item);
        } else if (item is Map) {
          final normalized = <String, dynamic>{};
          item.forEach((key, value) {
            normalized[key.toString()] = value;
          });
          return MessageReactionSummary.fromCacheJson(normalized);
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

  static ForwardInfo? _parseForwardFromCache(dynamic raw) {
    if (raw == null) return null;
    if (raw is ForwardInfo) return raw;
    if (raw is Map<String, dynamic>) {
      return ForwardInfo.fromCacheJson(raw);
    }
    if (raw is Map) {
      final normalized = <String, dynamic>{};
      raw.forEach((key, value) {
        normalized[key.toString()] = value;
      });
      return ForwardInfo.fromCacheJson(normalized);
    }
    return null;
  }

  static DateTime? _parseTimestamp(dynamic raw) {
    if (raw == null) return null;
    if (raw is DateTime) return raw;
    if (raw is String && raw.isNotEmpty) {
      return DateTime.tryParse(raw);
    }
    return null;
  }

  bool get isPinned => pinnedAt != null;
}
