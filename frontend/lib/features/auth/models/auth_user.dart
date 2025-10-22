class AuthUser {
  const AuthUser({
    required this.id,
    required this.username,
    this.email,
    this.nickname,
    this.avatarUrl,
    this.status,
  });

  final String id;
  final String username;
  final String? email;
  final String? nickname;
  final String? avatarUrl;
  final String? status;

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    return AuthUser(
      id: (json['id'] as String?) ?? '',
      username: (json['username'] as String?) ?? '',
      email: json['email'] as String?,
      nickname: json['nickname'] as String?,
      avatarUrl: json['avatar_url'] as String?,
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
      if (status != null) 'status': status,
    };
  }

  String get displayName =>
      (nickname != null && nickname!.isNotEmpty) ? nickname! : username;
}
