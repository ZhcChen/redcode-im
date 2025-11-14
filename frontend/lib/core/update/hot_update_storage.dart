import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import 'hot_update_models.dart';

class HotUpdateStorage {
  HotUpdateStorage(this._prefs);

  final SharedPreferences _prefs;

  static const _installedKey = 'hot_update.installed';
  static const _downloadedKey = 'hot_update.downloaded';
  static const _clientIdKey = 'hot_update.client_id';

  static Future<HotUpdateStorage> create() async {
    final prefs = await SharedPreferences.getInstance();
    return HotUpdateStorage(prefs);
  }

  InstalledHotPatchInfo? loadInstalledPatch() {
    final text = _prefs.getString(_installedKey);
    if (text == null || text.isEmpty) return null;
    try {
      final Map<String, dynamic> json =
          jsonDecode(text) as Map<String, dynamic>;
      return InstalledHotPatchInfo.fromJson(json);
    } catch (_) {
      return null;
    }
  }

  Future<void> saveInstalledPatch(InstalledHotPatchInfo info) async {
    await _prefs.setString(_installedKey, jsonEncode(info.toJson()));
  }

  Future<void> clearInstalledPatch() async {
    await _prefs.remove(_installedKey);
  }

  HotUpdateDownloadRecord? loadDownloadedPatch() {
    final text = _prefs.getString(_downloadedKey);
    if (text == null || text.isEmpty) return null;
    try {
      final Map<String, dynamic> json =
          jsonDecode(text) as Map<String, dynamic>;
      return HotUpdateDownloadRecord.fromJson(json);
    } catch (_) {
      return null;
    }
  }

  Future<void> saveDownloadedPatch(HotUpdateDownloadRecord record) async {
    await _prefs.setString(_downloadedKey, jsonEncode(record.toJson()));
  }

  Future<void> clearDownloadedPatch() async {
    await _prefs.remove(_downloadedKey);
  }

  Future<String> ensureClientId() async {
    final existing = _prefs.getString(_clientIdKey);
    if (existing != null && existing.isNotEmpty) {
      return existing;
    }
    final generated = const Uuid().v4();
    await _prefs.setString(_clientIdKey, generated);
    return generated;
  }
}
