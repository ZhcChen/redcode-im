/// 附件 URL 内存缓存
///
/// 提供内存级别的附件路径缓存，避免频繁访问文件系统。
/// 类似 desktop 端的 `attachmentUrlCache`。
class AttachmentUrlCache {
  AttachmentUrlCache._();

  static final AttachmentUrlCache instance = AttachmentUrlCache._();

  final _cache = <String, _CacheEntry>{};
  static const _defaultTtl = Duration(minutes: 10);

  /// 获取缓存的本地路径
  String? get(String key) {
    final entry = _cache[key];
    if (entry == null) return null;
    if (DateTime.now().isAfter(entry.expiresAt)) {
      _cache.remove(key);
      return null;
    }
    return entry.localPath;
  }

  /// 设置缓存
  void set(String key, String localPath, {Duration? ttl}) {
    _cache[key] = _CacheEntry(
      localPath: localPath,
      expiresAt: DateTime.now().add(ttl ?? _defaultTtl),
    );
  }

  /// 移除指定缓存
  void remove(String key) => _cache.remove(key);

  /// 清空所有缓存
  void clear() => _cache.clear();

  /// 获取缓存数量（用于调试）
  int get length => _cache.length;

  /// 清理过期缓存
  void cleanup() {
    final now = DateTime.now();
    _cache.removeWhere((_, entry) => now.isAfter(entry.expiresAt));
  }
}

class _CacheEntry {
  final String localPath;
  final DateTime expiresAt;

  _CacheEntry({
    required this.localPath,
    required this.expiresAt,
  });
}

