import 'dart:convert';

import 'package:http/http.dart' as http;

import '../constants/app_config.dart';

class SettingsServiceException implements Exception {
  SettingsServiceException(this.message);

  final String message;

  @override
  String toString() => 'SettingsServiceException: $message';
}

class DocumentContent {
  const DocumentContent({
    required this.title,
    required this.content,
    this.updatedAt,
  });

  final String title;
  final String content;
  final DateTime? updatedAt;

  factory DocumentContent.fromJson(Map<String, dynamic> json) {
    return DocumentContent(
      title: (json['title'] as String?) ?? '',
      content: (json['content'] as String?) ?? '',
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'] as String)
          : null,
    );
  }
}

class SettingsService {
  SettingsService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  Future<DocumentContent> fetchPrivacyPolicy() async {
    final uri = Uri.parse('${AppConfig.apiBaseUrl}/settings/privacy-policy');
    final response = await _client.get(uri);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data is Map<String, dynamic>) {
        return DocumentContent.fromJson(data);
      }
      throw SettingsServiceException('隐私政策数据格式异常');
    }

    throw SettingsServiceException(
      _extractMessage(response.body) ?? '隐私政策加载失败',
    );
  }

  /// 获取应用名称（公开 API，无需 token）
  Future<String> fetchAppName() async {
    final uri = Uri.parse('${AppConfig.apiBaseUrl}/settings/app-name');
    try {
      final response = await _client.get(uri);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return (data['app_name'] as String?) ?? 'Redcode IM';
      }
    } catch (_) {
      // 静默失败，返回默认值
    }
    return 'Redcode IM';
  }

  /// 获取用户协议（公开 API，无需 token）
  Future<DocumentContent> fetchUserAgreement() async {
    final uri = Uri.parse('${AppConfig.apiBaseUrl}/settings/user-agreement');
    final response = await _client.get(uri);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data is Map<String, dynamic>) {
        return DocumentContent.fromJson(data);
      }
      throw SettingsServiceException('用户协议数据格式异常');
    }

    throw SettingsServiceException(
      _extractMessage(response.body) ?? '用户协议加载失败',
    );
  }

  /// 获取验证码设置（公开 API，无需 token）
  Future<bool> fetchRequireCaptchaForLogin() async {
    final uri = Uri.parse('${AppConfig.apiBaseUrl}/settings/captcha');
    try {
      final response = await _client.get(uri);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return (data['require_captcha_for_login'] as bool?) ?? false;
      }
    } catch (_) {
      // 静默失败，返回默认值
    }
    return false;
  }

  String? _extractMessage(String raw) {
    try {
      final data = jsonDecode(raw);
      if (data is Map<String, dynamic>) {
        final message = data['message'];
        if (message is String && message.isNotEmpty) {
          return message;
        }
      }
    } catch (_) {}
    return null;
  }
}
