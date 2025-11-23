import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

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
        // 保存到临时文件
        final tempDir = await Directory.systemTemp.createTemp();
        final tempFile = File(
          '${tempDir.path}/emoji_${DateTime.now().millisecondsSinceEpoch}',
        );
        await tempFile.writeAsBytes(response.bodyBytes);

        // 保存到缓存
        final cachedPath = await EmojiCache.instance.save(
          imageUrl: imageUrl,
          source: tempFile,
        );

        // 清理临时文件
        await tempFile.delete();
        await tempDir.delete(recursive: true);

        return cachedPath;
      }
    } catch (e) {
      // 下载失败，返回null
      debugPrint('加载表情失败: $e');
    }

    return null;
  }
}
