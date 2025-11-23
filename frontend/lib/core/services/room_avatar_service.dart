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
    try {
      final headers = await _authHeaders();
      final uri = Uri.parse('${AppConfig.apiBaseUrl}/rooms/$roomId/avatar/url')
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
    } catch (e, stackTrace) {
      debugPrint('获取群头像下载地址失败 room=$roomId err=$e');
    }
    return null;
  }

  /// 加载并缓存房间头像
  /// 返回本地缓存路径，如果加载失败返回null
  Future<String?> loadAndCacheAvatar({
    required String roomId,
    required String? avatarObjectKey,
  }) async {
    if (avatarObjectKey == null || avatarObjectKey.isEmpty) {
      await AvatarCache.instance.clearRoom(roomId);
      return null;
    }

    // 先检查本地缓存
    final cachedPath = await AvatarCache.instance.resolveRoomLocalPath(
      roomId: roomId,
      objectKey: avatarObjectKey,
    );
    if (cachedPath != null) {
      return cachedPath;
    }

    // 尝试获取临时下载地址
    final downloadUrl = await getAvatarDownloadUrl(roomId);
    if (downloadUrl == null) {
      // 如果无法获取下载地址，返回null（显示默认头像）
      return null;
    }

    try {
      // 下载头像
      final response = await http.get(Uri.parse(downloadUrl));

      if (response.statusCode == 200) {
        // 保存到临时文件
        final tempDir = await Directory.systemTemp.createTemp();
        final tempFile = File(
          '${tempDir.path}/room_avatar_${DateTime.now().millisecondsSinceEpoch}',
        );
        await tempFile.writeAsBytes(response.bodyBytes);

        // 保存到缓存
        final cachedPath = await AvatarCache.instance.saveRoomAvatar(
          roomId: roomId,
          objectKey: avatarObjectKey,
          source: tempFile,
        );

        // 清理临时文件
        await tempFile.delete();
        await tempDir.delete(recursive: true);

        return cachedPath;
      }
    } catch (e, stackTrace) {
      debugPrint('群头像下载失败 room=$roomId key=$avatarObjectKey err=$e');
    }

    return null;
  }
}
