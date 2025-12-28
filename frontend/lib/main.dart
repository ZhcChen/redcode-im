import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'app.dart';
import 'core/debug/debug_logger.dart';
import 'core/services/local_notification_service.dart';
import 'core/services/push_service.dart';
import 'core/update/update_center.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  DebugLogger.initialize();
  await UpdateCenter.ensureHotUpdateManager();
  await LocalNotificationService.instance.initialize();
  await PushService.instance.initialize();

  // 初始化屏幕适配，基于 375x812 (iPhone X) 的设计稿
  await ScreenUtil.ensureScreenSize();

  runApp(RedcodeApp(hotUpdateManager: UpdateCenter.hotUpdateManager));
}
