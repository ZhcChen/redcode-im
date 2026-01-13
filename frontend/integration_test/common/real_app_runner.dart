import 'package:flutter/widgets.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:frontend/app.dart';
import 'package:frontend/core/debug/debug_logger.dart';
import 'package:frontend/core/services/local_notification_service.dart';
import 'package:frontend/core/services/push_service.dart';
import 'package:frontend/core/update/update_center.dart';

/// 真实应用测试入口
///
/// 包含必要的服务初始化，用于 E2E 集成测试。
/// 此类会初始化与 main.dart 相同的服务，确保真实应用正常启动。
class RealAppTestRunner {
  static bool _initialized = false;

  /// 初始化应用服务
  ///
  /// 与 main.dart 中的初始化逻辑保持一致
  static Future<void> ensureInitialized() async {
    if (_initialized) return;

    WidgetsFlutterBinding.ensureInitialized();
    DebugLogger.initialize();

    // 热更新管理器（允许失败，不阻塞测试）
    try {
      await UpdateCenter.ensureHotUpdateManager();
    } catch (_) {
      // 测试环境中热更新可能不可用，忽略错误
    }

    // 本地通知服务（允许失败）
    try {
      await LocalNotificationService.instance.initialize();
    } catch (_) {
      // 测试环境中通知服务可能不可用
    }

    // 推送服务（允许失败）
    try {
      await PushService.instance.initialize();
    } catch (_) {
      // 测试环境中推送服务可能不可用
    }

    // 屏幕适配
    await ScreenUtil.ensureScreenSize();

    _initialized = true;
  }

  /// 创建真实应用 Widget
  static Widget createApp() {
    return RedcodeApp(hotUpdateManager: UpdateCenter.hotUpdateManager);
  }
}
