import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/constants/app_assets.dart';
import '../../core/constants/app_colors.dart';
import '../home/home_shell_page.dart';

enum LoginType { password, sms, register }

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  LoginType _type = LoginType.password;
  bool _agreed = false;

  final TextEditingController _mobileCtrl = TextEditingController(
    text: '13800138000',
  );
  final TextEditingController _passwordCtrl = TextEditingController(
    text: 'mock-pass',
  );
  final TextEditingController _smsCtrl = TextEditingController();

  @override
  void dispose() {
    _mobileCtrl.dispose();
    _passwordCtrl.dispose();
    _smsCtrl.dispose();
    super.dispose();
  }

  String get _submitText => _type == LoginType.register ? '注册账号' : '登录账号';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage(AppAssets.splashBackground),
            fit: BoxFit.cover,
            alignment: Alignment.topCenter,
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 48),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    'Hello!',
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
                        '欢迎来到CHATLY',
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
                ),
                if (_type == LoginType.password) ...[
                  const SizedBox(height: 32),
                  _buildLabel('密码'),
                  const SizedBox(height: 12),
                  _buildField(
                    controller: _passwordCtrl,
                    hint: '请输入登录密码',
                    obscureText: true,
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
                  ),
                ],
                const SizedBox(height: 40),
                ElevatedButton(onPressed: _submit, child: Text(_submitText)),
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
  }) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
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
    return TextButton(
      onPressed: () {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('已发送验证码（mock）')));
      },
      style: TextButton.styleFrom(
        backgroundColor: const Color(0xFFDDDDDD),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        minimumSize: const Size(0, 0),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: const Text(
        '获取验证码',
        style: TextStyle(fontSize: 13, color: Colors.black87),
      ),
    );
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

  void _submit() {
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

    Navigator.of(
      context,
    ).pushReplacement(MaterialPageRoute(builder: (_) => const HomeShellPage()));
  }
}
