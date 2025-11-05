import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AttachmentCache {
  AttachmentCache._();

  static final AttachmentCache instance = AttachmentCache._();

  static const _prefsKeyPrefix = 'attachment_cache_';

  Future<Directory> _ensureCacheDir() async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(base.path, 'message_attachments'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  String _prefsKey(String objectKey) {
    final encoded = base64Url
        .encode(utf8.encode(objectKey))
        .replaceAll('=', '');
    return '$_prefsKeyPrefix$encoded';
  }

  Future<String?> resolve(String objectKey) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _prefsKey(objectKey);
    final path = prefs.getString(key);
    if (path == null || path.isEmpty) {
      return null;
    }
    final file = File(path);
    if (await file.exists()) {
      return path;
    }
    await prefs.remove(key);
    return null;
  }

  Future<String> saveFile({
    required String objectKey,
    required File source,
  }) async {
    final dir = await _ensureCacheDir();
    final ext = _resolveExtension(
      objectKey,
      fallback: p.extension(source.path),
    );
    final target = File(p.join(dir.path, _buildFileName(objectKey, ext)));
    if (await target.exists()) {
      await target.delete();
    }
    await source.copy(target.path);
    await _writeRecord(objectKey, target.path);
    return target.path;
  }

  Future<String> saveBytes({
    required String objectKey,
    required List<int> bytes,
    String? suggestedExtension,
  }) async {
    final dir = await _ensureCacheDir();
    final ext = _resolveExtension(objectKey, fallback: suggestedExtension);
    final target = File(p.join(dir.path, _buildFileName(objectKey, ext)));
    if (await target.exists()) {
      await target.delete();
    }
    await target.writeAsBytes(bytes, flush: true);
    await _writeRecord(objectKey, target.path);
    return target.path;
  }

  Future<void> remove(String objectKey) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _prefsKey(objectKey);
    final path = prefs.getString(key);
    if (path != null && path.isNotEmpty) {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
      }
    }
    await prefs.remove(key);
  }

  Future<void> clearAll() async {
    final dir = await _ensureCacheDir();
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs
        .getKeys()
        .where((key) => key.startsWith(_prefsKeyPrefix))
        .toList();
    for (final key in keys) {
      await prefs.remove(key);
    }
  }

  Future<void> _writeRecord(String objectKey, String path) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey(objectKey), path);
  }

  String _resolveExtension(String objectKey, {String? fallback}) {
    final extFromKey = p.extension(objectKey);
    if (extFromKey.isNotEmpty) {
      return extFromKey;
    }
    if (fallback != null && fallback.isNotEmpty) {
      return fallback;
    }
    return '.bin';
  }

  String _buildFileName(String objectKey, String extension) {
    final encoded = base64Url
        .encode(utf8.encode(objectKey))
        .replaceAll('=', '');
    final shortened = encoded.length > 24 ? encoded.substring(0, 24) : encoded;
    final safeExt = extension.startsWith('.') ? extension : '.$extension';
    return '$shortened$safeExt';
  }
}
