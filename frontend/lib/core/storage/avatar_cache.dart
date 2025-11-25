import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AvatarCache {
  AvatarCache._();

  static final AvatarCache instance = AvatarCache._();
  static const _userPrefsKeyPrefix = 'user_avatar_cache_';
  static const _roomPrefsKeyPrefix = 'room_avatar_cache_';

  /// 缓存 TTL (7 天)
  static const Duration cacheTtl = Duration(days: 7);

  Future<Directory> _ensureUserCacheDir() async {
    final baseDir = await getApplicationDocumentsDirectory();
    final cacheDir = Directory(p.join(baseDir.path, 'user_avatar_cache'));
    if (!await cacheDir.exists()) {
      await cacheDir.create(recursive: true);
    }
    return cacheDir;
  }

  Future<Directory> _ensureRoomCacheDir() async {
    final baseDir = await getApplicationDocumentsDirectory();
    final cacheDir = Directory(p.join(baseDir.path, 'room_avatar_cache'));
    if (!await cacheDir.exists()) {
      await cacheDir.create(recursive: true);
    }
    return cacheDir;
  }

  /// 清除用户头像缓存
  Future<void> clearUser(String userId) async {
    final record = await _readUserRecord(userId);
    await _writeUserRecord(userId, null);
    if (record != null) {
      final file = File(record.path);
      if (await file.exists()) {
        await file.delete();
      }
    }
  }

  /// 清除房间头像缓存
  Future<void> clearRoom(String roomId) async {
    final record = await _readRoomRecord(roomId);
    await _writeRoomRecord(roomId, null);
    if (record != null) {
      final file = File(record.path);
      if (await file.exists()) {
        await file.delete();
      }
    }
  }

  /// 解析用户头像本地缓存路径
  /// 会验证 objectKey 是否匹配且缓存未过期
  Future<String?> resolveUserLocalPath({
    required String userId,
    required String objectKey,
  }) async {
    final record = await _readUserRecord(userId);
    if (record == null || record.key != objectKey) {
      return null;
    }
    // 检查 TTL
    if (record.isExpired(cacheTtl)) {
      await clearUser(userId);
      return null;
    }
    final file = File(record.path);
    if (await file.exists()) {
      return record.path;
    }
    await _writeUserRecord(userId, null);
    return null;
  }

  /// 解析房间头像本地缓存路径
  /// 会验证 objectKey 是否匹配且缓存未过期
  Future<String?> resolveRoomLocalPath({
    required String roomId,
    required String objectKey,
  }) async {
    final record = await _readRoomRecord(roomId);
    if (record == null || record.key != objectKey) {
      return null;
    }
    // 检查 TTL
    if (record.isExpired(cacheTtl)) {
      await clearRoom(roomId);
      return null;
    }
    final file = File(record.path);
    if (await file.exists()) {
      return record.path;
    }
    await _writeRoomRecord(roomId, null);
    return null;
  }

  /// 解析任何已存在的用户头像本地缓存路径
  /// 不检查objectKey，只要有缓存且未过期就返回
  Future<String?> resolveAnyLocalPath(String userId) async {
    final record = await _readUserRecord(userId);
    if (record == null) {
      return null;
    }
    // 检查 TTL
    if (record.isExpired(cacheTtl)) {
      await clearUser(userId);
      return null;
    }
    final file = File(record.path);
    if (await file.exists()) {
      return record.path;
    }
    await _writeUserRecord(userId, null);
    return null;
  }

  /// 保存用户头像到缓存
  Future<String> saveUserAvatar({
    required String userId,
    required String objectKey,
    required File source,
  }) async {
    final cacheDir = await _ensureUserCacheDir();
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
    await _writeUserRecord(
      userId,
      _AvatarCacheRecord(
        key: objectKey,
        path: targetPath,
        cachedAt: DateTime.now(),
      ),
    );
    return targetPath;
  }

  /// 保存房间头像到缓存
  Future<String> saveRoomAvatar({
    required String roomId,
    required String objectKey,
    required File source,
  }) async {
    final cacheDir = await _ensureRoomCacheDir();
    final extension = p.extension(objectKey).isNotEmpty
        ? p.extension(objectKey)
        : p.extension(source.path);
    final safeName =
        '${roomId}_${objectKey.hashCode.abs().toRadixString(16)}$extension';
    final targetPath = p.join(cacheDir.path, safeName);
    final targetFile = File(targetPath);
    if (await targetFile.exists()) {
      await targetFile.delete();
    }
    await source.copy(targetPath);
    await _writeRoomRecord(
      roomId,
      _AvatarCacheRecord(
        key: objectKey,
        path: targetPath,
        cachedAt: DateTime.now(),
      ),
    );
    return targetPath;
  }

  // --- 私有方法 ---

  Future<_AvatarCacheRecord?> _readUserRecord(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('$_userPrefsKeyPrefix$userId');
    if (raw == null || raw.isEmpty) {
      return null;
    }
    try {
      final data = jsonDecode(raw);
      if (data is Map<String, dynamic>) {
        final key = data['key'] as String?;
        final path = data['path'] as String?;
        final cachedAtStr = data['cachedAt'] as String?;
        if (key != null && path != null) {
          // 向后兼容：如果没有 cachedAt，使用当前时间（视为刚缓存）
          final cachedAt = cachedAtStr != null
              ? DateTime.tryParse(cachedAtStr) ?? DateTime.now()
              : DateTime.now();
          return _AvatarCacheRecord(key: key, path: path, cachedAt: cachedAt);
        }
      }
    } catch (_) {}
    return null;
  }

  Future<_AvatarCacheRecord?> _readRoomRecord(String roomId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('$_roomPrefsKeyPrefix$roomId');
    if (raw == null || raw.isEmpty) {
      return null;
    }
    try {
      final data = jsonDecode(raw);
      if (data is Map<String, dynamic>) {
        final key = data['key'] as String?;
        final path = data['path'] as String?;
        final cachedAtStr = data['cachedAt'] as String?;
        if (key != null && path != null) {
          // 向后兼容：如果没有 cachedAt，使用当前时间（视为刚缓存）
          final cachedAt = cachedAtStr != null
              ? DateTime.tryParse(cachedAtStr) ?? DateTime.now()
              : DateTime.now();
          return _AvatarCacheRecord(key: key, path: path, cachedAt: cachedAt);
        }
      }
    } catch (_) {}
    return null;
  }

  Future<void> _writeUserRecord(
    String userId,
    _AvatarCacheRecord? record,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final storageKey = '$_userPrefsKeyPrefix$userId';
    if (record == null) {
      await prefs.remove(storageKey);
      return;
    }
    final raw = jsonEncode({
      'key': record.key,
      'path': record.path,
      'cachedAt': record.cachedAt.toIso8601String(),
    });
    await prefs.setString(storageKey, raw);
  }

  Future<void> _writeRoomRecord(
    String roomId,
    _AvatarCacheRecord? record,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final storageKey = '$_roomPrefsKeyPrefix$roomId';
    if (record == null) {
      await prefs.remove(storageKey);
      return;
    }
    final raw = jsonEncode({
      'key': record.key,
      'path': record.path,
      'cachedAt': record.cachedAt.toIso8601String(),
    });
    await prefs.setString(storageKey, raw);
  }

  // --- 向后兼容的旧方法 ---
  // 这些方法现在标记为废弃，建议使用专门的方法

  @Deprecated('使用 clearUser 代替')
  Future<void> clear(String id) async {
    // 尝试判断是用户ID还是房间ID来决定调用哪个方法
    // 这是一个临时解决方案，未来应该移除这个方法
    // 这里我们调用两个方法来确保清理
    await clearUser(id);
    await clearRoom(id);
  }

  @Deprecated('使用 resolveUserLocalPath 代替')
  Future<String?> resolveLocalPath({
    required String userId,
    required String objectKey,
  }) async {
    return await resolveUserLocalPath(userId: userId, objectKey: objectKey);
  }

  @Deprecated('使用 saveUserAvatar 代替')
  Future<String> save({
    required String userId,
    required String objectKey,
    required File source,
  }) async {
    return await saveUserAvatar(
      userId: userId,
      objectKey: objectKey,
      source: source,
    );
  }
}

class _AvatarCacheRecord {
  const _AvatarCacheRecord({
    required this.key,
    required this.path,
    required this.cachedAt,
  });

  final String key;
  final String path;
  final DateTime cachedAt;

  /// 检查缓存是否过期
  bool isExpired(Duration ttl) {
    return DateTime.now().difference(cachedAt) > ttl;
  }
}
