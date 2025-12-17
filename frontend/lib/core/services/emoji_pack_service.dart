import 'dart:convert';

import 'package:flutter/foundation.dart';
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

  /// 获取用户的贴纸列表（包含表情项）
  /// 返回格式：Array<{ pack: EmojiPack; items: EmojiItem[] }>
  Future<List<EmojiPack>> getUserPacks() async {
    final headers = await _authHeaders();
    final uri = Uri.parse('${AppConfig.apiBaseUrl}/emoji-packs/my');

    final response = await http.get(uri, headers: headers);
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data is List) {
        // API 返回格式：Array<{ pack: EmojiPack; items: EmojiItem[] }>
        return data.whereType<Map<String, dynamic>>().map((item) {
          final packJson = item['pack'] as Map<String, dynamic>?;
          final itemsJson = item['items'] as List<dynamic>?;

          if (packJson == null) {
            throw EmojiPackServiceException('贴纸数据格式错误：缺少 pack 字段');
          }

          final pack = EmojiPack.fromJson(packJson);

          // 解析 items
          final items = <EmojiItem>[];
          if (itemsJson != null) {
            for (final itemJson in itemsJson) {
              if (itemJson is Map<String, dynamic>) {
                try {
                  items.add(EmojiItem.fromJson(itemJson));
                } catch (e) {
                  debugPrint('解析表情项失败: $e, 数据: $itemJson');
                }
              }
            }
          }

          // 将 items 赋值给 pack
          return EmojiPack(
            id: pack.id,
            name: pack.name,
            iconUrl: pack.iconUrl,
            description: pack.description,
            isActive: pack.isActive,
            createdAt: pack.createdAt,
            updatedAt: pack.updatedAt,
            packType: pack.packType,
            items: items,
          );
        }).toList();
      }
      return [];
    }

    throw EmojiPackServiceException(
      _extractErrorMessage(response.body) ?? '获取贴纸列表失败',
    );
  }

  /// 获取所有可用的贴纸（用于用户选择添加）
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
      _extractErrorMessage(response.body) ?? '获取可用贴纸列表失败',
    );
  }

  /// 添加用户贴纸
  Future<void> addUserPack(String packId) async {
    final headers = await _authHeaders();
    final uri = Uri.parse('${AppConfig.apiBaseUrl}/emoji-packs/$packId/add');

    final response = await http.post(uri, headers: headers);
    if (response.statusCode != 200) {
      throw EmojiPackServiceException(
        _extractErrorMessage(response.body) ?? '添加贴纸失败',
      );
    }
  }

  /// 删除用户贴纸
  Future<void> removeUserPack(String packId) async {
    final headers = await _authHeaders();
    final uri = Uri.parse('${AppConfig.apiBaseUrl}/emoji-packs/$packId/remove');

    final response = await http.delete(uri, headers: headers);
    if (response.statusCode != 200) {
      throw EmojiPackServiceException(
        _extractErrorMessage(response.body) ?? '删除贴纸失败',
      );
    }
  }

  /// 搜索贴纸
  Future<List<EmojiPack>> searchPacks(String keyword) async {
    final headers = await _authHeaders();
    final uri = Uri.parse(
      '${AppConfig.apiBaseUrl}/emoji-packs/search?keyword=${Uri.encodeComponent(keyword)}',
    );

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
      _extractErrorMessage(response.body) ?? '搜索贴纸失败',
    );
  }

  /// 添加贴纸包（添加贴纸包下的所有贴纸）
  Future<Map<String, dynamic>> addUserSuite(String suiteId) async {
    final headers = await _authHeaders();
    final uri = Uri.parse(
      '${AppConfig.apiBaseUrl}/emoji-packs/suites/$suiteId/add',
    );

    final response = await http.post(uri, headers: headers);
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return {'count': data['count'] as int? ?? 0};
    }

    throw EmojiPackServiceException(
      _extractErrorMessage(response.body) ?? '添加贴纸包失败',
    );
  }

  /// 获取贴纸包下的贴纸列表（包含表情项）
  /// 只返回用户已添加的贴纸
  /// 返回格式：Array<{ pack: EmojiPack; items: EmojiItem[] }>
  Future<List<EmojiPack>> getSuitePacks(String suiteId) async {
    final headers = await _authHeaders();
    final uri = Uri.parse(
      '${AppConfig.apiBaseUrl}/emoji-packs/suites/$suiteId/packs',
    );

    final response = await http.get(uri, headers: headers);
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data is List) {
        // API 返回格式：Array<{ pack: EmojiPack; items: EmojiItem[] }>
        return data.whereType<Map<String, dynamic>>().map((item) {
          final packJson = item['pack'] as Map<String, dynamic>?;
          final itemsJson = item['items'] as List<dynamic>?;

          if (packJson == null) {
            throw EmojiPackServiceException('贴纸数据格式错误：缺少 pack 字段');
          }

          final pack = EmojiPack.fromJson(packJson);

          // 解析 items
          final items = <EmojiItem>[];
          if (itemsJson != null) {
            for (final itemJson in itemsJson) {
              if (itemJson is Map<String, dynamic>) {
                try {
                  items.add(EmojiItem.fromJson(itemJson));
                } catch (e) {
                  debugPrint('解析表情项失败: $e, 数据: $itemJson');
                }
              }
            }
          }

          return EmojiPack(
            id: pack.id,
            name: pack.name,
            iconUrl: pack.iconUrl,
            description: pack.description,
            isActive: pack.isActive,
            createdAt: pack.createdAt,
            updatedAt: pack.updatedAt,
            packType: pack.packType,
            items: items,
          );
        }).toList();
      }
      return [];
    }

    throw EmojiPackServiceException(
      _extractErrorMessage(response.body) ?? '获取贴纸包贴纸列表失败',
    );
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
