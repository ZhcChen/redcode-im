import 'dart:async';
import 'package:flutter/material.dart';
import '../../features/auth/data/auth_repository.dart';
import '../../features/auth/login_page.dart';
import '../services/websocket_service.dart';
import '../services/message_service.dart';
import '../services/friend_store.dart';
import '../services/settings_service.dart';
import 'auth_state.dart';

/// 认证守卫组件，确保用户已登录
class AuthGuard extends StatefulWidget {
  final Widget Function(String appName) childBuilder;

  const AuthGuard({super.key, required this.childBuilder});

  @override
  State<AuthGuard> createState() => _AuthGuardState();
}

class _AuthGuardState extends State<AuthGuard> {
  final AuthRepository _authRepository = AuthRepository();
  final SettingsService _settingsService = SettingsService();
  StreamSubscription<AuthState>? _authSubscription;
  String _appName = '';

  @override
  void initState() {
    super.initState();
    _loadAppName();
    // 监听认证状态变化
    _authSubscription = _authRepository.authStateStream.listen((state) {
      if (state == AuthState.unauthenticated && mounted) {
        _cleanupSessionSideEffects();
        // 用户未登录，跳转到登录页
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginPage()),
          (route) => false,
        );
      }
    });

    // 检查当前认证状态
    _checkAuthStatus();
  }

  Future<void> _loadAppName() async {
    try {
      final appName = await _settingsService.fetchAppName();
      if (mounted) {
        setState(() {
          _appName = appName;
        });
      }
    } catch (_) {
      // 静默失败，使用默认值
    }
  }

  Future<void> _checkAuthStatus() async {
    try {
      final session = await _authRepository.loadSession();
      if (session == null) {
        // 没有会话，跳转到登录页
        if (mounted) {
          _cleanupSessionSideEffects();
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const LoginPage()),
            (route) => false,
          );
        }
      } else {
        // 有有效会话，启动 WebSocket 连接
        try {
          await WebSocketService.instance.connect();
          debugPrint('[AuthGuard] WebSocket 连接启动成功');
        } catch (e) {
          debugPrint('[AuthGuard] WebSocket 连接启动失败: $e');
          // WebSocket 连接失败不影响应用正常使用
        }
      }
      // 注意：这里不立即验证会话，因为在启动页面已经验证过了
      // 只在有明确错误时才跳转
    } catch (e) {
      // 出现错误，跳转到登录页
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginPage()),
          (route) => false,
        );
      }
    }
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  void _cleanupSessionSideEffects() {
    try {
      WebSocketService.instance.disconnect();
    } catch (_) {}
    try {
      unawaited(MessageService.instance.clearAll());
    } catch (_) {}
    try {
      FriendStore.instance.clearAll();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return widget.childBuilder(_appName);
  }
}
