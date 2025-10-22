/// 已读成员信息
class MessageReader {
  const MessageReader({
    required this.userId,
    required this.username,
    this.nickname,
    this.avatarUrl,
    required this.readAt,
  });

  final String userId;
  final String username;
  final String? nickname;
  final String? avatarUrl;
  final DateTime readAt;

  String get displayName {
    final name = nickname?.trim();
    if (name != null && name.isNotEmpty) {
      return name;
    }
    return username;
  }

  factory MessageReader.fromJson(Map<String, dynamic> json) {
    return MessageReader(
      userId: (json['user_id'] ?? '').toString(),
      username: (json['username'] ?? '').toString(),
      nickname: json['nickname'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      readAt: DateTime.parse(json['read_at'] as String).toLocal(),
    );
  }
}
