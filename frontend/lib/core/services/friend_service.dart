import 'dart:convert';

import 'package:http/http.dart' as http;

import '../constants/app_config.dart';
import '../storage/token_storage.dart';
import '../../features/auth/models/auth_user.dart';
import '../../features/contacts/models/friend_models.dart';

class FriendServiceException implements Exception {
  FriendServiceException(this.message);

  final String message;

  @override
  String toString() => 'FriendServiceException: $message';
}

class FriendService {
  FriendService({TokenStorage? tokenStorage})
    : _tokenStorage = tokenStorage ?? const TokenStorage();

  final TokenStorage _tokenStorage;

  Future<Map<String, String>> _authHeaders() async {
    final session = await _tokenStorage.readSession();
    if (session == null) {
      throw FriendServiceException('用户未登录');
    }
    return {
      'Authorization': 'Bearer ${session.token}',
      'Content-Type': 'application/json',
    };
  }

  Future<List<AuthUser>> searchUsers(String keyword, {int limit = 20}) async {
    final headers = await _authHeaders();
    final uri = Uri.parse(
      '${AppConfig.apiBaseUrl}/users/search',
    ).replace(queryParameters: {'keyword': keyword, 'limit': limit.toString()});

    final response = await http.get(uri, headers: headers);
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data is List) {
        return data
            .whereType<Map<String, dynamic>>()
            .map(AuthUser.fromJson)
            .toList();
      }
      return [];
    }

    throw FriendServiceException(
      _extractErrorMessage(response.body) ?? '搜索用户失败',
    );
  }

  Future<FriendRequestInfo> sendFriendRequest(
    String targetUserId, {
    String? message,
  }) async {
    final headers = await _authHeaders();
    final uri = Uri.parse('${AppConfig.apiBaseUrl}/friends/requests');
    final response = await http.post(
      uri,
      headers: headers,
      body: jsonEncode({
        'target_user_id': targetUserId,
        if (message != null && message.trim().isNotEmpty)
          'message': message.trim(),
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return FriendRequestInfo.fromJson(data);
    }

    throw FriendServiceException(
      _extractErrorMessage(response.body) ?? '发送好友请求失败',
    );
  }

  Future<List<FriendRequestInfo>> fetchFriendRequests({
    String? direction,
    String? status,
  }) async {
    final headers = await _authHeaders();
    final query = <String, String>{};
    if (direction != null && direction.isNotEmpty) {
      query['direction'] = direction;
    }
    if (status != null && status.isNotEmpty) {
      query['status'] = status;
    }

    final uri = Uri.parse(
      '${AppConfig.apiBaseUrl}/friends/requests',
    ).replace(queryParameters: query.isEmpty ? null : query);
    final response = await http.get(uri, headers: headers);
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data is List) {
        return data
            .whereType<Map<String, dynamic>>()
            .map(FriendRequestInfo.fromJson)
            .toList();
      }
      return [];
    }

    throw FriendServiceException(
      _extractErrorMessage(response.body) ?? '获取好友请求失败',
    );
  }

  Future<FriendRequestInfo> respondFriendRequest(
    String requestId,
    FriendRequestAction action,
  ) async {
    final headers = await _authHeaders();
    final uri = Uri.parse(
      '${AppConfig.apiBaseUrl}/friends/requests/$requestId/respond',
    );
    final response = await http.post(
      uri,
      headers: headers,
      body: jsonEncode({'action': action.name}),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return FriendRequestInfo.fromJson(data);
    }

    throw FriendServiceException(
      _extractErrorMessage(response.body) ?? '处理好友请求失败',
    );
  }

  Future<List<FriendInfo>> fetchFriends() async {
    final headers = await _authHeaders();
    final uri = Uri.parse('${AppConfig.apiBaseUrl}/friends');
    final response = await http.get(uri, headers: headers);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data is List) {
        return data
            .whereType<Map<String, dynamic>>()
            .map(FriendInfo.fromJson)
            .toList();
      }
      return [];
    }

    throw FriendServiceException(
      _extractErrorMessage(response.body) ?? '获取好友列表失败',
    );
  }

  Future<EnsureChatResult> ensurePrivateChat(String friendUserId) async {
    final headers = await _authHeaders();
    final uri = Uri.parse('${AppConfig.apiBaseUrl}/friends/$friendUserId/chat');
    final response = await http.post(uri, headers: headers);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data is Map<String, dynamic>) {
        return EnsureChatResult.fromJson(data);
      }
      throw FriendServiceException('创建聊天返回数据格式异常');
    }

    throw FriendServiceException(
      _extractErrorMessage(response.body) ?? '创建聊天失败',
    );
  }

  String? _extractErrorMessage(String body) {
    try {
      final data = jsonDecode(body);
      if (data is Map<String, dynamic>) {
        final message = data['message'];
        if (message is String && message.isNotEmpty) {
          return message;
        }
        final error = data['error'];
        if (error is String && error.isNotEmpty) {
          return error;
        }
      }
    } catch (_) {
      return null;
    }
    return null;
  }
}
