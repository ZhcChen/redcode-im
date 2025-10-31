import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
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
      try {
        await WebSocketService.instance.disconnect();
      } catch (_) {}
      await MessageService.instance.clearAll();
      FriendStore.instance.clearAll();
      _authStateController.add(AuthState.authenticated);
      return session;
    }

    final uri = Uri.parse('${AppConfig.apiBaseUrl}/auth/login');
    if (kDebugMode) {
      debugPrint('[Auth] 登录请求 - API Base URL: ${AppConfig.apiBaseUrl}');
      debugPrint('[Auth] 登录请求 - Username: $username');
    }
    final response = await _makeRequest(
      () => http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'username': username, 'password': password}),
      ),
      uri: uri,
    );

    if (response.statusCode == 200) {
      if (kDebugMode) {
        debugPrint('[Auth] 响应体长度: ${response.body.length}');
        debugPrint('[Auth] 响应体内容: ${response.body.substring(0, response.body.length > 200 ? 200 : response.body.length)}...');
      }
      
      try {
        final payload = jsonDecode(response.body) as Map<String, dynamic>;
        if (kDebugMode) {
          debugPrint('[Auth] 解析后的 payload keys: ${payload.keys}');
        }
        
        final token = payload['token'] as String?;
        final userJson = payload['user'];

        if (kDebugMode) {
          debugPrint('[Auth] Token 是否存在: ${token != null}');
          debugPrint('[Auth] Token 长度: ${token?.length ?? 0}');
          debugPrint('[Auth] User JSON 类型: ${userJson.runtimeType}');
        }

        if (token == null || token.isEmpty || userJson is! Map<String, dynamic>) {
          if (kDebugMode) {
            debugPrint('[Auth] 登录响应异常 - token: ${token != null && token.isNotEmpty}, userJson: ${userJson is Map<String, dynamic>}');
          }
          throw const AuthException('登录响应异常');
        }

        if (kDebugMode) {
          debugPrint('[Auth] 开始解析用户信息...');
        }
        final user = AuthUser.fromJson(userJson as Map<String, dynamic>);
        if (kDebugMode) {
          debugPrint('[Auth] 用户信息解析成功: ${user.username}');
        }
        
        final session = AuthSession(token: token, user: user);
        if (kDebugMode) {
          debugPrint('[Auth] 开始保存 session...');
        }
        try {
          await _storage.saveSession(session);
          if (kDebugMode) {
            debugPrint('[Auth] Session 保存成功');
          }
        } catch (e) {
          if (kDebugMode) {
            debugPrint('[Auth] Session 保存失败: $e');
          }
          // 如果是 PlatformException，提供更友好的错误信息
          if (e.toString().contains('SharedPreferences') || 
              e.toString().contains('PlatformException')) {
            throw AuthException('本地存储初始化失败，请尝试重启应用');
          }
          rethrow;
        }
        
        try {
          await WebSocketService.instance.disconnect();
        } catch (_) {}
        await MessageService.instance.clearAll();
        FriendStore.instance.clearAll();
        _authStateController.add(AuthState.authenticated);
        if (kDebugMode) {
          debugPrint('[Auth] 登录流程完成');
        }
        return session;
      } catch (e, stackTrace) {
        if (kDebugMode) {
          debugPrint('[Auth] JSON 解析或后续处理出错: $e');
          debugPrint('[Auth] 异常类型: ${e.runtimeType}');
          debugPrint('[Auth] 堆栈跟踪: $stackTrace');
        }
        rethrow;
      }
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
    final response = await _makeRequest(
      () => http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': username,
          'email': email,
          'password': password,
          'nickname': effectiveNickname,
        }),
      ),
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
    final response = await _makeRequest(
      () => http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'phone': phone.trim()}),
      ),
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
      try {
        await WebSocketService.instance.disconnect();
      } catch (_) {}
      await MessageService.instance.clearAll();
      FriendStore.instance.clearAll();
      _authStateController.add(AuthState.authenticated);
      return session;
    }

    final uri = Uri.parse('${AppConfig.apiBaseUrl}/auth/login/sms');
    if (kDebugMode) {
      debugPrint('[Auth] 验证码登录请求 - API Base URL: ${AppConfig.apiBaseUrl}');
      debugPrint('[Auth] 验证码登录请求 - Phone: ${phone.trim()}');
    }
    final response = await _makeRequest(
      () => http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'phone': phone.trim(), 'code': code.trim()}),
      ),
      uri: uri,
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
      try {
        await WebSocketService.instance.disconnect();
      } catch (_) {}
      await MessageService.instance.clearAll();
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
    final response = await _makeRequest(
      () => http.post(
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
      ),
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
    final response = await _makeRequest(
      () => http.patch(
        uri,
        headers: {
          'Authorization': 'Bearer ${session.token}',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(payload),
      ),
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
    final response = await _makeRequest(
      () => http.post(
        uri,
        headers: {
          'Authorization': 'Bearer ${session.token}',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'old_password': oldPassword,
          'new_password': newPassword,
        }),
      ),
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
    final response = await _makeRequest(
      () => http.delete(
        uri,
        headers: {
          'Authorization': 'Bearer ${session.token}',
          'Content-Type': 'application/json',
        },
      ),
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
    final response = await _makeRequest(
      () => http.get(
        uri,
        headers: {
          'Authorization': 'Bearer ${session.token}',
          'Content-Type': 'application/json',
        },
      ),
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
    await MessageService.instance.clearAll();
    FriendStore.instance.clearAll();

    await _storage.clear();
    _authStateController.add(AuthState.unauthenticated);
  }

  /// 统一的 HTTP 请求处理，添加超时和错误处理
  Future<http.Response> _makeRequest(
    Future<http.Response> Function() request, {
    Uri? uri,
  }) async {
    if (kDebugMode && uri != null) {
      debugPrint('[Auth] 请求 URL: ${uri.toString()}');
    }
    
    try {
      final response = await request().timeout(
        AppConfig.apiTimeout,
        onTimeout: () {
          if (kDebugMode) {
            debugPrint('[Auth] 请求超时: ${uri?.toString() ?? 'unknown'}');
          }
          throw TimeoutException(
            '请求超时，请检查网络连接',
            AppConfig.apiTimeout,
          );
        },
      );
      
      if (kDebugMode) {
        debugPrint('[Auth] 响应状态码: ${response.statusCode}');
        debugPrint('[Auth] 响应头: ${response.headers}');
      }
      
      return response;
    } on SocketException catch (e) {
      if (kDebugMode) {
        debugPrint('[Auth] SocketException: ${e.message}');
        debugPrint('[Auth] OS Error: ${e.osError}');
      }
      throw AuthException('网络连接失败：${e.message}。请检查设备是否与服务器在同一网络');
    } on TimeoutException catch (e) {
      if (kDebugMode) {
        debugPrint('[Auth] TimeoutException: ${e.message}');
      }
      throw AuthException('请求超时，请检查网络连接');
    } on HttpException catch (e) {
      if (kDebugMode) {
        debugPrint('[Auth] HttpException: ${e.message}');
      }
      throw AuthException('HTTP 错误：${e.message}');
    } on FormatException catch (e) {
      if (kDebugMode) {
        debugPrint('[Auth] FormatException: ${e.message}');
      }
      throw AuthException('数据格式错误：${e.message}');
    } catch (e, stackTrace) {
      if (kDebugMode) {
        debugPrint('[Auth] 未知异常: $e');
        debugPrint('[Auth] 异常类型: ${e.runtimeType}');
        debugPrint('[Auth] 堆栈跟踪: $stackTrace');
      }
      throw AuthException('网络异常：${e.toString()}');
    }
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
