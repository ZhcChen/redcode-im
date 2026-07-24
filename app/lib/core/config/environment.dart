import 'package:flutter/foundation.dart';

// 环境配置管理
// 根据不同的环境加载相应的配置
//
// 使用方式：
// - 开发环境：flutter run --dart-define=ENV=development
// - 生产环境：flutter run --dart-define=ENV=production
// - 测试环境：flutter run --dart-define=ENV=staging

/// 环境类型
enum Environment {
  development,
  staging,
  production,
}

/// 环境配置
class EnvironmentConfig {
  const EnvironmentConfig._();

  /// 当前环境（通过 --dart-define=ENV=xxx 设置）
  static const String _envString = String.fromEnvironment(
    'ENV',
    defaultValue: 'development',
  );

  /// 获取当前环境
  static Environment get current {
    switch (_envString.toLowerCase()) {
      case 'production':
      case 'prod':
        return Environment.production;
      case 'staging':
      case 'stage':
      case 'test':
        return Environment.staging;
      default:
        return Environment.development;
    }
  }

  /// 是否为开发环境
  static bool get isDevelopment => current == Environment.development;

  /// 是否为测试环境
  static bool get isStaging => current == Environment.staging;

  /// 是否为生产环境
  static bool get isProduction => current == Environment.production;

  /// 开发环境 API 地址
  /// 本地默认走 localhost；真机联调请通过 --dart-define 覆盖为当前局域网 IP。
  static const String devApiBaseUrl = 'http://127.0.0.1:8010';
  static const String devWsUrl = 'ws://127.0.0.1:8010/ws';

  /// 当前测试/正式构建统一先指向 im-test-1。
  /// 后续有独立正式域名时再拆分 staging / production。
  static const String stagingApiBaseUrl = 'https://im-test-1.codelib.cc';
  static const String stagingWsUrl = 'wss://im-test-1.codelib.cc/ws';

  /// 生产环境 API 地址
  static const String prodApiBaseUrl = 'https://im-test-1.codelib.cc';
  static const String prodWsUrl = 'wss://im-test-1.codelib.cc/ws';

  /// 获取当前环境的 API 基础地址
  static String get apiBaseUrl {
    // 优先使用 --dart-define 传入的自定义地址
    const customUrl = String.fromEnvironment('API_BASE_URL');
    if (customUrl.isNotEmpty) {
      return customUrl;
    }

    // 否则根据环境返回默认地址
    switch (current) {
      case Environment.production:
        return prodApiBaseUrl;
      case Environment.staging:
        return stagingApiBaseUrl;
      case Environment.development:
        return devApiBaseUrl;
    }
  }

  /// 获取当前环境的 WebSocket 地址
  static String get wsUrl {
    // 优先使用 --dart-define 传入的自定义地址
    const customUrl = String.fromEnvironment('WS_URL');
    if (customUrl.isNotEmpty) {
      return customUrl;
    }

    // 否则根据环境返回默认地址
    switch (current) {
      case Environment.production:
        return prodWsUrl;
      case Environment.staging:
        return stagingWsUrl;
      case Environment.development:
        return devWsUrl;
    }
  }

  /// 是否启用调试日志
  static bool get enableDebugLog {
    const defined = String.fromEnvironment('ENABLE_DEBUG_LOG');
    if (defined.isNotEmpty) {
      return defined.toLowerCase() == 'true';
    }
    return isDevelopment || isStaging;
  }

  /// 是否启用性能监控
  static bool get enablePerformanceMonitor {
    const defined = String.fromEnvironment('ENABLE_PERFORMANCE_MONITOR');
    if (defined.isNotEmpty) {
      return defined.toLowerCase() == 'true';
    }
    return isDevelopment;
  }

  /// 是否使用 Mock 数据
  static bool get useMockData {
    const defined = String.fromEnvironment('USE_MOCK_DATA');
    if (defined.isNotEmpty) {
      return defined.toLowerCase() == 'true';
    }
    return false;
  }

  /// 环境名称（用于显示）
  static String get envName {
    switch (current) {
      case Environment.production:
        return '生产环境';
      case Environment.staging:
        return '测试环境';
      case Environment.development:
        return '开发环境';
    }
  }

  /// 打印当前环境信息
  static void printInfo() {
    if (enableDebugLog) {
      debugPrint('╔══════════════════════════════════════════╗');
      debugPrint('║          🌍 环境配置信息                  ║');
      debugPrint('╠══════════════════════════════════════════╣');
      debugPrint('║  环境: $envName');
      debugPrint('║  API:  $apiBaseUrl');
      debugPrint('║  WS:   $wsUrl');
      debugPrint('║  调试: ${enableDebugLog ? '✅' : '❌'}');
      debugPrint('╚══════════════════════════════════════════╝');
    }
  }
}
