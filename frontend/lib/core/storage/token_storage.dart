import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/auth/models/auth_session.dart';
import '../../features/auth/models/auth_user.dart';

class TokenStorage {
  const TokenStorage();

  static const _tokenKey = 'auth_token';
  static const _userKey = 'auth_user';
  static const _maxRetries = 10; // 增加重试次数
  static const _initialRetryDelay = Duration(milliseconds: 300);
  static const _maxRetryDelay = Duration(seconds: 3);

  /// 获取 SharedPreferences 实例，带增强的重试机制
  Future<SharedPreferences> _getPrefsWithRetry() async {
    Object? lastError;
    
    for (int i = 0; i < _maxRetries; i++) {
      try {
        if (kDebugMode) {
          if (i == 0) {
            debugPrint('[TokenStorage] 开始获取 SharedPreferences');
          } else {
            debugPrint('[TokenStorage] 重试获取 SharedPreferences (${i + 1}/$_maxRetries)');
          }
        }
        
        // 使用超时机制避免无限等待
        final prefs = await SharedPreferences.getInstance().timeout(
          const Duration(seconds: 5),
          onTimeout: () {
            throw TimeoutException('SharedPreferences.getInstance() 超时');
          },
        );
        
        if (kDebugMode) {
          debugPrint('[TokenStorage] SharedPreferences 获取成功');
        }
        return prefs;
      } on TimeoutException catch (e) {
        lastError = e;
        if (kDebugMode) {
          debugPrint('[TokenStorage] SharedPreferences 获取超时: ${e.message}');
        }
        if (i < _maxRetries - 1) {
          // 指数退避，但有最大延迟限制
          final delay = _initialRetryDelay * (1 << i);
          final actualDelay = delay > _maxRetryDelay ? _maxRetryDelay : delay;
          await Future.delayed(actualDelay);
        }
      } on PlatformException catch (e) {
        lastError = e;
        if (kDebugMode) {
          debugPrint('[TokenStorage] SharedPreferences 平台异常: ${e.message}');
          debugPrint('[TokenStorage] 异常详情: code=${e.code}, details=${e.details}');
        }
        if (i < _maxRetries - 1) {
          final delay = _initialRetryDelay * (1 << i);
          final actualDelay = delay > _maxRetryDelay ? _maxRetryDelay : delay;
          await Future.delayed(actualDelay);
        }
      } catch (e) {
        lastError = e;
        if (kDebugMode) {
          debugPrint('[TokenStorage] SharedPreferences 未知错误: $e');
          debugPrint('[TokenStorage] 错误类型: ${e.runtimeType}');
        }
        if (i < _maxRetries - 1) {
          final delay = _initialRetryDelay * (1 << i);
          final actualDelay = delay > _maxRetryDelay ? _maxRetryDelay : delay;
          await Future.delayed(actualDelay);
        }
      }
    }
    
    throw Exception(
      '无法初始化 SharedPreferences (尝试 $_maxRetries 次后失败): $lastError。'
      '请尝试以下操作：\n'
      '1. 完全关闭应用后重新启动\n'
      '2. 清除应用数据后重试\n'
      '3. 重启设备',
    );
  }

  Future<void> saveSession(AuthSession session) async {
    try {
      final prefs = await _getPrefsWithRetry();
      await prefs.setString(_tokenKey, session.token);
      await prefs.setString(_userKey, jsonEncode(session.user.toJson()));
      if (kDebugMode) {
        debugPrint('[TokenStorage] Session 保存成功');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[TokenStorage] Session 保存失败: $e');
      }
      rethrow;
    }
  }

  Future<AuthSession?> readSession() async {
    try {
      final prefs = await _getPrefsWithRetry();
      final token = prefs.getString(_tokenKey);
      final userJson = prefs.getString(_userKey);

      if (token == null || userJson == null) {
        return null;
      }

      try {
        final data = jsonDecode(userJson) as Map<String, dynamic>;
        final user = AuthUser.fromJson(data);
        return AuthSession(token: token, user: user);
      } catch (_) {
        await prefs.remove(_tokenKey);
        await prefs.remove(_userKey);
        return null;
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[TokenStorage] 读取 Session 失败: $e');
      }
      return null;
    }
  }

  Future<String?> readToken() async {
    try {
      final prefs = await _getPrefsWithRetry();
      return prefs.getString(_tokenKey);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[TokenStorage] 读取 Token 失败: $e');
      }
      return null;
    }
  }

  Future<void> updateUser(AuthUser user) async {
    try {
      final prefs = await _getPrefsWithRetry();
      if (!prefs.containsKey(_tokenKey)) {
        return;
      }

      await prefs.setString(_userKey, jsonEncode(user.toJson()));
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[TokenStorage] 更新用户信息失败: $e');
      }
      rethrow;
    }
  }

  Future<void> clear() async {
    try {
      final prefs = await _getPrefsWithRetry();
      await prefs.remove(_tokenKey);
      await prefs.remove(_userKey);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[TokenStorage] 清除 Session 失败: $e');
      }
      // 清除失败不应该抛出异常，静默处理
    }
  }
}
