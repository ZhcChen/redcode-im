import 'dart:async';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../../features/chat/models/message_model.dart';

class MessageSearchResult {
  const MessageSearchResult({
    required this.id,
    required this.roomId,
    required this.roomName,
    required this.senderId,
    required this.senderName,
    required this.content,
    required this.messageType,
    required this.timestampMs,
    required this.relevanceScore,
    this.matchedText,
  });

  final String id;
  final String roomId;
  final String roomName;
  final String senderId;
  final String senderName;
  final String content;
  final String messageType;
  final int timestampMs;
  final double relevanceScore;
  final String? matchedText;

  DateTime get timestamp => DateTime.fromMillisecondsSinceEpoch(timestampMs);
}

class MessageSearchStats {
  const MessageSearchStats({
    required this.totalResults,
    required this.searchTimeMs,
    required this.query,
  });

  final int totalResults;
  final int searchTimeMs;
  final String query;
}

class MessageSearchResponse {
  const MessageSearchResponse({
    required this.results,
    required this.stats,
    required this.hasMore,
  });

  final List<MessageSearchResult> results;
  final MessageSearchStats stats;
  final bool hasMore;
}

/// 本地消息搜索索引（SQLite FTS5）
///
/// 设计目标：
/// - 对齐 desktop 端的本地索引搜索体验：先出本地结果，再可融合服务端搜索结果
/// - 索引字段：room_name / sender_name / content
class MessageSearchStorage {
  const MessageSearchStorage();

  static const _databaseName = 'message_search.db';
  static const _table = 'message_search';
  static const _defaultLimit = 50;

  static Future<Database>? _databaseFuture;

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
          CREATE VIRTUAL TABLE IF NOT EXISTS $_table USING fts5(
            id UNINDEXED,
            room_id UNINDEXED,
            room_name,
            sender_id UNINDEXED,
            sender_name,
            content,
            message_type UNINDEXED,
            timestamp UNINDEXED
          );
        ''');
      },
    );
  }

  String _normalizeContent(Message message) {
    final trimmed = message.content.trim();
    if (trimmed.isNotEmpty) {
      return trimmed;
    }
    switch (message.type) {
      case MessageType.image:
        return '[图片]';
      case MessageType.audio:
        return '[语音]';
      case MessageType.video:
        return '[视频]';
      case MessageType.file:
        return '[文件]';
      case MessageType.system:
        return '[系统消息]';
      case MessageType.mixed:
        return '[多媒体消息]';
      case MessageType.text:
        return '[消息]';
    }
  }

  /// 替换某个房间的索引（用于保证与本地缓存一致，避免 FTS 表重复记录）
  Future<void> replaceRoomIndex({
    required String roomId,
    required String roomName,
    required List<Message> messages,
    int maxMessages = 200,
  }) async {
    if (roomId.isEmpty) return;

    final db = await _openDatabase();
    final trimmed = messages.length > maxMessages
        ? messages.sublist(messages.length - maxMessages)
        : messages;

    await db.transaction((txn) async {
      await txn.delete(_table, where: 'room_id = ?', whereArgs: [roomId]);

      for (final message in trimmed) {
        if (message.id.isEmpty) continue;
        if (message.isDeleted) continue;

        await txn.insert(_table, {
          'id': message.id,
          'room_id': roomId,
          'room_name': roomName,
          'sender_id': message.senderId,
          'sender_name': message.displaySenderName,
          'content': _normalizeContent(message),
          'message_type': message.type.name,
          'timestamp': message.timestamp.millisecondsSinceEpoch,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
  }

  String _processSearchQuery(String query) {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return '';

    // 如果包含高级语法，直接返回（与 desktop 端一致）
    if (trimmed.contains('"') ||
        trimmed.contains('AND') ||
        trimmed.contains('OR') ||
        trimmed.contains('NOT')) {
      return trimmed;
    }

    final words = trimmed
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toList();
    if (words.isEmpty) return '';
    if (words.length == 1) {
      return '"${words.first}"*';
    }
    return words.map((w) => '"$w"*').join(' AND ');
  }

  Future<MessageSearchResponse> searchMessages({
    required String query,
    String? roomId,
    String? senderId,
    String? messageType,
    int? dateFromMs,
    int? dateToMs,
    int limit = _defaultLimit,
    int offset = 0,
  }) async {
    final stopwatch = Stopwatch()..start();

    final normalizedQuery = query.trim();
    if (normalizedQuery.isEmpty) {
      return const MessageSearchResponse(
        results: [],
        stats: MessageSearchStats(totalResults: 0, searchTimeMs: 0, query: ''),
        hasMore: false,
      );
    }

    final ftsQuery = _processSearchQuery(normalizedQuery);
    if (ftsQuery.isEmpty) {
      return MessageSearchResponse(
        results: const [],
        stats: MessageSearchStats(
          totalResults: 0,
          searchTimeMs: 0,
          query: normalizedQuery,
        ),
        hasMore: false,
      );
    }

    final conditions = <String>[];
    final args = <Object?>[];

    conditions.add('$_table MATCH ?');
    args.add(ftsQuery);

    if (roomId != null && roomId.trim().isNotEmpty) {
      conditions.add('room_id = ?');
      args.add(roomId.trim());
    }

    if (senderId != null && senderId.trim().isNotEmpty) {
      conditions.add('sender_id = ?');
      args.add(senderId.trim());
    }

    if (messageType != null && messageType.trim().isNotEmpty) {
      conditions.add('message_type = ?');
      args.add(messageType.trim());
    }

    if (dateFromMs != null) {
      conditions.add('timestamp >= ?');
      args.add(dateFromMs);
    }

    if (dateToMs != null) {
      conditions.add('timestamp <= ?');
      args.add(dateToMs);
    }

    final whereClause = conditions.isEmpty ? '1' : conditions.join(' AND ');
    final db = await _openDatabase();

    final countRows = await db.rawQuery(
      'SELECT COUNT(1) AS total FROM $_table WHERE $whereClause',
      args,
    );
    final total =
        (countRows.isNotEmpty ? countRows.first['total'] : 0) as int? ?? 0;

    final queryArgs = <Object?>[
      ...args,
      limit.clamp(1, 100),
      offset < 0 ? 0 : offset,
    ];
    final rows = await db.rawQuery('''
        SELECT
          id,
          room_id,
          room_name,
          sender_id,
          sender_name,
          snippet($_table, 5, '<mark>', '</mark>', '...', 20) AS matched_text,
          content,
          message_type,
          timestamp,
          bm25($_table) AS relevance_score
        FROM $_table
        WHERE $whereClause
        ORDER BY relevance_score, timestamp DESC
        LIMIT ? OFFSET ?
      ''', queryArgs);

    final results = <MessageSearchResult>[];
    for (final row in rows) {
      results.add(
        MessageSearchResult(
          id: (row['id'] ?? '').toString(),
          roomId: (row['room_id'] ?? '').toString(),
          roomName: (row['room_name'] ?? '').toString(),
          senderId: (row['sender_id'] ?? '').toString(),
          senderName: (row['sender_name'] ?? '').toString(),
          matchedText: row['matched_text']?.toString(),
          content: (row['content'] ?? '').toString(),
          messageType: (row['message_type'] ?? 'text').toString(),
          timestampMs: (row['timestamp'] as int?) ?? 0,
          relevanceScore: (row['relevance_score'] as num?)?.toDouble() ?? 0,
        ),
      );
    }

    stopwatch.stop();
    final hasMore = (offset + results.length) < total;

    return MessageSearchResponse(
      results: results,
      stats: MessageSearchStats(
        totalResults: total,
        searchTimeMs: stopwatch.elapsedMilliseconds,
        query: normalizedQuery,
      ),
      hasMore: hasMore,
    );
  }
}
