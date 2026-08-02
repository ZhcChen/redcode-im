import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:mime/mime.dart';
import 'package:path/path.dart' as p;

import '../constants/app_config.dart';
import '../network/direct_upload.dart';
import '../storage/token_storage.dart';

class ReportServiceException implements Exception {
  const ReportServiceException(this.message);

  final String message;

  @override
  String toString() => message;
}

class ReportService {
  ReportService({TokenStorage? tokenStorage, http.Client? client})
    : _tokenStorage = tokenStorage ?? const TokenStorage(),
      _client = client ?? http.Client();

  final TokenStorage _tokenStorage;
  final http.Client _client;

  Future<void> submitReport({
    required String targetType,
    required String targetId,
    required String content,
    required List<File> attachments,
  }) async {
    final normalizedContent = content.trim();
    if (normalizedContent.isEmpty) {
      throw const ReportServiceException('请输入举报内容');
    }
    if (attachments.isEmpty) {
      throw const ReportServiceException('请至少上传 1 张截图');
    }

    final session = await _tokenStorage.readSession();
    if (session == null) {
      throw const ReportServiceException('请先登录');
    }

    final keys = <String>[];
    for (final file in attachments) {
      keys.add(await _uploadAttachment(token: session.token, file: file));
    }

    final response = await _client.post(
      Uri.parse('${AppConfig.apiBaseUrl}/reports'),
      headers: _headers(session.token),
      body: jsonEncode({
        'target_type': targetType,
        'target_id': targetId,
        'content': normalizedContent,
        'attachment_keys': keys,
      }),
    );
    final payload = _decodeObject(response.body);
    if (response.statusCode != 200 || payload['success'] != true) {
      throw ReportServiceException(_errorMessage(payload, fallback: '提交举报失败'));
    }
  }

  Future<String> _uploadAttachment({
    required String token,
    required File file,
  }) async {
    if (!await file.exists()) {
      throw const ReportServiceException('未找到截图文件');
    }

    final contentType = lookupMimeType(file.path) ?? 'application/octet-stream';
    final fileSize = await file.length();
    final signatureResponse = await _client.post(
      Uri.parse('${AppConfig.apiBaseUrl}/reports/attachments/signature'),
      headers: _headers(token),
      body: jsonEncode({
        'filename': p.basename(file.path),
        'content_type': contentType,
        'file_size': fileSize,
      }),
    );
    final signaturePayload = _decodeObject(signatureResponse.body);
    if (signatureResponse.statusCode != 200 ||
        signaturePayload['success'] != true) {
      throw ReportServiceException(
        _errorMessage(signaturePayload, fallback: '获取上传签名失败'),
      );
    }

    final key = signaturePayload['key'] as String?;
    final signatureJson = signaturePayload['signature'];
    if (key == null || signatureJson is! Map<String, dynamic>) {
      throw const ReportServiceException('上传签名响应不完整');
    }

    final signature = DirectUploadSignature.fromJson(signatureJson);
    final uploadRequest = http.Request(
      signature.method,
      Uri.parse(signature.url),
    );
    signature.applyHeaders(uploadRequest, defaultContentType: contentType);
    uploadRequest.bodyBytes = await file.readAsBytes();
    final uploadResponse = await _client.send(uploadRequest);
    if (uploadResponse.statusCode < 200 || uploadResponse.statusCode >= 300) {
      final body = await uploadResponse.stream.bytesToString();
      throw ReportServiceException(body.isEmpty ? '截图上传失败' : body);
    }

    final commitResponse = await _client.post(
      Uri.parse('${AppConfig.apiBaseUrl}/reports/attachments/commit'),
      headers: _headers(token),
      body: jsonEncode({'key': key, 'file_size': fileSize}),
    );
    final commitPayload = _decodeObject(commitResponse.body);
    if (commitResponse.statusCode != 200 || commitPayload['success'] != true) {
      throw ReportServiceException(
        _errorMessage(commitPayload, fallback: '提交截图信息失败'),
      );
    }
    return key;
  }

  Map<String, String> _headers(String token) => {
    'Authorization': 'Bearer $token',
    'Content-Type': 'application/json',
  };

  Map<String, dynamic> _decodeObject(String body) {
    try {
      final value = jsonDecode(body);
      return value is Map<String, dynamic> ? value : const {};
    } catch (_) {
      return const {};
    }
  }

  String _errorMessage(
    Map<String, dynamic> payload, {
    required String fallback,
  }) {
    final message = payload['message'] ?? payload['error'];
    return message is String && message.isNotEmpty ? message : fallback;
  }
}
