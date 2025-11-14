import 'package:flutter/material.dart';

import 'app.dart';
import 'core/debug/debug_logger.dart';
import 'core/update/update_center.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  DebugLogger.initialize();
  await UpdateCenter.ensureHotUpdateManager();
  runApp(RedcodeApp(hotUpdateManager: UpdateCenter.hotUpdateManager));
}
