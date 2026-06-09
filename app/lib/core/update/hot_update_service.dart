import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as crypto;
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../constants/app_config.dart';
import 'hot_update_models.dart';

class HotUpdateService {
  HotUpdateService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<HotUpdateCheckResult> checkLatest({
    required String platform,
    required String currentVersion,
    String channel = 'stable',
    String? currentPatchVersion,
    String? clientId,
  }) async {
    final uri = Uri.parse('${AppConfig.apiBaseUrl}/versions/hot-update')
        .replace(
          queryParameters: <String, String>{
            'platform': platform,
            'channel': channel,
            'current_version': currentVersion,
            if (currentPatchVersion != null && currentPatchVersion.isNotEmpty)
              'current_patch_version': currentPatchVersion,
            if (clientId != null && clientId.isNotEmpty) 'client_id': clientId,
          },
        );

    final response = await _client.get(uri);
    if (response.statusCode != 200) {
      throw HttpException('热更新检查失败: HTTP ${response.statusCode}', uri: uri);
    }

    final Map<String, dynamic> payload =
        jsonDecode(response.body) as Map<String, dynamic>;
    final patchJson = payload['patch'] as Map<String, dynamic>?;
    return HotUpdateCheckResult(
      hasUpdate: payload['has_update'] as bool? ?? false,
      currentPatchVersion: payload['current_patch_version'] as String?,
      patch: patchJson != null ? HotPatchInfo.fromJson(patchJson) : null,
    );
  }

  Future<String> requestDownloadUrl({
    required String patchId,
    int expiresInSeconds = 600,
  }) async {
    final uri =
        Uri.parse(
          '${AppConfig.apiBaseUrl}/versions/hot-update/download',
        ).replace(
          queryParameters: <String, String>{
            'id': patchId,
            'expires_in_seconds': expiresInSeconds.toString(),
          },
        );

    final response = await _client.get(uri);
    if (response.statusCode != 200) {
      throw HttpException('获取补丁下载地址失败: HTTP ${response.statusCode}', uri: uri);
    }

    final Map<String, dynamic> payload =
        jsonDecode(response.body) as Map<String, dynamic>;
    final success = payload['success'] as bool? ?? false;
    final url = payload['download_url'] as String?;
    if (!success || url == null || url.isEmpty) {
      final message = payload['message'] as String? ?? '未知错误';
      throw StateError('获取补丁下载地址失败: $message');
    }
    return url;
  }

  Future<HotUpdateDownloadRecord> downloadPatch({
    required HotPatchInfo patch,
    required String baseVersion,
    int expiresInSeconds = 600,
  }) async {
    final downloadUrl = await requestDownloadUrl(
      patchId: patch.id,
      expiresInSeconds: expiresInSeconds,
    );
    final uri = Uri.parse(downloadUrl);
    final response = await _client.get(uri);
    if (response.statusCode != 200) {
      throw HttpException('下载补丁失败: HTTP ${response.statusCode}', uri: uri);
    }
    final bytes = response.bodyBytes;
    if (patch.checksum != null &&
        patch.checksum!.isNotEmpty &&
        !_verifyChecksum(bytes, patch.checksum!)) {
      throw StateError('补丁校验失败，checksum 不匹配');
    }

    final directory = await _resolvePatchDirectory();
    final fileName = _buildPatchFileName(patch);
    final filePath = p.join(directory.path, fileName);
    final file = File(filePath);
    await file.writeAsBytes(bytes, flush: true);

    return HotUpdateDownloadRecord(
      patchId: patch.id,
      patchVersion: patch.patchVersion,
      baseVersion: baseVersion,
      filePath: file.path,
      fileSize: bytes.length,
      checksum: patch.checksum,
      downloadedAt: DateTime.now(),
    );
  }

  Future<Directory> _resolvePatchDirectory() async {
    final supportDir = await getApplicationSupportDirectory();
    final patchDir = Directory(p.join(supportDir.path, 'hot_updates'));
    if (!await patchDir.exists()) {
      await patchDir.create(recursive: true);
    }
    return patchDir;
  }

  String _buildPatchFileName(HotPatchInfo patch) {
    final safeChannel = patch.channel.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '');
    final safeVersion = patch.patchVersion.replaceAll(
      RegExp(r'[^a-zA-Z0-9._-]'),
      '_',
    );
    return 'patch_${patch.platform}_${safeChannel}_$safeVersion.bin';
  }

  bool _verifyChecksum(Uint8List data, String checksumSpec) {
    final normalized = checksumSpec.trim();
    if (normalized.isEmpty) return true;

    String algorithm;
    String digestHex;
    if (normalized.contains(':')) {
      final parts = normalized.split(':');
      algorithm = parts.first.toLowerCase();
      digestHex = parts.last;
    } else {
      digestHex = normalized;
      algorithm = _inferAlgorithmByLength(digestHex.length);
    }

    final calculated = _calculateDigest(data, algorithm);
    return calculated == digestHex.toLowerCase();
  }

  String _inferAlgorithmByLength(int length) {
    switch (length) {
      case 32:
        return 'md5';
      case 40:
        return 'sha1';
      case 64:
        return 'sha256';
      default:
        return 'sha256';
    }
  }

  String _calculateDigest(Uint8List data, String algorithm) {
    switch (algorithm) {
      case 'md5':
        return crypto.md5.convert(data).bytes.map(_toHex).join();
      case 'sha1':
        return crypto.sha1.convert(data).bytes.map(_toHex).join();
      case 'sha256':
      default:
        return crypto.sha256.convert(data).bytes.map(_toHex).join();
    }
  }

  String _toHex(int byte) {
    return byte.toRadixString(16).padLeft(2, '0');
  }
}
