import 'package:desktop_flutter/features/auth/widgets/login_form.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:window_manager/window_manager.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  @override
  void initState() {
    super.initState();
    _setupLoginWindowSize();
  }

  Future<void> _setupLoginWindowSize() async {
    await windowManager.setSize(const Size(400, 600));
    await windowManager.setResizable(false);
    await windowManager.center();
    await windowManager.setTitle('Chatly');
  }

  @override
  void dispose() {
    // 恢复窗口设置
    _restoreWindowSize();
    super.dispose();
  }

  Future<void> _restoreWindowSize() async {
    await windowManager.setSize(const Size(1000, 700));
    await windowManager.setResizable(true);
    await windowManager.center();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // 背景渐变色（如果 SVG 加载失败的后备方案）
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFFE8F5F4),
                    Color(0xFFD4EBE9),
                  ],
                ),
              ),
            ),
          ),
          // SVG 背景图
          Positioned.fill(
            child: SvgPicture.asset(
              'assets/images/login-bg.svg',
              fit: BoxFit.cover,
              placeholderBuilder: (context) => Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0xFFE8F5F4),
                      Color(0xFFD4EBE9),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Container(
            color: Colors.white.withValues(alpha: 0.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 52),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Hello!',
                            style: Theme.of(context).textTheme.displaySmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '欢迎来到CHATLY',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ],
                      ),
                      SvgPicture.asset(
                        'assets/images/logo-text.svg',
                        width: 115,
                        height: 24,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 40),
                Expanded(
                  child: Container(
                    margin: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                    padding: const EdgeInsets.fromLTRB(36, 16, 36, 32),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(16),
                        topRight: Radius.circular(16),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 12,
                          offset: const Offset(0, -4),
                        ),
                      ],
                    ),
                    child: const LoginForm(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
