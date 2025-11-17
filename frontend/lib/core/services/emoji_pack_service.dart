import 'dart:convert';

import 'package:http/http.dart' as http;

import '../constants/app_config.dart';
import '../storage/token_storage.dart';
import '../../features/emoji/models/emoji_pack_models.dart';

class EmojiPackServiceException implements Exception {
  EmojiPackServiceException(this.message);

  final String message;

  @override
  String toString() => 'EmojiPackServiceException: $message';
}

class EmojiPackService {
  EmojiPackService({TokenStorage? tokenStorage})
      : _tokenStorage = tokenStorage ?? const TokenStorage();

  final TokenStorage _tokenStorage;

  Future<Map<String, String>> _authHeaders() async {
    final session = await _tokenStorage.readSession();
    if (session == null) {
      throw EmojiPackServiceException('用户未登录');
    }
    return {
      'Authorization': 'Bearer ${session.token}',
      'Content-Type': 'application/json',
    };
  }

  /// 获取用户的表情包列表
  Future<List<EmojiPack>> getUserPacks() async {
    final headers = await _authHeaders();
    final uri = Uri.parse('${AppConfig.apiBaseUrl}/emoji-packs/my');

    final response = await http.get(uri, headers: headers);
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data is List) {
        return data
            .whereType<Map<String, dynamic>>()
            .map((json) => EmojiPack.fromJson(json))
            .toList();
      }
      return [];
    }

    throw EmojiPackServiceException(
      _extractErrorMessage(response.body) ?? '获取表情包列表失败',
    );
  }

  /// 获取所有可用的表情包（用于用户选择添加）
  Future<List<EmojiPack>> getAvailablePacks() async {
    final headers = await _authHeaders();
    final uri = Uri.parse('${AppConfig.apiBaseUrl}/emoji-packs/available');

    final response = await http.get(uri, headers: headers);
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data is List) {
        return data
            .whereType<Map<String, dynamic>>()
            .map((json) => EmojiPack.fromJson(json))
            .toList();
      }
      return [];
    }

    throw EmojiPackServiceException(
      _extractErrorMessage(response.body) ?? '获取可用表情包列表失败',
    );
  }

  /// 添加用户表情包
  Future<void> addUserPack(String packId) async {
    final headers = await _authHeaders();
    final uri = Uri.parse('${AppConfig.apiBaseUrl}/emoji-packs/$packId/add');

    final response = await http.post(uri, headers: headers);
    if (response.statusCode != 200) {
      throw EmojiPackServiceException(
        _extractErrorMessage(response.body) ?? '添加表情包失败',
      );
    }
  }

  /// 删除用户表情包
  Future<void> removeUserPack(String packId) async {
    final headers = await _authHeaders();
    final uri =
        Uri.parse('${AppConfig.apiBaseUrl}/emoji-packs/$packId/remove');

    final response = await http.delete(uri, headers: headers);
    if (response.statusCode != 200) {
      throw EmojiPackServiceException(
        _extractErrorMessage(response.body) ?? '删除表情包失败',
      );
    }
  }

  String? _extractErrorMessage(String body) {
    try {
      final json = jsonDecode(body) as Map<String, dynamic>;
      return json['message'] as String?;
    } catch (_) {
      return null;
    }
  }
}

