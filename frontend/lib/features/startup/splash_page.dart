import 'dart:async';
import 'package:flutter/material.dart';

import '../../core/constants/app_assets.dart';
import '../../core/constants/app_colors.dart';
import '../../core/debug/debug_logger.dart';
import '../../core/auth/auth_guard.dart';
import '../auth/login_page.dart';
import '../auth/data/auth_repository.dart';
import '../home/home_shell_page.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  final AuthRepository _authRepository = AuthRepository();
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    Log.d('开始启动流程');

    final delay = Future<void>.delayed(const Duration(milliseconds: 800));
    const timeout = Duration(seconds: 10); // 设置10秒超时

    try {
      Log.d('尝试加载本地会话...');
      final session = await _authRepository.loadSession().timeout(timeout);

      if (session != null) {
        Log.d('找到本地会话，尝试验证...');
        try {
          final user = await _authRepository.refreshCurrentUser().timeout(
            timeout,
          );
          if (user != null) {
            Log.d('用户验证成功: ${user.username}');
            await delay;
            if (!mounted || _navigated) {
              return;
            }
            _goHome();
            return;
          }
        } on AuthException catch (e) {
          Log.e('用户验证失败: $e');
          await _authRepository.logout();
        } on TimeoutException {
          Log.e('验证用户超时');
          await _authRepository.logout();
        }
      } else {
        Log.d('没有找到本地会话');
      }
    } catch (e) {
      Log.e('启动流程出错: $e');
    }

    Log.d('跳转到登录页面');
    await delay;
    if (!mounted || _navigated) {
      return;
    }
    _goLogin();
  }

  void _goHome() {
    _navigated = true;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => AuthGuard(child: const HomeShellPage()),
      ),
    );
  }

  void _goLogin() {
    _navigated = true;
    Navigator.of(
      context,
    ).pushReplacement(MaterialPageRoute(builder: (_) => const LoginPage()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7FFFE),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 临时使用简单的容器替代图片
          Center(
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(Icons.chat, size: 60, color: Colors.white),
            ),
          ),
          const Positioned(
            bottom: 64,
            left: 0,
            right: 0,
            child: Center(
              child: Text(
                'Redcode IM',
                style: TextStyle(
                  fontSize: 18,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
