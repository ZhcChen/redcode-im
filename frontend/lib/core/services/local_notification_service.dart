import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';

import 'push_navigation.dart';

class LocalNotificationService with WidgetsBindingObserver {
  LocalNotificationService._();

  static final LocalNotificationService instance = LocalNotificationService._();

  static const String _channelId = 'chat_messages';
  static const String _channelName = '聊天消息';
  static const String _channelDescription = 'RedCode IM 聊天消息通知';

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;
  AppLifecycleState? _lifecycleState;

  bool get _isAppResumed =>
      _lifecycleState == null || _lifecycleState == AppLifecycleState.resumed;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    WidgetsBinding.instance.addObserver(this);

    try {
      const settings = InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
      );

      await _plugin.initialize(
        settings,
        onDidReceiveNotificationResponse: _onNotificationResponse,
      );

      await _ensureAndroidChannel();
      await _requestNotificationPermission();
      await _handleLaunchFromNotification();
    } catch (e) {
      debugPrint('[LocalNotification] 初始化失败：$e');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _lifecycleState = state;
  }

  Future<void> maybeShowChatMessage({
    required String roomId,
    required String title,
    required String body,
    String? roomType,
    String? chatName,
    String? messageId,
  }) async {
    if (roomId.trim().isEmpty) return;
    if (!_initialized) {
      await initialize();
    }

    // App 在前台时避免重复打扰：聊天页已有实时消息展示。
    if (_isAppResumed) return;

    final payload = jsonEncode({
      'room_id': roomId,
      if (roomType != null && roomType.trim().isNotEmpty) 'room_type': roomType,
      if (chatName != null && chatName.trim().isNotEmpty) 'chat_name': chatName,
      if (messageId != null && messageId.trim().isNotEmpty)
        'message_id': messageId,
    });

    final details = NotificationDetails(
      android: const AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDescription,
        importance: Importance.max,
        priority: Priority.high,
      ),
      iOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );

    final id = (messageId?.isNotEmpty == true)
        ? messageId.hashCode
        : roomId.hashCode;
    try {
      await _plugin.show(
        id,
        title.trim().isNotEmpty ? title.trim() : '聊天',
        body.trim(),
        details,
        payload: payload,
      );
    } catch (e) {
      debugPrint('[LocalNotification] show 失败：$e');
    }
  }

  Future<void> _ensureAndroidChannel() async {
    if (defaultTargetPlatform != TargetPlatform.android) return;
    final android =
        _plugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (android == null) return;

    try {
      await android.createNotificationChannel(
        const AndroidNotificationChannel(
          _channelId,
          _channelName,
          description: _channelDescription,
          importance: Importance.high,
        ),
      );
    } catch (e) {
      debugPrint('[LocalNotification] 创建 Android Channel 失败：$e');
    }
  }

  Future<void> _requestNotificationPermission() async {
    try {
      await Permission.notification.request();
    } catch (e) {
      debugPrint('[LocalNotification] 申请通知权限失败：$e');
    }
  }

  Future<void> _handleLaunchFromNotification() async {
    try {
      final details = await _plugin.getNotificationAppLaunchDetails();
      final payload = details?.notificationResponse?.payload;
      if (payload == null || payload.trim().isEmpty) return;
      final decoded = jsonDecode(payload);
      if (decoded is Map) {
        final map = <String, dynamic>{};
        decoded.forEach((key, value) {
          map[key.toString()] = value;
        });
        unawaited(openChatFromPushPayload(map));
      }
    } catch (e) {
      debugPrint('[LocalNotification] 处理启动通知失败：$e');
    }
  }

  void _onNotificationResponse(NotificationResponse response) {
    final payload = response.payload;
    if (payload == null || payload.trim().isEmpty) return;
    try {
      final decoded = jsonDecode(payload);
      if (decoded is Map) {
        final map = <String, dynamic>{};
        decoded.forEach((key, value) {
          map[key.toString()] = value;
        });
        unawaited(openChatFromPushPayload(map));
      }
    } catch (e) {
      debugPrint('[LocalNotification] 点击通知解析 payload 失败：$e');
    }
  }
}

