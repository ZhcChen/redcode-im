import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../storage/emoji_cache.dart';

class EmojiItemService {
  EmojiItemService();

  /// 加载并缓存表情图片
  /// 返回本地缓存路径，如果加载失败返回null
  Future<String?> loadAndCacheEmoji(String imageUrl) async {
    if (imageUrl.isEmpty) {
      return null;
    }

    // 先检查本地缓存
    final cachedPath = await EmojiCache.instance.resolveLocalPath(imageUrl);
    if (cachedPath != null) {
      return cachedPath;
    }

    try {
      // 下载表情图片
      final response = await http.get(Uri.parse(imageUrl));

      if (response.statusCode == 200) {
        // 保存到临时文件（使用 app 沙盒目录，避免 Directory.systemTemp 在部分设备不可写）
        final tempDir = await getTemporaryDirectory();
        final tempFile = File(
          '${tempDir.path}/emoji_${DateTime.now().millisecondsSinceEpoch}',
        );
        try {
          await tempFile.writeAsBytes(response.bodyBytes, flush: true);
          // 保存到缓存
          return await EmojiCache.instance.save(
            imageUrl: imageUrl,
            source: tempFile,
          );
        } finally {
          if (await tempFile.exists()) {
            await tempFile.delete();
          }
        }
      }
    } catch (e) {
      // 下载失败，返回null
      debugPrint('加载表情失败: $e');
    }

    return null;
  }
}
