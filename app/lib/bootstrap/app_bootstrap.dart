import 'package:flutter/widgets.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../app.dart';
import '../core/debug/debug_logger.dart';
import '../core/services/local_notification_service.dart';
import '../core/services/push_service.dart';
import '../core/update/update_center.dart';

abstract final class AppBootstrap {
  static Future<void> run() async {
    WidgetsFlutterBinding.ensureInitialized();
    DebugLogger.initialize();
    await UpdateCenter.ensureHotUpdateManager();
    await LocalNotificationService.instance.initialize();
    await PushService.instance.initialize();
    await ScreenUtil.ensureScreenSize();
    runApp(RedcodeApp(hotUpdateManager: UpdateCenter.hotUpdateManager));
  }
}
