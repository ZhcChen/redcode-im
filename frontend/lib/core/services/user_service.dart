import 'dart:convert';

import 'package:http/http.dart' as http;

import '../constants/app_config.dart';
import '../storage/token_storage.dart';

class UserService {
  UserService({TokenStorage? tokenStorage})
    : _tokenStorage = tokenStorage ?? const TokenStorage();

  final TokenStorage _tokenStorage;

  Future<Map<String, String>> _authHeaders() async {
    final session = await _tokenStorage.readSession();
    if (session == null) {
      throw Exception('用户未登录');
    }

    return {
      'Authorization': 'Bearer ${session.token}',
      'Content-Type': 'application/json',
    };
  }

  /// 获取用户详情信息
  Future<Map<String, dynamic>?> fetchUserDetail(String userId) async {
    if (userId.isEmpty) {
      return null;
    }

    try {
      final headers = await _authHeaders();
      final uri = Uri.parse('${AppConfig.apiBaseUrl}/users/$userId');
      final response = await http.get(uri, headers: headers);

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) {
          return decoded['user'] as Map<String, dynamic>?;
        }
      }
    } catch (e) {
      // 静默失败，返回 null
    }
    return null;
  }
}