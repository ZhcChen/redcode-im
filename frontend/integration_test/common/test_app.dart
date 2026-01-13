import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:frontend/app.dart';

/// 简化的测试应用
///
/// 用于 E2E 测试，避免复杂服务初始化导致的类型冲突问题。
/// 注意：此测试应用不修改任何业务代码，采用零侵入设计。
class TestApp extends StatelessWidget {
  const TestApp({super.key, this.home, this.useRealApp = false});

  final Widget? home;

  /// 是否使用真实应用（连接后端服务）
  final bool useRealApp;

  @override
  Widget build(BuildContext context) {
    // 使用真实应用
    if (useRealApp) {
      return const RedcodeApp();
    }

    // 使用模拟应用（用于隔离测试）
    return ScreenUtilInit(
      designSize: const Size(375, 812),
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (context, child) => MaterialApp(
        title: 'RedCode IM Test',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
          useMaterial3: true,
        ),
        debugShowCheckedModeBanner: false,
        home: home ?? const _SimpleLoginPage(),
      ),
    );
  }
}

/// 简化的登录页面用于测试
///
/// 此页面模拟真实登录页的 UI 结构，但不依赖业务服务。
/// 测试代码通过文本和类型选择器定位元素，无需在业务代码中添加 Key。
class _SimpleLoginPage extends StatefulWidget {
  const _SimpleLoginPage();

  @override
  State<_SimpleLoginPage> createState() => _SimpleLoginPageState();
}

class _SimpleLoginPageState extends State<_SimpleLoginPage> {
  final _mobileController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _agreed = false;

  @override
  void dispose() {
    _mobileController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('登录')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // 手机号输入框（测试通过 $(TextField).first 定位）
            TextField(
              controller: _mobileController,
              decoration: const InputDecoration(
                labelText: '手机号',
                hintText: '请输入手机号',
              ),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 16),
            // 密码输入框（测试通过 $(TextField).last 定位）
            TextField(
              controller: _passwordController,
              decoration: const InputDecoration(
                labelText: '密码',
                hintText: '请输入密码',
              ),
              obscureText: true,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                // 协议复选框（测试通过 $(Checkbox) 定位）
                Checkbox(
                  value: _agreed,
                  onChanged: (value) {
                    setState(() {
                      _agreed = value ?? false;
                    });
                  },
                ),
                const Expanded(
                  child: Text('我已阅读并同意用户协议'),
                ),
              ],
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              // 登录按钮（测试通过 $('登录账号') 定位）
              child: ElevatedButton(
                onPressed: _agreed ? _handleLogin : null,
                child: const Text('登录账号'),
              ),
            ),
            const SizedBox(height: 16),
            // 验证码登录（测试通过 $('验证码登录') 定位）
            TextButton(
              onPressed: () {
                // 切换到验证码登录
              },
              child: const Text('验证码登录'),
            ),
            // 注册账号（测试通过 $('注册账号') 定位）
            TextButton(
              onPressed: () {
                // 切换到注册
              },
              child: const Text('注册账号'),
            ),
          ],
        ),
      ),
    );
  }

  void _handleLogin() {
    final mobile = _mobileController.text;
    final password = _passwordController.text;

    if (mobile.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入手机号和密码')),
      );
      return;
    }

    // 模拟登录成功
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('登录成功')),
    );
  }
}
