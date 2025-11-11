import 'dart:convert';
import 'dart:io';

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
    print('[UserAvatarService] 开始获取下载URL - userId: $userId');
    try {
      // 尝试使用通用API（如果后端支持）
      // 如果后端不支持，这里会返回null，然后使用本地缓存或默认头像
      final headers = await _authHeaders();
      final uri = Uri.parse(
        '${AppConfig.apiBaseUrl}/users/$userId/avatar/url',
      ).replace(queryParameters: {
        'expires_in_seconds': expiresInSeconds.toString(),
      });

      print('[UserAvatarService] 请求URL: $uri');
      final response = await http.get(uri, headers: headers);
      print('[UserAvatarService] 响应状态码: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final success = data['success'] as bool? ?? false;
        final downloadUrl = data['download_url'] as String?;
        print('[UserAvatarService] 响应数据 - success: $success, hasUrl: ${downloadUrl != null}');
        if (success && downloadUrl != null && downloadUrl.isNotEmpty) {
          print('[UserAvatarService] ✅ 成功获取下载URL: ${downloadUrl.substring(0, 50)}...');
          return downloadUrl;
        }
      } else {
        print('[UserAvatarService] ❌ 获取下载URL失败 - 状态码: ${response.statusCode}, body: ${response.body}');
      }
    } catch (e, stackTrace) {
      // API不存在或失败，返回null
      print('[UserAvatarService] ❌ 获取下载URL异常: $e');
      print('[UserAvatarService] 堆栈: $stackTrace');
    }
    print('[UserAvatarService] ⚠️ 未能获取下载URL，返回null');
    return null;
  }

  /// 加载并缓存用户头像
  /// 返回本地缓存路径，如果加载失败返回null
  Future<String?> loadAndCacheAvatar({
    required String userId,
    required String? avatarObjectKey,
  }) async {
    print('[UserAvatarService] ========== 开始加载头像 ==========');
    print('[UserAvatarService] userId: $userId');
    print('[UserAvatarService] avatarObjectKey: $avatarObjectKey');
    
    if (avatarObjectKey == null || avatarObjectKey.isEmpty) {
      print('[UserAvatarService] ⚠️ avatarObjectKey为空，清除缓存');
      await AvatarCache.instance.clear(userId);
      return null;
    }

    // 先检查本地缓存
    print('[UserAvatarService] 检查本地缓存...');
    final cachedPath = await AvatarCache.instance.resolveLocalPath(
      userId: userId,
      objectKey: avatarObjectKey,
    );
    if (cachedPath != null) {
      print('[UserAvatarService] ✅ 命中本地缓存: $cachedPath');
      return cachedPath;
    }
    print('[UserAvatarService] ⚠️ 本地缓存未命中');

    // 尝试获取临时下载地址
    print('[UserAvatarService] 尝试获取临时下载地址...');
    final downloadUrl = await getAvatarDownloadUrl(userId);
    if (downloadUrl == null) {
      // 如果无法获取下载地址，返回null（显示默认头像）
      print('[UserAvatarService] ❌ 无法获取下载地址，返回null');
      return null;
    }

    try {
      // 下载头像
      print('[UserAvatarService] 开始下载头像文件...');
      final response = await http.get(Uri.parse(downloadUrl));
      print('[UserAvatarService] 下载响应状态码: ${response.statusCode}');
      print('[UserAvatarService] 下载文件大小: ${response.bodyBytes.length} bytes');
      
      if (response.statusCode == 200) {
        // 保存到临时文件
        print('[UserAvatarService] 保存到临时文件...');
        final tempDir = await Directory.systemTemp.createTemp();
        final tempFile = File(
          '${tempDir.path}/avatar_${DateTime.now().millisecondsSinceEpoch}',
        );
        await tempFile.writeAsBytes(response.bodyBytes);
        print('[UserAvatarService] 临时文件路径: ${tempFile.path}');

        // 保存到缓存
        print('[UserAvatarService] 保存到缓存...');
        final cachedPath = await AvatarCache.instance.save(
          userId: userId,
          objectKey: avatarObjectKey,
          source: tempFile,
        );
        print('[UserAvatarService] ✅ 缓存保存成功: $cachedPath');

        // 清理临时文件
        await tempFile.delete();
        await tempDir.delete(recursive: true);
        print('[UserAvatarService] 临时文件已清理');

        print('[UserAvatarService] ========== 加载完成 ==========');
        return cachedPath;
      } else {
        print('[UserAvatarService] ❌ 下载失败，状态码: ${response.statusCode}');
      }
    } catch (e, stackTrace) {
      // 下载失败，返回null
      print('[UserAvatarService] ❌ 下载异常: $e');
      print('[UserAvatarService] 堆栈: $stackTrace');
    }

    print('[UserAvatarService] ========== 加载失败 ==========');
    return null;
  }
}

