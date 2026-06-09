import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../constants/app_config.dart';
import '../storage/token_storage.dart';
import '../storage/avatar_cache.dart';

/// 用户头像服务，用于获取和缓存其他用户的头像
class UserAvatarService {
  UserAvatarService({TokenStorage? tokenStorage})
    : _tokenStorage = tokenStorage ?? const TokenStorage();

  final TokenStorage _tokenStorage;

  /// 最大重试次数
  static const int _maxRetries = 3;

  /// 重试延迟基数（毫秒）
  static const int _retryDelayMs = 500;

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

  /// 获取用户头像的临时下载地址
  /// 注意：目前后端可能只支持获取当前用户的头像，其他用户需要后端提供API支持
  Future<String?> getAvatarDownloadUrl(
    String userId, {
    int expiresInSeconds = 3600,
  }) async {
    try {
      // 尝试使用通用API（如果后端支持）
      // 如果后端不支持，这里会返回null，然后使用本地缓存或默认头像
      final headers = await _authHeaders();
      final uri = Uri.parse('${AppConfig.apiBaseUrl}/users/$userId/avatar/url')
          .replace(
            queryParameters: {
              'expires_in_seconds': expiresInSeconds.toString(),
            },
          );

      final response = await http.get(uri, headers: headers);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final success = data['success'] as bool? ?? false;
        final downloadUrl = data['download_url'] as String?;
        if (success && downloadUrl != null && downloadUrl.isNotEmpty) {
          return downloadUrl;
        }
      }
      if (kDebugMode) {
        debugPrint(
          '[Avatar] 获取用户头像下载地址失败 user=$userId status=${response.statusCode} body=${response.body}',
        );
      }
    } catch (e, stackTrace) {
      // API不存在或失败，返回null
      if (kDebugMode) {
        debugPrint('[Avatar] 获取用户头像下载地址异常 user=$userId err=$e');
        debugPrint(stackTrace.toString());
      }
    }
    return null;
  }

  /// 查找用户的本地缓存头像路径
  /// 只查找缓存，不进行网络请求
  /// 如果提供了 objectKey，会验证缓存的 objectKey 是否匹配
  Future<String?> resolveAvatarLocalPath({
    required String userId,
    String? objectKey,
  }) async {
    if (objectKey != null && objectKey.isNotEmpty) {
      // 有 objectKey 时，验证缓存是否匹配
      return await AvatarCache.instance.resolveUserLocalPath(
        userId: userId,
        objectKey: objectKey,
      );
    }
    // 没有 objectKey 时，返回任何已缓存的头像
    return await AvatarCache.instance.resolveAnyLocalPath(userId);
  }

  /// 加载并缓存用户头像
  /// 返回本地缓存路径，如果加载失败返回null
  /// 支持自动重试机制
  Future<String?> loadAndCacheAvatar({
    required String userId,
    required String? avatarObjectKey,
  }) async {
    if (avatarObjectKey == null || avatarObjectKey.isEmpty) {
      await AvatarCache.instance.clearUser(userId);
      return null;
    }

    // 先检查本地缓存
    final cachedPath = await AvatarCache.instance.resolveUserLocalPath(
      userId: userId,
      objectKey: avatarObjectKey,
    );
    if (cachedPath != null) {
      return cachedPath;
    }

    // 尝试获取临时下载地址
    final downloadUrl = await getAvatarDownloadUrl(userId);
    if (downloadUrl == null) {
      // 如果无法获取下载地址，返回null（显示默认头像）
      return null;
    }

    // 使用重试机制下载头像
    return await _downloadWithRetry(
      downloadUrl: downloadUrl,
      userId: userId,
      avatarObjectKey: avatarObjectKey,
    );
  }

  /// 带重试机制的下载方法
  Future<String?> _downloadWithRetry({
    required String downloadUrl,
    required String userId,
    required String avatarObjectKey,
    int attempt = 0,
  }) async {
    try {
      // 下载头像
      final response = await http
          .get(Uri.parse(downloadUrl))
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        // 保存到临时文件（必须使用 app 沙盒目录，避免 Directory.systemTemp 在部分设备不可写）
        final tempDir = await getTemporaryDirectory();
        final tempFile = File(
          '${tempDir.path}/avatar_${DateTime.now().millisecondsSinceEpoch}',
        );
        try {
          await tempFile.writeAsBytes(response.bodyBytes, flush: true);

          // 保存到缓存
          return await AvatarCache.instance.saveUserAvatar(
            userId: userId,
            objectKey: avatarObjectKey,
            source: tempFile,
          );
        } finally {
          if (await tempFile.exists()) {
            await tempFile.delete();
          }
        }
      }

      // 非 200 响应，根据状态码决定是否重试
      if (_shouldRetry(response.statusCode) && attempt < _maxRetries - 1) {
        await _delay(attempt);
        return await _downloadWithRetry(
          downloadUrl: downloadUrl,
          userId: userId,
          avatarObjectKey: avatarObjectKey,
          attempt: attempt + 1,
        );
      }
    } catch (e) {
      // 网络错误或超时，尝试重试
      if (attempt < _maxRetries - 1) {
        await _delay(attempt);
        return await _downloadWithRetry(
          downloadUrl: downloadUrl,
          userId: userId,
          avatarObjectKey: avatarObjectKey,
          attempt: attempt + 1,
        );
      }
      if (kDebugMode) {
        debugPrint(
          '[Avatar] 下载头像失败 user=$userId attempt=${attempt + 1}/$_maxRetries err=$e',
        );
      }
    }

    return null;
  }

  /// 判断是否应该重试
  bool _shouldRetry(int statusCode) {
    // 5xx 服务器错误或 429 限流时重试
    return statusCode >= 500 || statusCode == 429;
  }

  /// 指数退避延迟
  Future<void> _delay(int attempt) async {
    final delayMs = _retryDelayMs * (1 << attempt); // 500, 1000, 2000...
    await Future.delayed(Duration(milliseconds: delayMs));
  }
}
