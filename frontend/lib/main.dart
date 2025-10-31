import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/debug/debug_logger.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 初始化调试日志管理器
  DebugLogger.initialize();

  // 关键修复：添加延迟确保 Flutter 引擎完全初始化
  // Android 平台通道需要一些时间才能完全准备好
  await Future.delayed(const Duration(milliseconds: 100));
  debugPrint('[Main] Flutter 引擎初始化延迟完成');

  // 预初始化 SharedPreferences，确保在登录前可用
  // 使用更长的超时时间和更多重试
  const maxRetries = 3;
  bool prefsInitialized = false;
  
  for (int i = 0; i < maxRetries; i++) {
    try {
      debugPrint('[Main] SharedPreferences 预初始化尝试 ${i + 1}/$maxRetries');
      final prefs = await SharedPreferences.getInstance().timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          debugPrint('[Main] SharedPreferences 预初始化超时 (${i + 1}/$maxRetries)');
          throw TimeoutException('SharedPreferences 初始化超时');
        },
      );
      // 验证 SharedPreferences 确实可用
      await prefs.reload();
      debugPrint('[Main] SharedPreferences 预初始化成功');
      prefsInitialized = true;
      break;
    } catch (e) {
      debugPrint('[Main] SharedPreferences 预初始化失败 (${i + 1}/$maxRetries): $e');
      if (i < maxRetries - 1) {
        // 指数退避重试
        await Future.delayed(Duration(milliseconds: 500 * (i + 1)));
      }
    }
  }

  if (!prefsInitialized) {
    debugPrint('[Main] ⚠️ SharedPreferences 预初始化最终失败，应用可能无法正常工作');
  }

  runApp(const RedcodeApp());
}
