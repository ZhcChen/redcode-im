class AppConfig {
  const AppConfig._();

  // 允许通过 --dart-define 覆盖默认地址，便于真机与模拟器区分
  static const apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://192.168.31.80:8010',
  );
  static const wsUrl = String.fromEnvironment(
    'WS_URL',
    defaultValue: 'ws://192.168.31.80:8010/ws',
  );

  static const useMockData = false;
  static const mockLatency = Duration(milliseconds: 450);
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
