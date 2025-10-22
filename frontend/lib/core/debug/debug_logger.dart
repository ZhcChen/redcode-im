import 'package:flutter/foundation.dart';

/// 自定义调试日志管理器
class DebugLogger {
  static bool _isInitialized = false;
  static void Function(String? message, {int? wrapWidth})? _originalDebugPrint;

  /// 初始化调试日志
  static void initialize() {
    if (_isInitialized) return;
    _isInitialized = true;

    // 只在调试模式下启用详细日志
    if (kDebugMode) {
      // 保存原始的 debugPrint
      _originalDebugPrint = debugPrint;

      // 设置日志级别
      debugPrint = (String? message, {int? wrapWidth}) {
        if (message != null && !message.contains('semantics.parentDataDirty')) {
          // 过滤掉已知的无害错误
          if (message.contains('Failed assertion') &&
              message.contains('semantics.parentDataDirty')) {
            return; // 忽略这个特定的错误
          }
          // 输出其他日志
          _printLog(message);
        }
      };
    }
  }

  static void _printLog(String? message) {
    // 使用原始的 debugPrint 输出
    if (message != null && _originalDebugPrint != null) {
      // 在开发环境添加时间戳
      final timestamp = DateTime.now().toIso8601String().substring(11, 19);
      _originalDebugPrint!('[$timestamp] $message');
    }
  }
}

/// 简化的日志方法
class Log {
  static void d(String message) {
    if (kDebugMode) {
      debugPrint('[DEBUG] $message');
    }
  }

  static void e(String message) {
    if (kDebugMode) {
      debugPrint('[ERROR] $message');
    }
  }

  static void i(String message) {
    if (kDebugMode) {
      debugPrint('[INFO] $message');
    }
  }

  static void w(String message) {
    if (kDebugMode) {
      debugPrint('[WARN] $message');
    }
  }
}
