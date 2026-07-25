import 'dart:io';

/// 返回本地路径是否可直接读取，用于避免已缓存文件再次进入异步占位态。
bool hasReadableLocalFile(String? path) {
  if (path == null || path.isEmpty) {
    return false;
  }
  return File(path).existsSync();
}
