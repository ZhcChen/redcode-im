import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/constants/app_config.dart';
import '../../../core/services/websocket_service.dart';
import '../../../core/services/message_service.dart';
import '../../../core/services/friend_store.dart';
import '../../../core/storage/token_storage.dart';
import '../models/auth_session.dart';
import '../models/auth_user.dart';

class AuthRepository {
  AuthRepository({TokenStorage? storage})
    : _storage = storage ?? TokenStorage();

  final TokenStorage _storage;
  final StreamController<AuthState> _authStateController =
      StreamController.broadcast();

  Stream<AuthState> get authStateStream => _authStateController.stream;

  Future<AuthSession> login({
    required String username,
    required String password,
  }) async {
    if (AppConfig.useMockData) {
      await Future<void>.delayed(AppConfig.mockLatency);
      final user = AuthUser(
        id: 'mock-user-id',
        username: username.isEmpty ? 'bear_user' : username,
        nickname: '熊小熊',
        email: 'bear@example.com',
        status: 'active',
      );
      final session = AuthSession(token: 'mock-token', user: user);
      await _storage.saveSession(session);
      // 切换账号/新登录时重置本地缓存与连接状态
      try { await WebSocketService.instance.disconnect(); } catch (_) {}
      MessageService.instance.clearAll();
      FriendStore.instance.clearAll();
      _authStateController.add(AuthState.authenticated);
      return session;
    }

    final uri = Uri.parse('${AppConfig.apiBaseUrl}/auth/login');
    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'username': username, 'password': password}),
    );

    if (response.statusCode == 200) {
      final payload = jsonDecode(response.body) as Map<String, dynamic>;
      final token = payload['token'] as String?;
      final userJson = payload['user'];

      if (token == null || token.isEmpty || userJson is! Map<String, dynamic>) {
        throw const AuthException('登录响应异常');
      }

      final user = AuthUser.fromJson(userJson);
      final session = AuthSession(token: token, user: user);
      await _storage.saveSession(session);
      try { await WebSocketService.instance.disconnect(); } catch (_) {}
      MessageService.instance.clearAll();
      FriendStore.instance.clearAll();
      _authStateController.add(AuthState.authenticated);
      return session;
    }

    final message = _extractErrorMessage(response.body);
    if (response.statusCode == 401) {
      throw AuthException(message ?? '用户名或密码错误');
    }

    throw AuthException(message ?? '登录失败，请稍后重试');
  }

  Future<AuthUser> register({
    required String username,
    required String email,
    required String password,
    String? nickname,
  }) async {
    final effectiveNickname = (nickname != null && nickname.trim().isNotEmpty)
        ? nickname.trim()
        : username;

    if (AppConfig.useMockData) {
      await Future<void>.delayed(AppConfig.mockLatency);
      return AuthUser(
        id: 'mock-user-${username.isEmpty ? 'new' : username}',
        username: username.isEmpty ? 'mock_user' : username,
        email: email,
        nickname: effectiveNickname,
        status: 'active',
      );
    }

    final uri = Uri.parse('${AppConfig.apiBaseUrl}/auth/register');
    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'username': username,
        'email': email,
        'password': password,
        'nickname': effectiveNickname,
      }),
    );

    if (response.statusCode == 200) {
      final payload = jsonDecode(response.body) as Map<String, dynamic>;
      return AuthUser.fromJson(payload);
    }

    final message = _extractErrorMessage(response.body);
    throw AuthException(message ?? '注册失败，请稍后重试');
  }

  Future<void> sendSmsCode(String phone) async {
    if (phone.trim().isEmpty) {
      throw const AuthException('请输入手机号');
    }

    if (AppConfig.useMockData) {
      await Future<void>.delayed(const Duration(milliseconds: 600));
      return;
    }

    final uri = Uri.parse('${AppConfig.apiBaseUrl}/auth/sms/send');
    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'phone': phone.trim()}),
    );

    if (response.statusCode == 200) {
      return;
    }

    final message = _extractErrorMessage(response.body);
    throw AuthException(message ?? '发送验证码失败');
  }

  Future<AuthSession> loginWithSms({
    required String phone,
    required String code,
  }) async {
    if (phone.trim().isEmpty || code.trim().isEmpty) {
      throw const AuthException('手机号和验证码不能为空');
    }

    if (AppConfig.useMockData) {
      await Future<void>.delayed(const Duration(milliseconds: 600));
      final user = AuthUser(
        id: 'mock-user-sms',
        username: phone.trim(),
        nickname: '验证码用户',
        email: 'mock@example.com',
        status: 'active',
      );
      final session = AuthSession(token: 'mock-token', user: user);
      await _storage.saveSession(session);
      try { await WebSocketService.instance.disconnect(); } catch (_) {}
      MessageService.instance.clearAll();
      FriendStore.instance.clearAll();
      _authStateController.add(AuthState.authenticated);
      return session;
    }

    final uri = Uri.parse('${AppConfig.apiBaseUrl}/auth/login/sms');
    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'phone': phone.trim(), 'code': code.trim()}),
    );

    if (response.statusCode == 200) {
      final payload = jsonDecode(response.body) as Map<String, dynamic>;
      final token = payload['token'] as String?;
      final userJson = payload['user'];
      if (token == null || token.isEmpty || userJson is! Map<String, dynamic>) {
        throw const AuthException('登录响应异常');
      }

      final user = AuthUser.fromJson(userJson);
      final session = AuthSession(token: token, user: user);
      await _storage.saveSession(session);
      try { await WebSocketService.instance.disconnect(); } catch (_) {}
      MessageService.instance.clearAll();
      FriendStore.instance.clearAll();
      _authStateController.add(AuthState.authenticated);
      return session;
    }

    final message = _extractErrorMessage(response.body);
    if (response.statusCode == 401) {
      throw AuthException(message ?? '验证码无效或已过期');
    }

    throw AuthException(message ?? '验证码登录失败');
  }

  Future<void> resetPasswordWithSms({
    required String phone,
    required String code,
    required String newPassword,
  }) async {
    final session = await _storage.readSession();
    if (session == null) {
      throw const AuthException('当前未登录');
    }

    if (newPassword.trim().length < 6) {
      throw const AuthException('新密码长度至少 6 位');
    }

    final uri = Uri.parse('${AppConfig.apiBaseUrl}/auth/password/reset');
    final response = await http.post(
      uri,
      headers: {
        'Authorization': 'Bearer ${session.token}',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'phone': phone.trim(),
        'code': code.trim(),
        'new_password': newPassword.trim(),
      }),
    );

    if (response.statusCode == 200) {
      return;
    }

    final message = _extractErrorMessage(response.body);
    throw AuthException(message ?? '重置密码失败');
  }

  Future<AuthSession?> loadSession() {
    return _storage.readSession();
  }

  Future<AuthUser> updateProfile({String? nickname, String? avatarUrl}) async {
    final session = await _storage.readSession();
    if (session == null) {
      throw const AuthException('当前未登录');
    }

    final payload = <String, dynamic>{};
    if (nickname != null) {
      final trimmed = nickname.trim();
      if (trimmed.isEmpty) {
        throw const AuthException('昵称不能为空');
      }
      payload['nickname'] = trimmed;
    }
    if (avatarUrl != null) {
      final trimmed = avatarUrl.trim();
      if (trimmed.isNotEmpty) {
        payload['avatar_url'] = trimmed;
      }
    }

    if (payload.isEmpty) {
      throw const AuthException('没有需要更新的内容');
    }

    final uri = Uri.parse('${AppConfig.apiBaseUrl}/users/me');
    final response = await http.patch(
      uri,
      headers: {
        'Authorization': 'Bearer ${session.token}',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(payload),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final updatedUser = AuthUser.fromJson(data);
      await _storage.updateUser(updatedUser);
      _authStateController.add(AuthState.authenticated);
      return updatedUser;
    }

    final message = _extractErrorMessage(response.body);
    throw AuthException(message ?? '更新用户信息失败');
  }

  Future<void> changePassword({
    required String oldPassword,
    required String newPassword,
  }) async {
    final session = await _storage.readSession();
    if (session == null) {
      throw const AuthException('当前未登录');
    }

    if (newPassword.length < 6) {
      throw const AuthException('新密码长度不能少于 6 位');
    }

    final uri = Uri.parse('${AppConfig.apiBaseUrl}/users/me/password');
    final response = await http.post(
      uri,
      headers: {
        'Authorization': 'Bearer ${session.token}',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'old_password': oldPassword,
        'new_password': newPassword,
      }),
    );

    if (response.statusCode == 200) {
      return;
    }

    final message = _extractErrorMessage(response.body);
    throw AuthException(message ?? '修改密码失败');
  }

  Future<void> deactivateAccount() async {
    final session = await _storage.readSession();
    if (session == null) {
      throw const AuthException('当前未登录');
    }

    final uri = Uri.parse('${AppConfig.apiBaseUrl}/users/me');
    final response = await http.delete(
      uri,
      headers: {
        'Authorization': 'Bearer ${session.token}',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      await _storage.clear();
      _authStateController.add(AuthState.unauthenticated);
      return;
    }

    final message = _extractErrorMessage(response.body);
    throw AuthException(message ?? '注销账号失败');
  }

  Future<AuthUser?> refreshCurrentUser() async {
    if (AppConfig.useMockData) {
      await Future<void>.delayed(
        Duration(milliseconds: AppConfig.mockLatency.inMilliseconds ~/ 2),
      );
      final session = await _storage.readSession();
      return session?.user;
    }

    final session = await _storage.readSession();
    if (session == null) {
      return null;
    }

    final uri = Uri.parse('${AppConfig.apiBaseUrl}/auth/me');
    final response = await http.get(
      uri,
      headers: {
        'Authorization': 'Bearer ${session.token}',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final user = AuthUser.fromJson(data);
      await _storage.updateUser(user);
      return user;
    }

    if (response.statusCode == 401) {
      await _storage.clear();
      _authStateController.add(AuthState.unauthenticated);
      return null;
    }

    throw const AuthException('获取用户信息失败');
  }

  Future<void> logout() async {
    try {
      // 断开 WS、清空本地消息/会话与好友状态，避免切换账号出现脏数据
      await WebSocketService.instance.disconnect();
    } catch (_) {}
    MessageService.instance.clearAll();
    FriendStore.instance.clearAll();

    await _storage.clear();
    _authStateController.add(AuthState.unauthenticated);
  }

  String? _extractErrorMessage(String body) {
    try {
      final data = jsonDecode(body);
      if (data is Map<String, dynamic>) {
        final error = data['error'];
        if (error is String && error.isNotEmpty) {
          return error;
        }

        final message = data['message'];
        if (message is String && message.isNotEmpty) {
          return message;
        }
      }
    } catch (_) {
      return null;
    }
    return null;
  }
}

class AuthException implements Exception {
  const AuthException(this.message);

  final String message;

  @override
  String toString() => 'AuthException: $message';
}

enum AuthState { authenticated, unauthenticated }
