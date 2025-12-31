import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/app_config.dart';
import '../storage/token_storage.dart';

class AudioOnlyPolicy {
  const AudioOnlyPolicy({
    required this.enabled,
    required this.forceSingleAttachment,
    required this.allowText,
  });

  final bool enabled;
  final bool forceSingleAttachment;
  final bool allowText;

  factory AudioOnlyPolicy.fromJson(Map<String, dynamic> json) {
    return AudioOnlyPolicy(
      enabled: json['enabled'] as bool? ?? true,
      forceSingleAttachment: json['force_single_attachment'] as bool? ?? true,
      allowText: json['allow_text'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
    'enabled': enabled,
    'force_single_attachment': forceSingleAttachment,
    'allow_text': allowText,
  };
}

class UploadPolicy {
  const UploadPolicy({
    required this.version,
    required this.maxTotalSizeMb,
    required this.maxAttachmentsPerMessage,
    required this.maxSizeMbByPartType,
    required this.mimeByPartType,
    required this.mimeWhitelist,
    required this.audioOnly,
  });

  final String version;
  final int maxTotalSizeMb;
  final int maxAttachmentsPerMessage;
  final Map<String, int> maxSizeMbByPartType;
  final Map<String, List<String>> mimeByPartType;
  final List<String> mimeWhitelist;
  final AudioOnlyPolicy audioOnly;

  static UploadPolicy builtinV1() {
    final image = AppConfig.allowedImageMimeTypes;
    final video = AppConfig.allowedVideoMimeTypes;
    final audio = AppConfig.allowedAudioMimeTypes;
    final file = AppConfig.allowedFileMimeTypes;

    final whitelist = <String>{
      ...image.map((v) => v.trim().toLowerCase()),
      ...video.map((v) => v.trim().toLowerCase()),
      ...audio.map((v) => v.trim().toLowerCase()),
      ...file.map((v) => v.trim().toLowerCase()),
    }.where((v) => v.isNotEmpty).toList()
      ..sort();

    return UploadPolicy(
      version: 'builtin-v1',
      maxTotalSizeMb: 100,
      maxAttachmentsPerMessage: 10,
      maxSizeMbByPartType: const {
        // 与后端默认策略对齐：image=5MB, audio=20MB, video=100MB, file=50MB
        'image': 5,
        'video': 100,
        'audio': 20,
        'file': 50,
      },
      mimeByPartType: {
        'image': image.map((v) => v.trim().toLowerCase()).toList(),
        'video': video.map((v) => v.trim().toLowerCase()).toList(),
        'audio': audio.map((v) => v.trim().toLowerCase()).toList(),
        'file': file.map((v) => v.trim().toLowerCase()).toList(),
      },
      mimeWhitelist: whitelist,
      audioOnly: const AudioOnlyPolicy(
        enabled: true,
        forceSingleAttachment: true,
        allowText: false,
      ),
    );
  }

  factory UploadPolicy.fromJson(Map<String, dynamic> json) {
    final fallback = UploadPolicy.builtinV1();

    Map<String, int> parseMaxSize(dynamic raw) {
      if (raw is! Map<String, dynamic>) return fallback.maxSizeMbByPartType;
      int getInt(String key, int fallbackValue) {
        final v = raw[key];
        if (v is int) return v;
        if (v is double) return v.round();
        return fallbackValue;
      }

      return {
        'image': getInt('image', fallback.maxSizeMbByPartType['image'] ?? 5),
        'video': getInt('video', fallback.maxSizeMbByPartType['video'] ?? 100),
        'audio': getInt('audio', fallback.maxSizeMbByPartType['audio'] ?? 20),
        'file': getInt('file', fallback.maxSizeMbByPartType['file'] ?? 50),
      };
    }

    List<String> parseMimeList(dynamic raw) {
      if (raw is! List) return const [];
      final set = <String>{};
      for (final item in raw) {
        if (item is! String) continue;
        final v = item.trim().toLowerCase();
        if (v.isEmpty) continue;
        set.add(v);
      }
      final list = set.toList()..sort();
      return list;
    }

    Map<String, List<String>> parseMimeByType(dynamic raw) {
      if (raw is! Map<String, dynamic>) return fallback.mimeByPartType;
      return {
        'image': parseMimeList(raw['image']),
        'video': parseMimeList(raw['video']),
        'audio': parseMimeList(raw['audio']),
        'file': parseMimeList(raw['file']),
      };
    }

    final version = (json['version'] as String?)?.trim();
    final maxTotalSizeMb = (json['max_total_size_mb'] as int?) ??
        fallback.maxTotalSizeMb;
    final maxAttachmentsPerMessage =
        (json['max_attachments_per_message'] as int?) ??
        fallback.maxAttachmentsPerMessage;

    final maxSizeMbByPartType = parseMaxSize(json['max_size_mb_by_part_type']);
    final mimeByPartType = parseMimeByType(json['mime_by_part_type']);
    final mimeWhitelist = parseMimeList(json['mime_whitelist']);

    final audioOnlyRaw = json['audio_only'];
    final audioOnly = audioOnlyRaw is Map<String, dynamic>
        ? AudioOnlyPolicy.fromJson(audioOnlyRaw)
        : fallback.audioOnly;

    return UploadPolicy(
      version: (version == null || version.isEmpty) ? fallback.version : version,
      maxTotalSizeMb: maxTotalSizeMb,
      maxAttachmentsPerMessage: maxAttachmentsPerMessage,
      maxSizeMbByPartType: maxSizeMbByPartType,
      mimeByPartType: mimeByPartType,
      mimeWhitelist: mimeWhitelist.isEmpty ? fallback.mimeWhitelist : mimeWhitelist,
      audioOnly: audioOnly,
    );
  }

  Map<String, dynamic> toJson() => {
    'version': version,
    'max_total_size_mb': maxTotalSizeMb,
    'max_attachments_per_message': maxAttachmentsPerMessage,
    'max_size_mb_by_part_type': maxSizeMbByPartType,
    'mime_by_part_type': mimeByPartType,
    'mime_whitelist': mimeWhitelist,
    'audio_only': audioOnly.toJson(),
  };

  int maxTotalBytes() => maxTotalSizeMb * 1024 * 1024;

  int? maxSizeBytesForPartType(String partType) {
    final mb = maxSizeMbByPartType[partType];
    if (mb == null || mb <= 0) return null;
    return mb * 1024 * 1024;
  }

  bool isMimeAllowedForPartType(String partType, String mime) {
    final normalized = mime.trim().toLowerCase();
    if (normalized.isEmpty) return false;
    final list = mimeByPartType[partType];
    if (list == null || list.isEmpty) return false;
    return list.contains(normalized);
  }
}

class UploadPolicyService {
  UploadPolicyService({TokenStorage? tokenStorage, http.Client? client})
    : _tokenStorage = tokenStorage ?? const TokenStorage(),
      _client = client ?? http.Client();

  final TokenStorage _tokenStorage;
  final http.Client _client;

  static UploadPolicyService? _instance;
  static UploadPolicyService get instance {
    _instance ??= UploadPolicyService();
    return _instance!;
  }

  static const _prefsPolicyKey = 'upload_policy_cache_json';
  static const _prefsFetchedAtKey = 'upload_policy_cache_fetched_at_ms';
  static const _ttl = Duration(minutes: 5);

  UploadPolicy? _memoryPolicy;
  DateTime? _memoryFetchedAt;
  Future<UploadPolicy>? _inflight;

  Future<UploadPolicy> getPolicy({bool forceRefresh = false}) async {
    final now = DateTime.now();
    if (!forceRefresh &&
        _memoryPolicy != null &&
        _memoryFetchedAt != null &&
        now.difference(_memoryFetchedAt!) < _ttl) {
      return _memoryPolicy!;
    }

    _inflight ??= _load(forceRefresh: forceRefresh).whenComplete(() {
      _inflight = null;
    });
    return _inflight!;
  }

  Future<void> refresh() async {
    await getPolicy(forceRefresh: true);
  }

  Future<void> clearCache() async {
    _memoryPolicy = null;
    _memoryFetchedAt = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsPolicyKey);
    await prefs.remove(_prefsFetchedAtKey);
  }

  Future<UploadPolicy> _load({required bool forceRefresh}) async {
    final now = DateTime.now();

    // 先读本地缓存（用于启动/离线兜底）
    final cached = await _readCached();
    if (_memoryPolicy == null && cached != null) {
      _memoryPolicy = cached.$1;
      _memoryFetchedAt = cached.$2;
    }

    if (!forceRefresh &&
        _memoryPolicy != null &&
        _memoryFetchedAt != null &&
        now.difference(_memoryFetchedAt!) < _ttl) {
      return _memoryPolicy!;
    }

    final session = await _tokenStorage.readSession();
    if (session == null || session.token.isEmpty) {
      return _memoryPolicy ?? UploadPolicy.builtinV1();
    }

    final uri = Uri.parse('${AppConfig.apiBaseUrl}/system/upload-policy');
    try {
      final resp = await _client.get(
        uri,
        headers: {
          'Authorization': 'Bearer ${session.token}',
          'Content-Type': 'application/json',
        },
      );

      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        if (data is Map<String, dynamic>) {
          final policy = UploadPolicy.fromJson(data);
          _memoryPolicy = policy;
          _memoryFetchedAt = now;
          await _saveCached(policy, now);
          return policy;
        }
      }

      if (kDebugMode) {
        debugPrint(
          '[UploadPolicy] fetch failed: status=${resp.statusCode} body=${resp.body}',
        );
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[UploadPolicy] fetch error: $e');
      }
    }

    return _memoryPolicy ?? UploadPolicy.builtinV1();
  }

  Future<(UploadPolicy, DateTime)?> _readCached() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsPolicyKey);
    if (raw == null || raw.trim().isEmpty) return null;
    final fetchedAtMs = prefs.getInt(_prefsFetchedAtKey);

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return null;
      final policy = UploadPolicy.fromJson(decoded);
      final fetchedAt = fetchedAtMs != null
          ? DateTime.fromMillisecondsSinceEpoch(fetchedAtMs)
          : DateTime.now().subtract(_ttl * 10);
      return (policy, fetchedAt);
    } catch (_) {
      return null;
    }
  }

  Future<void> _saveCached(UploadPolicy policy, DateTime fetchedAt) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsPolicyKey, jsonEncode(policy.toJson()));
    await prefs.setInt(_prefsFetchedAtKey, fetchedAt.millisecondsSinceEpoch);
  }
}

