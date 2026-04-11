import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../services/settings_service.dart';

/// 应用配置本地存储（基于 SQLite）
class AppConfigStorage {
  const AppConfigStorage();

  static const _databaseName = 'app_config.db';
  static const _configTable = 'app_config';
  static const _keyAppName = 'app_name';
  static const _keyServerStorageMode = 'server_storage_mode';
  static const _keyContentAuditMode = 'content_audit_mode';

  static Future<Database>? _databaseFuture;

  /// 获取应用名称
  Future<String?> getAppName() async {
    return _getValue(_keyAppName);
  }

  /// 保存应用名称
  Future<void> saveAppName(String appName) async {
    await _saveValue(_keyAppName, appName);
  }

  /// 获取消息运行模式
  Future<MessageRuntimeSettings?> getMessageRuntime() async {
    final serverStorageMode = await _getValue(_keyServerStorageMode);
    final contentAuditMode = await _getValue(_keyContentAuditMode);
    if (serverStorageMode == null && contentAuditMode == null) {
      return null;
    }
    return MessageRuntimeSettings(
      serverStorageMode: serverStorageMode?.trim().isNotEmpty == true
          ? serverStorageMode!
          : MessageRuntimeSettings.defaults.serverStorageMode,
      contentAuditMode: contentAuditMode?.trim().isNotEmpty == true
          ? contentAuditMode!
          : MessageRuntimeSettings.defaults.contentAuditMode,
    );
  }

  /// 保存消息运行模式
  Future<void> saveMessageRuntime(MessageRuntimeSettings runtime) async {
    await _saveValue(_keyServerStorageMode, runtime.serverStorageMode);
    await _saveValue(_keyContentAuditMode, runtime.contentAuditMode);
  }

  /// 清空所有配置
  Future<void> clearAll() async {
    final db = await _openDatabase();
    await db.delete(_configTable);
  }

  Future<String?> _getValue(String key) async {
    final db = await _openDatabase();
    final rows = await db.query(
      _configTable,
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );

    if (rows.isEmpty) {
      return null;
    }

    return rows.first['value'] as String?;
  }

  Future<void> _saveValue(String key, String value) async {
    final db = await _openDatabase();
    await db.insert(_configTable, {
      'key': key,
      'value': value,
      'updated_at': DateTime.now().millisecondsSinceEpoch,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  static Future<Database> _openDatabase() {
    final existing = _databaseFuture;
    if (existing != null) {
      return existing;
    }
    final future = _initDatabase();
    _databaseFuture = future;
    return future;
  }

  static Future<Database> _initDatabase() async {
    final databasesPath = await getDatabasesPath();
    final path = p.join(databasesPath, _databaseName);

    return openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE $_configTable (
            key TEXT PRIMARY KEY,
            value TEXT NOT NULL,
            updated_at INTEGER NOT NULL
          )
        ''');
      },
    );
  }
}
