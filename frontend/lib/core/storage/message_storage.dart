import 'dart:async';
import 'dart:convert';

import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

import '../../features/chat/models/message_model.dart';

/// 聊天消息本地存储（基于 SQLite，兼容旧版 SharedPreferences 数据）
class MessageStorage {
  const MessageStorage();

  static const _legacyKeyPrefix = 'chat_messages_';
  static const _maxCacheCount = 200;
  static const _databaseName = 'message_cache.db';
  static const _messageTable = 'messages';

  static Future<Database>? _databaseFuture;

  Future<List<Message>> loadMessages(String roomId) async {
    if (roomId.isEmpty) {
      return const [];
    }

    final db = await _openDatabase();
    final rows = await db.query(
      _messageTable,
      where: 'room_id = ?',
      whereArgs: [roomId],
      orderBy: 'timestamp ASC',
    );

    if (rows.isEmpty) {
      return _tryMigrateFromSharedPreferences(db, roomId);
    }

    final messages = <Message>[];
    for (final row in rows) {
      final parsed = _messageFromRow(row);
      if (parsed != null) {
        messages.add(parsed);
      }
    }
    return messages;
  }

  Future<void> saveMessages(String roomId, List<Message> messages) async {
    if (roomId.isEmpty) {
      return;
    }

    final db = await _openDatabase();
    final trimmed = messages.length > _maxCacheCount
        ? messages.sublist(messages.length - _maxCacheCount)
        : messages;

    await db.transaction((txn) async {
      await txn.delete(
        _messageTable,
        where: 'room_id = ?',
        whereArgs: [roomId],
      );

      for (final message in trimmed) {
        await txn.insert(
          _messageTable,
          _rowFromMessage(roomId, message),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  Future<void> clear(String roomId) async {
    if (roomId.isEmpty) {
      return;
    }

    final db = await _openDatabase();
    await db.delete(_messageTable, where: 'room_id = ?', whereArgs: [roomId]);

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_legacyKeyPrefix$roomId');
  }

  Future<void> clearAll() async {
    final db = await _openDatabase();
    await db.transaction((txn) async {
      await txn.delete(_messageTable);
    });

    final prefs = await SharedPreferences.getInstance();
    final keys = prefs
        .getKeys()
        .where((key) => key.startsWith(_legacyKeyPrefix))
        .toList();
    for (final key in keys) {
      await prefs.remove(key);
    }
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
          CREATE TABLE $_messageTable (
            id TEXT PRIMARY KEY,
            room_id TEXT NOT NULL,
            timestamp INTEGER NOT NULL,
            payload TEXT NOT NULL
          )
        ''');
        await db.execute('''
          CREATE INDEX idx_${_messageTable}_room_timestamp
          ON $_messageTable (room_id, timestamp)
        ''');
      },
    );
  }

  Map<String, Object?> _rowFromMessage(String roomId, Message message) {
    return {
      'id': message.id,
      'room_id': roomId,
      'timestamp': message.timestamp.millisecondsSinceEpoch,
      'payload': jsonEncode(message.toCacheJson()),
    };
  }

  Message? _messageFromRow(Map<String, Object?> row) {
    final payload = row['payload'];
    if (payload is! String || payload.isEmpty) {
      return null;
    }

    try {
      final decoded = jsonDecode(payload);
      if (decoded is Map<String, dynamic>) {
        return Message.fromCacheJson(decoded);
      }
      if (decoded is Map) {
        final normalized = <String, dynamic>{};
        decoded.forEach((key, value) {
          normalized[key.toString()] = value;
        });
        return Message.fromCacheJson(normalized);
      }
    } catch (_) {
      // 忽略单条解析失败的数据，保留其它记录
    }
    return null;
  }

  Future<List<Message>> _tryMigrateFromSharedPreferences(
    Database db,
    String roomId,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('$_legacyKeyPrefix$roomId');
    if (raw == null || raw.isEmpty) {
      return const [];
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        await prefs.remove('$_legacyKeyPrefix$roomId');
        return const [];
      }

      final messages = <Message>[];
      for (final item in decoded) {
        if (item is Map<String, dynamic>) {
          messages.add(Message.fromCacheJson(item));
        } else if (item is Map) {
          final normalized = <String, dynamic>{};
          item.forEach((key, value) {
            normalized[key.toString()] = value;
          });
          messages.add(Message.fromCacheJson(normalized));
        }
      }

      if (messages.isEmpty) {
        await prefs.remove('$_legacyKeyPrefix$roomId');
        return const [];
      }

      messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));

      await db.transaction((txn) async {
        await txn.delete(
          _messageTable,
          where: 'room_id = ?',
          whereArgs: [roomId],
        );

        final trimmed = messages.length > _maxCacheCount
            ? messages.sublist(messages.length - _maxCacheCount)
            : messages;

        for (final message in trimmed) {
          await txn.insert(
            _messageTable,
            _rowFromMessage(roomId, message),
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      });

      await prefs.remove('$_legacyKeyPrefix$roomId');
      return messages;
    } catch (_) {
      await prefs.remove('$_legacyKeyPrefix$roomId');
      return const [];
    }
  }
}
