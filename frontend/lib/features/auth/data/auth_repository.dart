import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:mime/mime.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../core/constants/app_config.dart';
import '../../../core/network/direct_upload.dart';
import '../../../core/services/websocket_service.dart';
import '../../../core/services/message_service.dart';
import '../../../core/services/friend_store.dart';
import '../../../core/storage/token_storage.dart';
import '../../../core/storage/avatar_cache.dart';
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
        debugPrint(
          '[Auth] 响应体内容: ${response.body.substring(0, response.body.length > 200 ? 200 : response.body.length)}...',
        );
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

        if (token == null ||
            token.isEmpty ||
            userJson is! Map<String, dynamic>) {
          if (kDebugMode) {
            debugPrint(
              '[Auth] 登录响应异常 - token: ${token != null && token.isNotEmpty}, userJson: ${userJson is Map<String, dynamic>}',
            );
          }
          throw const AuthException('登录响应异常');
        }

        if (kDebugMode) {
          debugPrint('[Auth] 开始解析用户信息...');
        }
        final Map<String, dynamic> userMap = userJson;
        var user = AuthUser.fromJson(userMap);
        if (kDebugMode) {
          debugPrint('[Auth] 用户信息解析成功: ${user.username}');
        }

        user = await _attachAvatarCache(token, user);

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

      // 登录成功后启动 WebSocket 连接
      try {
        await WebSocketService.instance.connect();
        if (kDebugMode) {
          debugPrint('[Auth] WebSocket 连接启动成功 (Mock SMS)');
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint('[Auth] WebSocket 连接启动失败 (Mock SMS): $e');
        }
        // WebSocket 连接失败不影响登录成功
      }

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
      var updatedUser = AuthUser.fromJson(data);
      
      // 如果只是更新昵称，不需要重新处理头像缓存
      // 保持原有的头像缓存信息
      if (nickname != null && avatarUrl == null) {
        // 从当前会话中获取头像信息，保持一致性
        final currentUser = session.user;
        updatedUser = updatedUser.copyWith(
          avatarUrl: currentUser.avatarUrl,
          avatarObjectKey: currentUser.avatarObjectKey,
          localAvatarPath: currentUser.localAvatarPath,
        );
      } else {
        // 更新头像时才处理头像缓存
        updatedUser = await _attachAvatarCache(session.token, updatedUser);
      }
      
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

  Future<AuthUser> uploadAvatar(File file) async {
    if (!await file.exists()) {
      throw const AuthException('所选文件不存在或已被删除');
    }

    final session = await _storage.readSession();
    if (session == null) {
      throw const AuthException('当前未登录');
    }

    final contentType = lookupMimeType(file.path) ?? 'application/octet-stream';
    final directUri = Uri.parse(
      '${AppConfig.apiBaseUrl}/users/me/avatar/direct-upload',
    );
    final directResponse = await _makeRequest(
      () => http.post(
        directUri,
        headers: {
          'Authorization': 'Bearer ${session.token}',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'content_type': contentType}),
      ),
      uri: directUri,
    );

    if (directResponse.statusCode != 200) {
      final message = _extractErrorMessage(directResponse.body);
      throw AuthException(message ?? '获取上传签名失败');
    }

    final directPayload =
        jsonDecode(directResponse.body) as Map<String, dynamic>;
    final directSuccess = directPayload['success'] as bool? ?? false;
    if (!directSuccess) {
      final message = directPayload['message'] as String?;
      throw AuthException(message ?? '获取上传签名失败');
    }

    final key = directPayload['key'] as String?;
    final signatureMap =
        directPayload['signature'] as Map<String, dynamic>? ?? {};
    if (key == null || signatureMap.isEmpty) {
      throw const AuthException('上传签名响应不完整');
    }

    final signature = DirectUploadSignature.fromJson(signatureMap);
    final uploadRequest = http.Request(
      signature.method,
      Uri.parse(signature.url),
    );
    signature.applyHeaders(uploadRequest, defaultContentType: contentType);
    uploadRequest.bodyBytes = await file.readAsBytes();

    final uploadResponse = await uploadRequest.send();
    if (!_isSuccessStatus(uploadResponse.statusCode)) {
      final body = await uploadResponse.stream.bytesToString();
      throw AuthException(
        body.isNotEmpty
            ? '上传失败: $body'
            : '上传失败，状态码 ${uploadResponse.statusCode}',
      );
    }

    final commitUri = Uri.parse(
      '${AppConfig.apiBaseUrl}/users/me/avatar/commit',
    );
    final commitResponse = await _makeRequest(
      () => http.post(
        commitUri,
        headers: {
          'Authorization': 'Bearer ${session.token}',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'key': key,
          'delete_previous': true,
          'expires_in_seconds': 600,
        }),
      ),
      uri: commitUri,
    );

    if (commitResponse.statusCode != 200) {
      final message = _extractErrorMessage(commitResponse.body);
      throw AuthException(message ?? '提交头像信息失败');
    }

    final commitPayload =
        jsonDecode(commitResponse.body) as Map<String, dynamic>;
    final commitSuccess = commitPayload['success'] as bool? ?? false;
    if (!commitSuccess) {
      final message = commitPayload['message'] as String?;
      throw AuthException(message ?? '提交头像信息失败');
    }

    final downloadUrl = commitPayload['download_url'] as String?;
    final localPath = await AvatarCache.instance.save(
      userId: session.user.id,
      objectKey: key,
      source: file,
    );

    final updatedUser = session.user.copyWith(
      avatarUrl: downloadUrl ?? session.user.avatarUrl,
      avatarObjectKey: key,
      localAvatarPath: localPath,
    );
    await _storage.updateUser(updatedUser);
    _authStateController.add(AuthState.authenticated);
    return updatedUser;
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
      var user = AuthUser.fromJson(data);
      user = await _attachAvatarCache(session.token, user);
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

  Future<AuthUser> _attachAvatarCache(String token, AuthUser user) async {
    final key = user.avatarObjectKey;
    if (key == null || key.isEmpty) {
      await AvatarCache.instance.clear(user.id);
      return user.copyWith(clearLocalAvatarPath: true);
    }

    final cachedPath = await AvatarCache.instance.resolveLocalPath(
      userId: user.id,
      objectKey: key,
    );
    if (cachedPath != null) {
      return user.copyWith(localAvatarPath: cachedPath);
    }

    final downloadUri = Uri.parse(
      '${AppConfig.apiBaseUrl}/users/me/avatar/url?expires_in_seconds=600',
    );

    try {
      final response = await _makeRequest(
        () => http.get(
          downloadUri,
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
        ),
        uri: downloadUri,
      );

      if (response.statusCode == 200) {
        final payload = jsonDecode(response.body) as Map<String, dynamic>;
        final success = payload['success'] as bool? ?? false;
        final url = payload['download_url'] as String?;
        if (success && url != null && url.isNotEmpty) {
          final file = await _downloadAvatar(url);
          final savedPath = await AvatarCache.instance.save(
            userId: user.id,
            objectKey: key,
            source: file,
          );
          return user.copyWith(avatarUrl: url, localAvatarPath: savedPath);
        }
      }
    } catch (error, stackTrace) {
      if (kDebugMode) {
        debugPrint('[Auth] 同步头像缓存失败: $error');
        debugPrint(stackTrace.toString());
      }
    }

    return user.copyWith(clearLocalAvatarPath: true);
  }

  Future<File> _downloadAvatar(String url) async {
    final response = await http.get(Uri.parse(url));
    if (!_isSuccessStatus(response.statusCode)) {
      throw AuthException('下载头像失败，状态码 ${response.statusCode}');
    }

    final tempDir = await getTemporaryDirectory();
    final uri = Uri.parse(url);
    final ext = p.extension(uri.path);
    final fileName =
        'avatar_${DateTime.now().millisecondsSinceEpoch}_${response.bodyBytes.length}${ext.isNotEmpty ? ext : '.bin'}';
    final file = File(p.join(tempDir.path, fileName));
    await file.writeAsBytes(response.bodyBytes);
    return file;
  }

  bool _isSuccessStatus(int statusCode) =>
      statusCode >= 200 && statusCode < 300;

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
          throw TimeoutException('请求超时，请检查网络连接', AppConfig.apiTimeout);
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
