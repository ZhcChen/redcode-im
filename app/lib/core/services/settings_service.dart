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

class MessageRuntimeSettings {
  const MessageRuntimeSettings({
    required this.serverStorageMode,
    required this.contentAuditMode,
  });

  static const defaults = MessageRuntimeSettings(
    serverStorageMode: 'persist',
    contentAuditMode: 'plaintext',
  );

  final String serverStorageMode;
  final String contentAuditMode;

  bool get isRelayOnly => serverStorageMode == 'relay_only';
  bool get isPersist => !isRelayOnly;
  bool get isE2ee => contentAuditMode == 'e2ee';
  bool get isPlaintext => !isE2ee;

  String get runtimeNoticeTitle => isE2ee ? '当前配置目标：端到端加密' : '当前配置目标：明文可审计';

  String get runtimeNoticeDescription {
    if (isRelayOnly) {
      return isE2ee
          ? '服务器仅做实时转发且不保存聊天记录，按当前配置目标不应被服务端审计。'
          : '服务器仅做实时转发且不保存聊天记录，消息内容仍可被服务端审计。';
    }

    return isE2ee ? '消息会保存在服务器，按当前配置目标不应被服务端审计。' : '消息会保存在服务器，管理员可审计消息内容。';
  }

  String get messageLocateMissNotice =>
      isRelayOnly
      ? '当前模式不保存聊天记录，只能定位本地缓存中的消息'
      : '当前未加载到该消息，可能已被删除或尚未同步';

  factory MessageRuntimeSettings.fromJson(Map<String, dynamic>? json) {
    return MessageRuntimeSettings(
      serverStorageMode:
          (json?['server_storage_mode'] as String?)?.trim().isNotEmpty == true
          ? json!['server_storage_mode'] as String
          : 'persist',
      contentAuditMode:
          (json?['content_audit_mode'] as String?)?.trim().isNotEmpty == true
          ? json!['content_audit_mode'] as String
          : 'plaintext',
    );
  }
}

class GeneralSettings {
  const GeneralSettings({required this.appName, required this.messageRuntime});

  final String appName;
  final MessageRuntimeSettings messageRuntime;

  factory GeneralSettings.fromJson(Map<String, dynamic> json) {
    return GeneralSettings(
      appName: (json['app_name'] as String?) ?? '',
      messageRuntime: MessageRuntimeSettings.fromJson(
        json['message_runtime'] as Map<String, dynamic>?,
      ),
    );
  }
}

class SettingsService {
  SettingsService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<GeneralSettings> fetchGeneralSettings() async {
    final uri = Uri.parse('${AppConfig.apiBaseUrl}/settings/general');
    try {
      final response = await _client.get(uri);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is Map<String, dynamic>) {
          return GeneralSettings.fromJson(data);
        }
      }
    } catch (_) {
      // 静默失败，回退默认值
    }

    return const GeneralSettings(
      appName: '',
      messageRuntime: MessageRuntimeSettings.defaults,
    );
  }

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
    try {
      final general = await fetchGeneralSettings();
      if (general.appName.isNotEmpty) {
        return general.appName;
      }
    } catch (_) {
      // 静默失败，返回默认值
    }

    final uri = Uri.parse('${AppConfig.apiBaseUrl}/settings/app-name');
    try {
      final response = await _client.get(uri);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return (data['app_name'] as String?) ?? '';
      }
    } catch (_) {}
    return '';
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
