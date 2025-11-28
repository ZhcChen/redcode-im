import '../config/environment.dart';

class AppConfig {
  const AppConfig._();

  /// API 基础地址（从环境配置获取）
  static String get apiBaseUrl => EnvironmentConfig.apiBaseUrl;

  /// WebSocket 地址（从环境配置获取）
  static String get wsUrl => EnvironmentConfig.wsUrl;

  /// 是否使用 Mock 数据
  static bool get useMockData => EnvironmentConfig.useMockData;

  /// Mock 延迟时间
  static const mockLatency = Duration(milliseconds: 450);

  /// API 超时时间
  static const apiTimeout = Duration(seconds: 30);

  // 以下上传政策后续可由后端接口下发
  static const double maxAttachmentSizeMb = 50; // 单文件限制
  static const double maxTotalAttachmentSizeMb = 100; // 单条消息总限制
  static const int maxAttachmentCount = 10;

  static const List<String> allowedImageMimeTypes = [
    'image/jpeg',
    'image/png',
    'image/webp',
  ];

  static const List<String> allowedVideoMimeTypes = [
    'video/mp4',
    'video/quicktime',
  ];

  static const List<String> allowedAudioMimeTypes = [
    'audio/aac',
    'audio/m4a',
    'audio/mp4',
  ];

  static const List<String> allowedFileMimeTypes = [
    'application/pdf',
    'application/msword',
    'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    'application/vnd.ms-excel',
    'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    'application/vnd.ms-powerpoint',
    'application/vnd.openxmlformats-officedocument.presentationml.presentation',
    'application/zip',
  ];
}
