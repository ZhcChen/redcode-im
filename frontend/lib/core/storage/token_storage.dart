import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../features/auth/models/auth_session.dart';
import '../../features/auth/models/auth_user.dart';

class TokenStorage {
  const TokenStorage();

  static const _tokenKey = 'auth_token';
  static const _userKey = 'auth_user';
  static const _refreshTokenKey = 'auth_refresh_token';

  Future<void> saveSession(AuthSession session) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, session.token);
    await prefs.setString(_userKey, jsonEncode(session.user.toJson()));
    if (session.refreshToken != null && session.refreshToken!.isNotEmpty) {
      await prefs.setString(_refreshTokenKey, session.refreshToken!);
    } else {
      await prefs.remove(_refreshTokenKey);
    }
  }

  Future<AuthSession?> readSession() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_tokenKey);
    final userJson = prefs.getString(_userKey);
    final refreshToken = prefs.getString(_refreshTokenKey);

    if (token == null || userJson == null) {
      return null;
    }

    try {
      final data = jsonDecode(userJson) as Map<String, dynamic>;
      final user = AuthUser.fromJson(data);
      return AuthSession(token: token, user: user, refreshToken: refreshToken);
    } catch (_) {
      await prefs.remove(_tokenKey);
      await prefs.remove(_userKey);
      return null;
    }
  }

  Future<String?> readToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  Future<void> updateUser(AuthUser user) async {
    final prefs = await SharedPreferences.getInstance();
    if (!prefs.containsKey(_tokenKey)) {
      return;
    }

    await prefs.setString(_userKey, jsonEncode(user.toJson()));
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_userKey);
    await prefs.remove(_refreshTokenKey);
  }
}
