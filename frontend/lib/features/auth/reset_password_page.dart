import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../auth/data/auth_repository.dart';

class ResetPasswordPage extends StatefulWidget {
  const ResetPasswordPage({super.key});

  @override
  State<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends State<ResetPasswordPage> {
  final _phoneController = TextEditingController();
  final _codeController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _sendingCode = false;
  bool _resettingPassword = false;

  int _secondsLeft = 0;
  Timer? _timer;

  final AuthRepository _authRepository = AuthRepository();

  @override
  void initState() {
    super.initState();
    // 自动填充当前登录用户的手机号
    _loadCurrentUser();
  }

  Future<void> _loadCurrentUser() async {
    try {
      final session = await _authRepository.loadSession();
      if (session != null && mounted) {
        setState(() {
          _phoneController.text = session.user.username;
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _timer?.cancel();
    _phoneController.dispose();
    _codeController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  // 倒计时
  void _startCountdown() {
    _timer?.cancel();
    setState(() => _secondsLeft = 60);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_secondsLeft <= 1) {
        timer.cancel();
        setState(() => _secondsLeft = 0);
      } else {
        setState(() => _secondsLeft -= 1);
      }
    });
  }

  // 发送短信验证码
  Future<void> _sendCode() async {
    if (_sendingCode || _secondsLeft > 0) {
      return;
    }

    final phone = _phoneController.text.trim();
    if (phone.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请输入手机号')));
      return;
    }

    setState(() => _sendingCode = true);
    try {
      await _authRepository.sendSmsCode(phone);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('验证码已发送，请注意查收')));
      _startCountdown();
    } on AuthException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('验证码发送失败，请稍后重试')));
    } finally {
      if (mounted) {
        setState(() => _sendingCode = false);
      }
    }
  }

  // 重置密码
  Future<void> _resetPassword() async {
    final phone = _phoneController.text.trim();
    final code = _codeController.text.trim();
    final newPassword = _newPasswordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();

    if (phone.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请输入手机号')));
      return;
    }

    if (code.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请输入验证码')));
      return;
    }

    if (newPassword.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请输入新密码')));
      return;
    }

    if (newPassword.length < 6) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('新密码至少 6 位')));
      return;
    }

    if (newPassword != confirmPassword) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('两次输入的密码不一致')));
      return;
    }

    setState(() => _resettingPassword = true);
    try {
      await _authRepository.resetPasswordWithSms(
        phone: phone,
        code: code,
        newPassword: newPassword,
      );
      if (!mounted) return;

      // 显示成功消息
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('密码重置成功，请使用新密码登录'),
          backgroundColor: Colors.green,
        ),
      );

      // 清空表单
      _codeController.clear();
      _newPasswordController.clear();
      _confirmPasswordController.clear();

      // 返回上一页
      if (mounted) {
        Navigator.of(context).pop();
      }
    } on AuthException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('重置密码失败，请稍后重试')));
    } finally {
      if (mounted) {
        setState(() => _resettingPassword = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('修改密码'),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      backgroundColor: AppColors.background,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 说明文字
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: Colors.blue.shade700,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '通过短信验证码重置密码，请输入绑定的手机号',
                      style: TextStyle(
                        color: Colors.blue.shade700,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // 手机号输入
            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: '手机号',
                hintText: '请输入绑定的手机号',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                prefixIcon: const Icon(Icons.phone),
              ),
            ),
            const SizedBox(height: 16),

            // 验证码输入
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextField(
                    controller: _codeController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: '验证码',
                      hintText: '请输入短信验证码',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      prefixIcon: const Icon(Icons.lock),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  height: 54,
                  child: ElevatedButton(
                    onPressed: (_sendingCode || _secondsLeft > 0)
                        ? null
                        : _sendCode,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                    ),
                    child: _sendingCode
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            _secondsLeft > 0 ? '${_secondsLeft}s' : '发送验证码',
                            style: const TextStyle(fontSize: 14),
                          ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // 新密码输入
            TextField(
              controller: _newPasswordController,
              obscureText: _obscureNew,
              decoration: InputDecoration(
                labelText: '新密码',
                hintText: '请输入新密码（至少6位）',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                prefixIcon: const Icon(Icons.lock),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscureNew ? Icons.visibility_off : Icons.visibility,
                  ),
                  onPressed: () => setState(() => _obscureNew = !_obscureNew),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // 确认密码输入
            TextField(
              controller: _confirmPasswordController,
              obscureText: _obscureConfirm,
              decoration: InputDecoration(
                labelText: '确认密码',
                hintText: '请再次输入新密码',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                prefixIcon: const Icon(Icons.lock),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscureConfirm ? Icons.visibility_off : Icons.visibility,
                  ),
                  onPressed: () =>
                      setState(() => _obscureConfirm = !_obscureConfirm),
                ),
              ),
            ),
            const SizedBox(height: 32),

            // 确认按钮
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _resettingPassword ? null : _resetPassword,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _resettingPassword
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        '确认重置密码',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
