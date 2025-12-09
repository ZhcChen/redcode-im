import 'auth_user.dart';

class AuthSession {
  const AuthSession({
    required this.token,
    required this.user,
    this.refreshToken,
  });

  final String token;
  final AuthUser user;
  final String? refreshToken;
}
