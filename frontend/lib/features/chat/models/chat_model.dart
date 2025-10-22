/// 聊天类型
enum ChatType {
  single, // 单聊
  group, // 群聊
}

/// 聊天模型
class Chat {
  final String id;
  final String roomId;
  final String name;
  final String? avatar;
  final ChatType type;
  final String lastMessage;
  final DateTime lastMessageTime;
  final int unreadCount;
  final bool isPinned;
  final bool isMuted;
  final Map<String, dynamic>? extra;

  Chat({
    required this.id,
    required this.roomId,
    required this.name,
    this.avatar,
    required this.type,
    required this.lastMessage,
    required this.lastMessageTime,
    this.unreadCount = 0,
    this.isPinned = false,
    this.isMuted = false,
    this.extra,
  });

  /// 复制并修改部分字段
  Chat copyWith({
    String? id,
    String? roomId,
    String? name,
    String? avatar,
    ChatType? type,
    String? lastMessage,
    DateTime? lastMessageTime,
    int? unreadCount,
    bool? isPinned,
    bool? isMuted,
    Map<String, dynamic>? extra,
  }) {
    return Chat(
      id: id ?? this.id,
      roomId: roomId ?? this.roomId,
      name: name ?? this.name,
      avatar: avatar ?? this.avatar,
      type: type ?? this.type,
      lastMessage: lastMessage ?? this.lastMessage,
      lastMessageTime: lastMessageTime ?? this.lastMessageTime,
      unreadCount: unreadCount ?? this.unreadCount,
      isPinned: isPinned ?? this.isPinned,
      isMuted: isMuted ?? this.isMuted,
      extra: extra ?? this.extra,
    );
  }

  /// 获取显示的最后消息时间
  String get displayTime {
    final now = DateTime.now().toLocal();
    final localTime = lastMessageTime.toLocal();

    if (localTime.isAfter(now)) {
      return _formatHm(localTime);
    }

    final diff = now.difference(localTime);
    if (diff.inSeconds < 60) {
      return '刚刚';
    }

    if (_isSameDay(localTime, now)) {
      return _formatHm(localTime);
    }

    if (_isYesterday(localTime, now)) {
      return '昨天';
    }

    if (diff.inDays < 7) {
      return _weekdayLabel(localTime.weekday);
    }

    if (localTime.year == now.year) {
      return '${localTime.month}月${localTime.day}日';
    }

    final month = localTime.month.toString().padLeft(2, '0');
    final day = localTime.day.toString().padLeft(2, '0');
    return '${localTime.year}/$month/$day';
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  bool _isYesterday(DateTime time, DateTime now) {
    final yesterday = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(const Duration(days: 1));
    return time.year == yesterday.year &&
        time.month == yesterday.month &&
        time.day == yesterday.day;
  }

  String _formatHm(DateTime time) {
    final h = time.hour.toString().padLeft(2, '0');
    final m = time.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  String _weekdayLabel(int weekday) {
    switch (weekday) {
      case DateTime.monday:
        return '周一';
      case DateTime.tuesday:
        return '周二';
      case DateTime.wednesday:
        return '周三';
      case DateTime.thursday:
        return '周四';
      case DateTime.friday:
        return '周五';
      case DateTime.saturday:
        return '周六';
      case DateTime.sunday:
        return '周日';
      default:
        return '';
    }
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Chat && other.roomId == roomId;
  }

  @override
  int get hashCode => roomId.hashCode;
}
