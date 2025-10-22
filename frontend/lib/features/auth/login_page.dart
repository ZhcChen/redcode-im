import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/constants/app_assets.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_config.dart';
import '../home/home_shell_page.dart';
import 'data/auth_repository.dart';

enum LoginType { password, sms, register }

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  LoginType _type = LoginType.password;
  bool _agreed = false;
  bool _loading = false;
  int _smsCountdown = 0;
  bool _sendingCode = false;
  Timer? _smsTimer;

  final AuthRepository _authRepository = AuthRepository();

  final TextEditingController _mobileCtrl = TextEditingController(
    text: 'alice', // 测试账号：alice 或 bob
  );
  final TextEditingController _passwordCtrl = TextEditingController(
    text: 'password123', // 测试密码
  );
  final TextEditingController _smsCtrl = TextEditingController();
  final TextEditingController _emailCtrl = TextEditingController(
    text: 'alice@example.com',
  );

  @override
  void dispose() {
    _smsTimer?.cancel();
    _mobileCtrl.dispose();
    _passwordCtrl.dispose();
    _smsCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  String get _submitText => _type == LoginType.register ? '注册账号' : '登录账号';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7FFFE),
      body: Stack(
        children: [
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 48),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 24),
                    child: Text(
                      '你好！',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textBlack,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          '欢迎来到 Redcode IM',
                          style: TextStyle(
                            fontSize: 16,
                            color: AppColors.textBlack,
                          ),
                        ),
                        SvgPicture.asset(AppAssets.loginTitle, height: 24),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: _buildLoginCard(context),
                  ),
                ],
              ),
            ),
          ),
          if (_loading)
            Positioned.fill(
              child: ColoredBox(
                color: Colors.black.withValues(alpha: 0.12),
                child: const Center(child: CircularProgressIndicator()),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildLoginCard(BuildContext context) {
    final borderRadius = BorderRadius.circular(28);
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        borderRadius: borderRadius,
        boxShadow: const [
          BoxShadow(
            color: Color.fromRGBO(0, 0, 0, 0.08),
            blurRadius: 24,
            offset: Offset(0, 12),
          ),
        ],
        border: Border.all(color: Colors.white, width: 2),
      ),
      child: Column(
        children: [
          _buildTypeSelector(borderRadius),
          Padding(
            padding: EdgeInsets.only(
              left: 24,
              right: 24,
              top: _type == LoginType.register ? 32 : 48,
              bottom: 32,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildLabel('手机号'),
                const SizedBox(height: 12),
                _buildField(
                  controller: _mobileCtrl,
                  hint: '请输入手机号',
                  keyboardType: TextInputType.phone,
                  enabled: !_loading,
                ),
                if (_type == LoginType.register) ...[
                  const SizedBox(height: 32),
                  _buildLabel('邮箱'),
                  const SizedBox(height: 12),
                  _buildField(
                    controller: _emailCtrl,
                    hint: '请输入邮箱地址',
                    keyboardType: TextInputType.emailAddress,
                    enabled: !_loading,
                  ),
                ],
                if (_type == LoginType.password) ...[
                  const SizedBox(height: 32),
                  _buildLabel('密码'),
                  const SizedBox(height: 12),
                  _buildField(
                    controller: _passwordCtrl,
                    hint: '请输入登录密码',
                    obscureText: true,
                    enabled: !_loading,
                  ),
                ],
                if (_type != LoginType.password) ...[
                  const SizedBox(height: 32),
                  _buildLabel('验证码'),
                  const SizedBox(height: 12),
                  _buildField(
                    controller: _smsCtrl,
                    hint: '请输入验证码',
                    keyboardType: TextInputType.number,
                    suffix: _buildSmsAction(),
                    enabled: !_loading,
                  ),
                ],
                if (_type == LoginType.register) ...[
                  const SizedBox(height: 32),
                  _buildLabel('设置密码'),
                  const SizedBox(height: 12),
                  _buildField(
                    controller: _passwordCtrl,
                    hint: '请设置您的登陆密码',
                    obscureText: true,
                    enabled: !_loading,
                  ),
                ],
                const SizedBox(height: 40),
                ElevatedButton(
                  onPressed: _loading ? null : _submit,
                  child: Text(_submitText),
                ),
                const SizedBox(height: 24),
                _buildAgreeRow(),
                const SizedBox(height: 48),
                _buildSwitchRow(),
                if (_type != LoginType.register) ...[
                  const SizedBox(height: 24),
                  const Center(
                    child: Text(
                      '忘记密码',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypeSelector(BorderRadius radius) {
    return ClipRRect(
      borderRadius: BorderRadius.only(
        topLeft: radius.topLeft,
        topRight: radius.topRight,
      ),
      child: Container(
        color: const Color(0xFFF3F7F8),
        child: Row(
          children: _type == LoginType.register
              ? [_buildTypeButton(LoginType.register, '注册')]
              : [
                  _buildTypeButton(LoginType.password, '密码登录'),
                  _buildTypeButton(LoginType.sms, '验证码登录'),
                ],
        ),
      ),
    );
  }

  Widget _buildTypeButton(LoginType type, String label) {
    final isActive = _type == type;
    final isLeft = type == LoginType.password || type == LoginType.register;
    final radius = BorderRadius.only(
      topLeft: Radius.circular(isLeft ? 28 : 0),
      topRight: Radius.circular(isLeft ? 0 : 28),
    );
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _type = type),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          height: 72,
          decoration: BoxDecoration(
            color: isActive
                ? Colors.white
                : Colors.white.withValues(alpha: 0.4),
            borderRadius: radius,
          ),
          alignment: Alignment.center,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 16,
                  color: AppColors.textBlack,
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
              const SizedBox(height: 8),
              AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                height: 4,
                width: isActive ? 32 : 0,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String hint,
    bool obscureText = false,
    TextInputType? keyboardType,
    Widget? suffix,
    bool enabled = true,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      enabled: enabled,
      decoration: InputDecoration(
        hintText: hint,
        suffixIcon: suffix != null
            ? Padding(padding: const EdgeInsets.only(right: 12), child: suffix)
            : null,
        suffixIconConstraints: const BoxConstraints(maxHeight: 48),
      ),
    );
  }

  Widget _buildSmsAction() {
    final disabled = _loading || _sendingCode || _smsCountdown > 0;
    final label = _smsCountdown > 0 ? '${_smsCountdown}s' : '获取验证码';
    return TextButton(
      onPressed: disabled ? null : _requestSmsCode,
      style: TextButton.styleFrom(
        backgroundColor: const Color(0xFFDDDDDD),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        minimumSize: const Size(0, 0),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: _sendingCode
          ? const SizedBox(
              height: 16,
              width: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Text(
              label,
              style: const TextStyle(fontSize: 13, color: Colors.black87),
            ),
    );
  }

  Future<void> _requestSmsCode() async {
    final phone = _mobileCtrl.text.trim();
    if (phone.isEmpty) {
      _showMessage('请输入手机号');
      return;
    }

    if (_sendingCode || _smsCountdown > 0) {
      return;
    }

    setState(() => _sendingCode = true);
    try {
      await _authRepository.sendSmsCode(phone);
      if (mounted) {
        _showMessage('验证码已发送');
        _startSmsCountdown();
      }
    } on AuthException catch (error) {
      _showMessage(error.message);
    } catch (_) {
      _showMessage('发送验证码失败，请稍后重试');
    } finally {
      if (mounted) {
        setState(() => _sendingCode = false);
      }
    }
  }

  void _startSmsCountdown([int seconds = 60]) {
    _smsTimer?.cancel();
    setState(() => _smsCountdown = seconds);
    _smsTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_smsCountdown <= 1) {
        timer.cancel();
        if (mounted) {
          setState(() => _smsCountdown = 0);
        }
      } else if (mounted) {
        setState(() => _smsCountdown -= 1);
      }
    });
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 16,
        color: AppColors.textBlack,
        fontWeight: FontWeight.w500,
      ),
    );
  }

  Widget _buildAgreeRow() {
    return GestureDetector(
      onTap: () => setState(() => _agreed = !_agreed),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (_agreed)
            SvgPicture.asset(AppAssets.loginCheckboxSelected, height: 20)
          else
            Container(
              height: 20,
              width: 20,
              decoration: const BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Container(
                height: 16,
                width: 16,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          const SizedBox(width: 12),
          const Flexible(
            child: Text(
              '注册/登陆即代表同意《用户协议》和《隐私协议》',
              style: TextStyle(fontSize: 12, color: AppColors.textTertiary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSwitchRow() {
    final isRegister = _type == LoginType.register;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          isRegister ? '已有账号' : '新用户',
          style: const TextStyle(fontSize: 15, color: AppColors.textSecondary),
        ),
        const SizedBox(width: 4),
        GestureDetector(
          onTap: () => setState(() {
            _type = isRegister ? LoginType.password : LoginType.register;
          }),
          child: Text(
            isRegister ? '立即登录' : '立即注册',
            style: const TextStyle(
              fontSize: 15,
              color: AppColors.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _submit() async {
    if (_loading) {
      return;
    }

    if (AppConfig.useMockData) {
      final phone = _mobileCtrl.text.trim().isEmpty
          ? '13800138000'
          : _mobileCtrl.text.trim();
      final password = _passwordCtrl.text.isEmpty
          ? 'mock-pass'
          : _passwordCtrl.text;
      final email = _emailCtrl.text.trim().isEmpty
          ? '$phone@example.com'
          : _emailCtrl.text.trim();
      final code = _smsCtrl.text.trim().isEmpty
          ? '123456'
          : _smsCtrl.text.trim();

      FocusScope.of(context).unfocus();
      setState(() => _loading = true);
      try {
        if (_type == LoginType.register) {
          await _authRepository.register(
            username: phone,
            email: email,
            password: password,
          );
          await _authRepository.login(username: phone, password: password);
        } else if (_type == LoginType.sms) {
          await _authRepository.loginWithSms(phone: phone, code: code);
        } else {
          await _authRepository.login(username: phone, password: password);
        }
        if (!mounted) {
          return;
        }
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const HomeShellPage()),
          (route) => false,
        );
        return;
      } on AuthException catch (error) {
        _showMessage(error.message);
      } catch (_) {
        _showMessage('网络异常，请稍后重试');
      } finally {
        if (mounted) {
          setState(() => _loading = false);
        }
      }
    }

    if (!_agreed) {
      showDialog<void>(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('提示'),
            content: const Text('请勾选并阅读《用户协议》和《隐私协议》。'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('我知道了'),
              ),
            ],
          );
        },
      );
      return;
    }

    if (_type == LoginType.register) {
      await _handleRegister();
      return;
    }

    if (_type == LoginType.sms) {
      await _handleSmsLogin();
      return;
    }

    await _handlePasswordLogin();
  }

  Future<void> _handleRegister() async {
    final username = _mobileCtrl.text.trim();
    final email = _emailCtrl.text.trim();
    final password = _passwordCtrl.text;

    if (username.isEmpty || password.isEmpty || email.isEmpty) {
      _showMessage('请填写完整的注册信息');
      return;
    }

    if (!email.contains('@')) {
      _showMessage('请输入有效的邮箱地址');
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() => _loading = true);

    try {
      await _authRepository.register(
        username: username,
        email: email,
        password: password,
      );
      await _authRepository.login(username: username, password: password);
      if (!mounted) {
        return;
      }

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const HomeShellPage()),
        (route) => false,
      );
    } on AuthException catch (error) {
      _showMessage(error.message);
    } catch (_) {
      _showMessage('网络异常，请稍后重试');
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _handleSmsLogin() async {
    final phone = _mobileCtrl.text.trim();
    final code = _smsCtrl.text.trim();

    if (phone.isEmpty || code.isEmpty) {
      _showMessage('请输入手机号和验证码');
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() => _loading = true);

    try {
      final success = await _attemptSmsLogin(phone, code);
      if (!mounted) {
        return;
      }

      if (success) {
        _smsTimer?.cancel();
        setState(() => _smsCountdown = 0);
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const HomeShellPage()),
          (route) => false,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<bool> _attemptSmsLogin(String phone, String code) async {
    try {
      await _authRepository.loginWithSms(phone: phone, code: code);
      return true;
    } on AuthException catch (error) {
      if (_isAccountMissingError(error.message)) {
        return _autoRegisterAndLogin(phone, code);
      }
      _showMessage(error.message);
    } catch (_) {
      _showMessage('验证码登录失败，请稍后重试');
    }
    return false;
  }

  bool _isAccountMissingError(String message) {
    return message.contains('用户不存在') || message.contains('未注册');
  }

  Future<bool> _autoRegisterAndLogin(String phone, String code) async {
    final email = _buildAutoRegisterEmail(phone);
    final password = _buildAutoRegisterPassword(phone);

    try {
      await _authRepository.register(
        username: phone,
        email: email,
        password: password,
      );
    } on AuthException catch (error) {
      if (_isUserAlreadyExistsError(error.message)) {
        // 忽略该错误，后续直接重试登录
      } else {
        _showMessage(error.message);
        return false;
      }
    } catch (_) {
      _showMessage('自动注册失败，请稍后重试');
      return false;
    }

    try {
      await _authRepository.loginWithSms(phone: phone, code: code);
      return true;
    } on AuthException catch (error) {
      _showMessage(error.message);
    } catch (_) {
      _showMessage('验证码登录失败，请稍后重试');
    }
    return false;
  }

  bool _isUserAlreadyExistsError(String message) {
    return message.contains('已被使用') || message.contains('已存在');
  }

  String _buildAutoRegisterEmail(String phone) {
    final normalized = phone.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');
    final localPart = normalized.isEmpty
        ? 'user${DateTime.now().millisecondsSinceEpoch}'
        : normalized;
    return '$localPart@auto.redcode-im';
  }

  String _buildAutoRegisterPassword(String phone) {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnpqrstuvwxyz23456789';
    final random = Random();
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    final buffer = StringBuffer();

    if (digits.isNotEmpty) {
      buffer.write(
        digits.length >= 4 ? digits.substring(0, 4) : digits.padRight(4, '0'),
      );
    } else {
      buffer.write('rcim');
    }

    for (var i = 0; i < 6; i++) {
      buffer.write(chars[random.nextInt(chars.length)]);
    }

    return buffer.toString();
  }

  Future<void> _handlePasswordLogin() async {
    final username = _mobileCtrl.text.trim();
    final password = _passwordCtrl.text;

    if (username.isEmpty || password.isEmpty) {
      _showMessage('请输入完整的账号和密码');
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() => _loading = true);

    try {
      await _authRepository.login(username: username, password: password);
      if (!mounted) {
        return;
      }

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const HomeShellPage()),
        (route) => false,
      );
    } on AuthException catch (error) {
      _showMessage(error.message);
    } catch (_) {
      _showMessage('网络异常，请稍后重试');
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}
