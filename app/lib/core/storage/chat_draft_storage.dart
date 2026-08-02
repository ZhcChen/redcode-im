import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class ChatDraftStorage {
  ChatDraftStorage();

  static const _storageKey = 'chat_text_drafts_v1';
  Future<void> _pendingWrite = Future<void>.value();

  Future<String?> load({
    required String accountId,
    required String roomId,
  }) async {
    await _pendingWrite;
    final drafts = await _readDrafts();
    final value = drafts[_draftKey(accountId, roomId)];
    return value == null || value.isEmpty ? null : value;
  }

  Future<void> save({
    required String accountId,
    required String roomId,
    required String text,
  }) {
    return _enqueue(() async {
      final drafts = await _readDrafts();
      final key = _draftKey(accountId, roomId);
      if (text.trim().isEmpty) {
        drafts.remove(key);
      } else {
        drafts[key] = text;
      }
      await _writeDrafts(drafts);
    });
  }

  Future<void> clear({required String accountId, required String roomId}) {
    return save(accountId: accountId, roomId: roomId, text: '');
  }

  Future<void> _enqueue(Future<void> Function() operation) {
    final result = _pendingWrite.then((_) => operation());
    _pendingWrite = result.catchError((_) {});
    return result;
  }

  Future<Map<String, String>> _readDrafts() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw == null || raw.isEmpty) return <String, String>{};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return <String, String>{};
      return decoded.map(
        (key, value) => MapEntry(key.toString(), value.toString()),
      );
    } catch (_) {
      return <String, String>{};
    }
  }

  Future<void> _writeDrafts(Map<String, String> drafts) async {
    final prefs = await SharedPreferences.getInstance();
    if (drafts.isEmpty) {
      await prefs.remove(_storageKey);
      return;
    }
    await prefs.setString(_storageKey, jsonEncode(drafts));
  }

  String _draftKey(String accountId, String roomId) =>
      '${Uri.encodeComponent(accountId)}:${Uri.encodeComponent(roomId)}';
}
