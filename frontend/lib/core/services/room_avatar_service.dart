import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../constants/app_config.dart';
import '../storage/avatar_cache.dart';
import '../storage/token_storage.dart';

/// 群头像服务，用于获取和缓存房间头像
class RoomAvatarService {
  RoomAvatarService({TokenStorage? tokenStorage})
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

  /// 获取房间头像的临时下载地址
  Future<String?> getAvatarDownloadUrl(
    String roomId, {
    int expiresInSeconds = 3600,
  }) async {
    print('[RoomAvatarService] 开始获取下载URL - roomId: $roomId');
    try {
      final headers = await _authHeaders();
      final uri = Uri.parse(
        '${AppConfig.apiBaseUrl}/rooms/$roomId/avatar/url',
      ).replace(queryParameters: {
        'expires_in_seconds': expiresInSeconds.toString(),
      });

      print('[RoomAvatarService] 请求URL: $uri');
      final response = await http.get(uri, headers: headers);
      print('[RoomAvatarService] 响应状态码: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final success = data['success'] as bool? ?? false;
        final downloadUrl = data['download_url'] as String?;
        print('[RoomAvatarService] 响应数据 - success: $success, hasUrl: ${downloadUrl != null}');
        if (success && downloadUrl != null && downloadUrl.isNotEmpty) {
          print('[RoomAvatarService] ✅ 成功获取下载URL: ${downloadUrl.substring(0, 50)}...');
          return downloadUrl;
        }
      } else {
        print('[RoomAvatarService] ❌ 获取下载URL失败 - 状态码: ${response.statusCode}, body: ${response.body}');
      }
    } catch (e, stackTrace) {
      // API不存在或失败，返回null
      print('[RoomAvatarService] ❌ 获取下载URL异常: $e');
      print('[RoomAvatarService] 堆栈: $stackTrace');
    }
    print('[RoomAvatarService] ⚠️ 未能获取下载URL，返回null');
    return null;
  }

  /// 加载并缓存房间头像
  /// 返回本地缓存路径，如果加载失败返回null
  Future<String?> loadAndCacheAvatar({
    required String roomId,
    required String? avatarObjectKey,
  }) async {
    print('[RoomAvatarService] ========== 开始加载房间头像 ==========');
    print('[RoomAvatarService] roomId: $roomId');
    print('[RoomAvatarService] avatarObjectKey: $avatarObjectKey');
    
    if (avatarObjectKey == null || avatarObjectKey.isEmpty) {
      print('[RoomAvatarService] ⚠️ avatarObjectKey为空，清除缓存');
      await AvatarCache.instance.clearRoom(roomId);
      return null;
    }

    // 先检查本地缓存
    print('[RoomAvatarService] 检查本地缓存...');
    final cachedPath = await AvatarCache.instance.resolveRoomLocalPath(
      roomId: roomId,
      objectKey: avatarObjectKey,
    );
    if (cachedPath != null) {
      print('[RoomAvatarService] ✅ 命中本地缓存: $cachedPath');
      return cachedPath;
    }
    print('[RoomAvatarService] ⚠️ 本地缓存未命中');

    // 尝试获取临时下载地址
    print('[RoomAvatarService] 尝试获取临时下载地址...');
    final downloadUrl = await getAvatarDownloadUrl(roomId);
    if (downloadUrl == null) {
      // 如果无法获取下载地址，返回null（显示默认头像）
      print('[RoomAvatarService] ❌ 无法获取下载地址，返回null');
      return null;
    }

    try {
      // 下载头像
      print('[RoomAvatarService] 开始下载头像文件...');
      final response = await http.get(Uri.parse(downloadUrl));
      print('[RoomAvatarService] 下载响应状态码: ${response.statusCode}');
      print('[RoomAvatarService] 下载文件大小: ${response.bodyBytes.length} bytes');
      
      if (response.statusCode == 200) {
        // 保存到临时文件
        print('[RoomAvatarService] 保存到临时文件...');
        final tempDir = await Directory.systemTemp.createTemp();
        final tempFile = File(
          '${tempDir.path}/room_avatar_${DateTime.now().millisecondsSinceEpoch}',
        );
        await tempFile.writeAsBytes(response.bodyBytes);
        print('[RoomAvatarService] 临时文件路径: ${tempFile.path}');

        // 保存到缓存
        print('[RoomAvatarService] 保存到缓存...');
        final cachedPath = await AvatarCache.instance.saveRoomAvatar(
          roomId: roomId,
          objectKey: avatarObjectKey,
          source: tempFile,
        );
        print('[RoomAvatarService] ✅ 缓存保存成功: $cachedPath');

        // 清理临时文件
        await tempFile.delete();
        await tempDir.delete(recursive: true);
        print('[RoomAvatarService] 临时文件已清理');

        print('[RoomAvatarService] ========== 加载完成 ==========');
        return cachedPath;
      } else {
        print('[RoomAvatarService] ❌ 下载失败，状态码: ${response.statusCode}');
      }
    } catch (e, stackTrace) {
      // 下载失败，返回null
      print('[RoomAvatarService] ❌ 下载异常: $e');
      print('[RoomAvatarService] 堆栈: $stackTrace');
    }

    print('[RoomAvatarService] ========== 加载失败 ==========');
    return null;
  }
}
