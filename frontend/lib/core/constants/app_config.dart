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
}
