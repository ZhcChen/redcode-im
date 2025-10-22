import 'package:flutter/material.dart';

import 'app.dart';
import 'core/debug/debug_logger.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // 初始化调试日志管理器
  DebugLogger.initialize();

  runApp(const RedcodeApp());
}
