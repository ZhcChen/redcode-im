import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// 应用配置本地存储（基于 SQLite）
class AppConfigStorage {
  const AppConfigStorage();

  static const _databaseName = 'app_config.db';
  static const _configTable = 'app_config';
  static const _keyAppName = 'app_name';

  static Future<Database>? _databaseFuture;

  /// 获取应用名称
  Future<String?> getAppName() async {
    final db = await _openDatabase();
    final rows = await db.query(
      _configTable,
      where: 'key = ?',
      whereArgs: [_keyAppName],
      limit: 1,
    );

    if (rows.isEmpty) {
      return null;
    }

    return rows.first['value'] as String?;
  }

  /// 保存应用名称
  Future<void> saveAppName(String appName) async {
    final db = await _openDatabase();
    await db.insert(_configTable, {
      'key': _keyAppName,
      'value': appName,
      'updated_at': DateTime.now().millisecondsSinceEpoch,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// 清空所有配置
  Future<void> clearAll() async {
    final db = await _openDatabase();
    await db.delete(_configTable);
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
