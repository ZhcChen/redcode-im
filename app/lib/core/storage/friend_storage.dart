import 'dart:async';
import 'dart:convert';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../../features/contacts/models/friend_models.dart';

/// 联系人列表本地存储（基于 SQLite）
class FriendStorage {
  const FriendStorage();

  static const _databaseName = 'friend_cache.db';
  static const _friendTable = 'friends';

  static Future<Database>? _databaseFuture;

  /// 加载缓存的联系人列表
  Future<List<FriendInfo>> loadFriends() async {
    final db = await _openDatabase();
    final rows = await db.query(_friendTable, orderBy: 'created_at ASC');

    final friends = <FriendInfo>[];
    for (final row in rows) {
      final parsed = _friendFromRow(row);
      if (parsed != null) {
        friends.add(parsed);
      }
    }
    return friends;
  }

  /// 保存联系人列表到缓存
  Future<void> saveFriends(List<FriendInfo> friends) async {
    final db = await _openDatabase();

    await db.transaction((txn) async {
      // 清空旧数据
      await txn.delete(_friendTable);

      // 插入新数据
      for (final friend in friends) {
        await txn.insert(
          _friendTable,
          _rowFromFriend(friend),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  /// 清空所有缓存
  Future<void> clearAll() async {
    final db = await _openDatabase();
    await db.transaction((txn) async {
      await txn.delete(_friendTable);
    });
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
          CREATE TABLE $_friendTable (
            id TEXT PRIMARY KEY,
            user_id TEXT NOT NULL,
            created_at INTEGER NOT NULL,
            payload TEXT NOT NULL
          )
        ''');
        await db.execute('''
          CREATE INDEX idx_${_friendTable}_user_id
          ON $_friendTable (user_id)
        ''');
      },
    );
  }

  Map<String, Object?> _rowFromFriend(FriendInfo friend) {
    return {
      'id': friend.id,
      'user_id': friend.user.id,
      'created_at': friend.createdAt.millisecondsSinceEpoch,
      'payload': jsonEncode({
        'id': friend.id,
        'user': friend.user.toJson(),
        'created_at': friend.createdAt.toIso8601String(),
      }),
    };
  }

  FriendInfo? _friendFromRow(Map<String, Object?> row) {
    final payload = row['payload'];
    if (payload is! String || payload.isEmpty) {
      return null;
    }

    try {
      final decoded = jsonDecode(payload);
      if (decoded is Map<String, dynamic>) {
        return FriendInfo.fromJson(decoded);
      }
      if (decoded is Map) {
        final normalized = <String, dynamic>{};
        decoded.forEach((key, value) {
          normalized[key.toString()] = value;
        });
        return FriendInfo.fromJson(normalized);
      }
    } catch (_) {
      // 忽略单条解析失败的数据，保留其它记录
    }
    return null;
  }
}
