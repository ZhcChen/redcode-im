import 'dart:async';
import 'dart:convert';

import 'package:async/async.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../constants/app_config.dart';
import '../storage/token_storage.dart';
import 'push_navigation.dart';

class PushService {
  PushService({TokenStorage? tokenStorage})
    : _tokenStorage = tokenStorage ?? const TokenStorage();

  final TokenStorage _tokenStorage;

  static PushService? _instance;
  static PushService get instance {
    _instance ??= PushService();
    return _instance!;
  }

  StreamSubscription<String>? _tokenRefreshSub;
  bool _initialized = false;
  bool _ready = false;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    // Firebase 初始化可能因缺少配置而失败；Push 需要依赖 FirebaseMessaging
    try {
      await Firebase.initializeApp();
      _ready = true;
    } catch (e) {
      debugPrint('[Push] Firebase 初始化失败，跳过 Push：$e');
      return;
    }

    try {
      await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
    } catch (e) {
      debugPrint('[Push] 申请通知权限失败：$e');
    }

    try {
      await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );
    } catch (_) {
      // Android 无该选项也可忽略
    }

    FirebaseMessaging.onMessageOpenedApp.listen(_handleOpen);
    try {
      final initial = await FirebaseMessaging.instance.getInitialMessage();
      if (initial != null) {
        _handleOpen(initial);
      }
    } catch (e) {
      debugPrint('[Push] getInitialMessage 失败：$e');
    }

    _tokenRefreshSub?.cancel();
    _tokenRefreshSub = FirebaseMessaging.instance.onTokenRefresh.listen((t) {
      unawaited(registerDevice(deviceTokenOverride: t));
    });
  }

  Future<String> _getOrCreateDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getString('push_device_id');
    if (existing != null && existing.trim().isNotEmpty) {
      return existing.trim();
    }
    final id = const Uuid().v4();
    await prefs.setString('push_device_id', id);
    return id;
  }

  String _platform() {
    // 与后端约定：android/ios
    if (defaultTargetPlatform == TargetPlatform.iOS) return 'ios';
    if (defaultTargetPlatform == TargetPlatform.android) return 'android';
    return defaultTargetPlatform.name.toLowerCase();
  }

  String _channel() {
    // 先统一使用 FCM（iOS 也通过 FCM 转发到 APNs）
    return 'fcm';
  }

  Future<void> registerDevice({String? deviceTokenOverride}) async {
    // 未初始化或 Firebase 不可用时直接跳过
    if (!_initialized) {
      await initialize();
    }
    if (!_ready) return;

    final session = await _tokenStorage.readSession();
    if (session == null || session.token.isEmpty) return;

    String? token = deviceTokenOverride;
    try {
      token ??= await FirebaseMessaging.instance.getToken();
    } catch (e) {
      debugPrint('[Push] 获取 FCM token 失败：$e');
      return;
    }
    if (token == null || token.trim().isEmpty) {
      debugPrint('[Push] 获取 FCM token 为空，跳过注册');
      return;
    }

    final deviceId = await _getOrCreateDeviceId();
    final uri = Uri.parse('${AppConfig.apiBaseUrl}/push/devices');

    try {
      final resp = await http.post(
        uri,
        headers: {
          'Authorization': 'Bearer ${session.token}',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'device_id': deviceId,
          'platform': _platform(),
          'channel': _channel(),
          'device_token': token.trim(),
        }),
      );

      if (resp.statusCode != 200) {
        debugPrint('[Push] 注册设备失败: ${resp.statusCode} ${resp.body}');
      } else if (kDebugMode) {
        debugPrint('[Push] 设备注册成功: $deviceId');
      }
    } catch (e) {
      debugPrint('[Push] 注册设备异常: $e');
    }
  }

  Future<void> unregisterDevice() async {
    final session = await _tokenStorage.readSession();
    if (session == null || session.token.isEmpty) return;

    final deviceId = await _getOrCreateDeviceId();
    final uri = Uri.parse('${AppConfig.apiBaseUrl}/push/devices/$deviceId');

    try {
      final resp = await http.delete(
        uri,
        headers: {
          'Authorization': 'Bearer ${session.token}',
          'Content-Type': 'application/json',
        },
      );
      if (resp.statusCode != 200) {
        debugPrint('[Push] 注销设备失败: ${resp.statusCode} ${resp.body}');
      } else if (kDebugMode) {
        debugPrint('[Push] 设备注销成功: $deviceId');
      }
    } catch (e) {
      debugPrint('[Push] 注销设备异常: $e');
    }
  }

  Future<void> dispose() async {
    await _tokenRefreshSub?.cancel();
    _tokenRefreshSub = null;
    _initialized = false;
  }

  void _handleOpen(RemoteMessage message) {
    final payload = <String, dynamic>{};
    for (final entry in message.data.entries) {
      payload[entry.key] = entry.value;
    }
    unawaited(openChatFromPushPayload(payload));
  }
}
