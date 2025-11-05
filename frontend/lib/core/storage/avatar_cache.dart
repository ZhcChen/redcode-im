import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AvatarCache {
  AvatarCache._();

  static final AvatarCache instance = AvatarCache._();
  static const _prefsKeyPrefix = 'avatar_cache_';

  Future<Directory> _ensureCacheDir() async {
    final baseDir = await getApplicationDocumentsDirectory();
    final cacheDir = Directory(p.join(baseDir.path, 'avatar_cache'));
    if (!await cacheDir.exists()) {
      await cacheDir.create(recursive: true);
    }
    return cacheDir;
  }

  Future<_AvatarCacheRecord?> _readRecord(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('$_prefsKeyPrefix$userId');
    if (raw == null || raw.isEmpty) {
      return null;
    }
    try {
      final data = jsonDecode(raw);
      if (data is Map<String, dynamic>) {
        final key = data['key'] as String?;
        final path = data['path'] as String?;
        if (key != null && path != null) {
          return _AvatarCacheRecord(key: key, path: path);
        }
      }
    } catch (_) {}
    return null;
  }

  Future<void> _writeRecord(String userId, _AvatarCacheRecord? record) async {
    final prefs = await SharedPreferences.getInstance();
    final storageKey = '$_prefsKeyPrefix$userId';
    if (record == null) {
      await prefs.remove(storageKey);
      return;
    }
    final raw = jsonEncode({'key': record.key, 'path': record.path});
    await prefs.setString(storageKey, raw);
  }

  Future<void> clear(String userId) async {
    final record = await _readRecord(userId);
    await _writeRecord(userId, null);
    if (record != null) {
      final file = File(record.path);
      if (await file.exists()) {
        await file.delete();
      }
    }
  }

  Future<String?> resolveLocalPath({
    required String userId,
    required String objectKey,
  }) async {
    final record = await _readRecord(userId);
    if (record == null || record.key != objectKey) {
      return null;
    }
    final file = File(record.path);
    if (await file.exists()) {
      return record.path;
    }
    await _writeRecord(userId, null);
    return null;
  }

  Future<String> save({
    required String userId,
    required String objectKey,
    required File source,
  }) async {
    final cacheDir = await _ensureCacheDir();
    final extension = p.extension(objectKey).isNotEmpty
        ? p.extension(objectKey)
        : p.extension(source.path);
    final safeName =
        '${userId}_${objectKey.hashCode.abs().toRadixString(16)}$extension';
    final targetPath = p.join(cacheDir.path, safeName);
    final targetFile = File(targetPath);
    if (await targetFile.exists()) {
      await targetFile.delete();
    }
    await source.copy(targetPath);
    await _writeRecord(
      userId,
      _AvatarCacheRecord(key: objectKey, path: targetPath),
    );
    return targetPath;
  }
}

class _AvatarCacheRecord {
  const _AvatarCacheRecord({required this.key, required this.path});

  final String key;
  final String path;
}
