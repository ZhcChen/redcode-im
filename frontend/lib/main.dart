import 'package:flutter/material.dart';

import 'app.dart';
import 'core/debug/debug_logger.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  DebugLogger.initialize();
  runApp(const RedcodeApp());
}
