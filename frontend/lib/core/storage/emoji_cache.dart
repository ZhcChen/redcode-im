import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class EmojiCache {
  EmojiCache._();

  static final EmojiCache instance = EmojiCache._();
  static const _prefsKeyPrefix = 'emoji_cache_';

  Future<Directory> _ensureCacheDir() async {
    final baseDir = await getApplicationDocumentsDirectory();
    final cacheDir = Directory(p.join(baseDir.path, 'emoji_cache'));
    if (!await cacheDir.exists()) {
      await cacheDir.create(recursive: true);
    }
    return cacheDir;
  }

  /// 清除表情缓存
  Future<void> clear(String imageUrl) async {
    final record = await _readRecord(imageUrl);
    await _writeRecord(imageUrl, null);
    if (record != null) {
      final file = File(record.path);
      if (await file.exists()) {
        await file.delete();
      }
    }
  }

  /// 解析表情本地缓存路径
  Future<String?> resolveLocalPath(String imageUrl) async {
    final record = await _readRecord(imageUrl);
    if (record == null) {
      return null;
    }
    final file = File(record.path);
    if (await file.exists()) {
      return record.path;
    }
    await _writeRecord(imageUrl, null);
    return null;
  }

  /// 保存表情到缓存
  Future<String> save({
    required String imageUrl,
    required File source,
  }) async {
    final cacheDir = await _ensureCacheDir();
    // 从 URL 中提取文件扩展名，如果没有则从源文件获取
    final urlExtension = _getExtensionFromUrl(imageUrl);
    final extension = urlExtension.isNotEmpty
        ? urlExtension
        : p.extension(source.path);
    
    // 使用 URL 的 hash 作为文件名
    final safeName = '${imageUrl.hashCode.abs().toRadixString(16)}$extension';
    final targetPath = p.join(cacheDir.path, safeName);
    final targetFile = File(targetPath);
    if (await targetFile.exists()) {
      await targetFile.delete();
    }
    await source.copy(targetPath);
    await _writeRecord(
      imageUrl,
      _EmojiCacheRecord(imageUrl: imageUrl, path: targetPath),
    );
    return targetPath;
  }

  /// 从 URL 中提取文件扩展名
  String _getExtensionFromUrl(String url) {
    try {
      final uri = Uri.parse(url);
      final path = uri.path;
      final ext = p.extension(path);
      return ext;
    } catch (_) {
      return '';
    }
  }

  // --- 私有方法 ---

  Future<_EmojiCacheRecord?> _readRecord(String imageUrl) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '$_prefsKeyPrefix${imageUrl.hashCode.abs()}';
    final raw = prefs.getString(key);
    if (raw == null || raw.isEmpty) {
      return null;
    }
    try {
      final data = jsonDecode(raw);
      if (data is Map<String, dynamic>) {
        final url = data['imageUrl'] as String?;
        final path = data['path'] as String?;
        // 验证 URL 是否匹配（防止 hash 冲突）
        if (url != null && path != null && url == imageUrl) {
          return _EmojiCacheRecord(imageUrl: url, path: path);
        }
      }
    } catch (_) {}
    return null;
  }

  Future<void> _writeRecord(String imageUrl, _EmojiCacheRecord? record) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '$_prefsKeyPrefix${imageUrl.hashCode.abs()}';
    if (record == null) {
      await prefs.remove(key);
      return;
    }
    final raw = jsonEncode({'imageUrl': record.imageUrl, 'path': record.path});
    await prefs.setString(key, raw);
  }
}

class _EmojiCacheRecord {
  const _EmojiCacheRecord({required this.imageUrl, required this.path});

  final String imageUrl;
  final String path;
}

