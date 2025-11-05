class AuthUser {
  const AuthUser({
    required this.id,
    required this.username,
    this.email,
    this.nickname,
    this.avatarUrl,
    this.avatarObjectKey,
    this.localAvatarPath,
    this.status,
  });

  final String id;
  final String username;
  final String? email;
  final String? nickname;
  final String? avatarUrl;
  final String? avatarObjectKey;
  final String? localAvatarPath;
  final String? status;

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    return AuthUser(
      id: (json['id'] as String?) ?? '',
      username: (json['username'] as String?) ?? '',
      email: json['email'] as String?,
      nickname: json['nickname'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      avatarObjectKey: json['avatar_object_key'] as String?,
      localAvatarPath: json['local_avatar_path'] as String?,
      status: json['status'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      if (email != null) 'email': email,
      if (nickname != null) 'nickname': nickname,
      if (avatarUrl != null) 'avatar_url': avatarUrl,
      if (avatarObjectKey != null)
        'avatar_object_key': avatarObjectKey,
      if (localAvatarPath != null)
        'local_avatar_path': localAvatarPath,
      if (status != null) 'status': status,
    };
  }

  String get displayName =>
      (nickname != null && nickname!.isNotEmpty) ? nickname! : username;

  AuthUser copyWith({
    String? email,
    String? nickname,
    String? avatarUrl,
    String? avatarObjectKey,
    String? localAvatarPath,
    bool clearLocalAvatarPath = false,
    String? status,
  }) {
    return AuthUser(
      id: id,
      username: username,
      email: email ?? this.email,
      nickname: nickname ?? this.nickname,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      avatarObjectKey: avatarObjectKey ?? this.avatarObjectKey,
      localAvatarPath:
          clearLocalAvatarPath ? null : (localAvatarPath ?? this.localAvatarPath),
      status: status ?? this.status,
    );
  }
}
