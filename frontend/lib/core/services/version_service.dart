import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../constants/app_config.dart';

class AppVersionInfo {
  AppVersionInfo({
    required this.id,
    required this.platform,
    required this.version,
    required this.buildNumber,
    required this.channel,
    required this.downloadKey,
    this.downloadUrl,
    this.fileSize,
    this.checksum,
    this.signature,
    this.releaseNotes,
    required this.mandatory,
    required this.isActive,
    this.releasedAt,
  });

  factory AppVersionInfo.fromJson(Map<String, dynamic> json) {
    return AppVersionInfo(
      id: json['id'] as String,
      platform: json['platform'] as String,
      version: json['version'] as String,
      buildNumber: json['build_number'] as int,
      channel: json['channel'] as String,
      downloadKey: json['download_key'] as String,
      downloadUrl: json['download_url'] as String?,
      fileSize: json['file_size'] as int?,
      checksum: json['checksum'] as String?,
      signature: json['signature'] as String?,
      releaseNotes: json['release_notes'] as String?,
      mandatory: json['mandatory'] as bool? ?? false,
      isActive: json['is_active'] as bool? ?? false,
      releasedAt: json['released_at'] as String?,
    );
  }

  final String id;
  final String platform;
  final String version;
  final int buildNumber;
  final String channel;
  final String downloadKey;
  final String? downloadUrl;
  final int? fileSize;
  final String? checksum;
  final String? signature;
  final String? releaseNotes;
  final bool mandatory;
  final bool isActive;
  final String? releasedAt;
}

class VersionCheckResult {
  VersionCheckResult({
    required this.hasUpdate,
    required this.currentVersion,
    required this.latest,
  });

  final bool hasUpdate;
  final String? currentVersion;
  final AppVersionInfo? latest;
}

class VersionDownloadResult {
  VersionDownloadResult({
    required this.filePath,
    required this.fileSize,
  });

  final String filePath;
  final int fileSize;
}

class VersionService {
  VersionService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<VersionCheckResult> checkLatest({
    required String currentVersion,
    String channel = 'stable',
  }) async {
    // 自动识别平台：iOS 或 Android
    final platform = Platform.isIOS ? 'ios' : 'android';

    final uri = Uri.parse('${AppConfig.apiBaseUrl}/versions/latest').replace(
      queryParameters: <String, String>{
        'platform': platform,
        'channel': channel,
        if (currentVersion.isNotEmpty) 'current_version': currentVersion,
      },
    );

    final response = await _client.get(uri);
    if (response.statusCode != 200) {
      throw HttpException(
        '版本检查失败: HTTP ${response.statusCode}',
        uri: uri,
      );
    }

    final Map<String, dynamic> payload =
        jsonDecode(response.body) as Map<String, dynamic>;
    final hasUpdate = payload['has_update'] as bool? ?? false;
    final current = payload['current_version'] as String?;
    final latestJson = payload['version'] as Map<String, dynamic>?;
    final latest =
        latestJson != null ? AppVersionInfo.fromJson(latestJson) : null;

    return VersionCheckResult(
      hasUpdate: hasUpdate && latest != null,
      currentVersion: current,
      latest: latest,
    );
  }

  Future<VersionDownloadResult> downloadAndSave({
    required AppVersionInfo version,
    int expiresInSeconds = 600,
  }) async {
    final signedUrl = await fetchDownloadUrl(
      id: version.id,
      expiresInSeconds: expiresInSeconds,
    );

    final uri = Uri.parse(signedUrl);
    final http.Response response = await _client.get(uri);
    if (response.statusCode != 200) {
      throw HttpException(
        '下载更新失败: HTTP ${response.statusCode}',
        uri: uri,
      );
    }

    final bytes = response.bodyBytes;
    final directory = await _resolveDownloadDirectory();
    final fileName = _resolveFileName(version);
    final filePath = p.join(directory.path, fileName);
    final file = File(filePath);
    await file.writeAsBytes(bytes, flush: true);

    return VersionDownloadResult(
      filePath: file.path,
      fileSize: bytes.length,
    );
  }

  Future<Directory> _resolveDownloadDirectory() async {
    final documents = await getApplicationDocumentsDirectory();
    final target = Directory(p.join(documents.path, 'versions'));
    if (!await target.exists()) {
      await target.create(recursive: true);
    }
    return target;
  }

  String _resolveFileName(AppVersionInfo version) {
    final extension = () {
      final keyExt = p.extension(version.downloadKey);
      if (keyExt.isNotEmpty) return keyExt;
      final urlExt = p.extension(version.downloadUrl ?? '');
      if (urlExt.isNotEmpty) return urlExt;
      return '.pkg';
    }();
    final safeChannel = version.channel.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '');
    return 'bear_chat_${version.platform}_${safeChannel}_${version.version}$extension';
  }

  Future<String> fetchDownloadUrl({
    required String id,
    int expiresInSeconds = 600,
  }) async {
    final uri = Uri.parse('${AppConfig.apiBaseUrl}/versions/download')
        .replace(queryParameters: <String, String>{
      'id': id,
      'expires_in_seconds': expiresInSeconds.toString(),
    });

    final response = await _client.get(uri);
    if (response.statusCode != 200) {
      throw HttpException(
        '获取下载链接失败: HTTP ${response.statusCode}',
        uri: uri,
      );
    }

    final Map<String, dynamic> payload =
        jsonDecode(response.body) as Map<String, dynamic>;
    final success = payload['success'] as bool? ?? false;
    final url = payload['download_url'] as String?;

    if (!success || url == null || url.isEmpty) {
      final message = payload['message'] as String? ?? '未知错误';
      throw StateError('获取下载链接失败: $message');
    }

    return url;
  }
}
