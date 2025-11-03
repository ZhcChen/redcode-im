import 'package:desktop_flutter/state/app_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';

class LoginForm extends StatefulWidget {
  const LoginForm({super.key});

  @override
  State<LoginForm> createState() => _LoginFormState();
}

class _LoginFormState extends State<LoginForm> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isAgreed = true;
  bool _isLoading = false;
  bool _passwordVisible = false;

  @override
  void dispose() {
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _onSubmit() async {
    if (!_isAgreed || !_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isLoading = true);
    await context.read<AppState>().login(
          mobile: _phoneController.text.trim(),
          password: _passwordController.text,
        );
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  void _toggleAgreement() {
    setState(() {
      _isAgreed = !_isAgreed;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Form(
      key: _formKey,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 标题和滑块
            Column(
              children: [
                Text(
                  '密码登录',
                  style: theme.textTheme.titleMedium?.copyWith(fontSize: 14),
                ),
                const SizedBox(height: 6),
                Container(
                  height: 4,
                  width: 20,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF4ECDC4), Color(0xFF44A08D)],
                    ),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 56),
            _LabeledField(
              label: '手机号',
              child: _ChatlyInput(
                controller: _phoneController,
                placeholder: '请输入手机号',
                keyboardType: TextInputType.phone,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return '请输入手机号';
                  }
                  if (value.length < 6) {
                    return '手机号格式不正确';
                  }
                  return null;
                },
              ),
            ),
            const SizedBox(height: 24),
            _LabeledField(
              label: '密码',
              child: _ChatlyInput(
                controller: _passwordController,
                placeholder: '请输入密码',
                obscureText: !_passwordVisible,
                suffix: GestureDetector(
                  onTap: () => setState(() => _passwordVisible = !_passwordVisible),
                  child: SvgPicture.asset(
                    'assets/images/icon-passwd-show.svg',
                    width: 16,
                    height: 16,
                    colorFilter: ColorFilter.mode(
                      _passwordVisible ? theme.colorScheme.primary : const Color(0xFF9B9BB0),
                      BlendMode.srcIn,
                    ),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return '请输入密码';
                  }
                  if (value.length < 6) {
                    return '密码至少 6 位';
                  }
                  return null;
                },
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 44,
              child: FilledButton(
                onPressed: _isLoading ? null : _onSubmit,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF4ECDC4),
                  disabledBackgroundColor: const Color(0xFF4ECDC4).withValues(alpha: 0.6),
                  shape: const StadiumBorder(),
                ),
                child: Text(_isLoading ? '登录中...' : '登录账号'),
              ),
            ),
            const SizedBox(height: 17),
            GestureDetector(
              onTap: _toggleAgreement,
              behavior: HitTestBehavior.opaque,
              child: Row(
                children: [
                  _AgreementRadio(selected: _isAgreed),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '注册/登陆即代表同意《用户协议》和《隐私协议》',
                      style: theme.textTheme.bodySmall,
                    ),
                  )
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LabeledField extends StatelessWidget {
  const _LabeledField({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 12),
          child: Text(
            label,
            style: const TextStyle(
                  fontSize: 14,
                  height: 1.286,
                  color: Color(0xFF333333),
                ),
          ),
        ),
        const SizedBox(height: 12),
        child,
      ],
    );
  }
}

class _ChatlyInput extends StatelessWidget {
  const _ChatlyInput({
    required this.controller,
    this.placeholder,
    this.keyboardType,
    this.obscureText = false,
    this.validator,
    this.suffix,
  });

  final TextEditingController controller;
  final String? placeholder;
  final TextInputType? keyboardType;
  final bool obscureText;
  final String? Function(String?)? validator;
  final Widget? suffix;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        obscureText: obscureText,
        validator: validator,
        decoration: InputDecoration(
          filled: true,
          fillColor: const Color(0xFFF3F7F8),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(22),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          hintText: placeholder,
          suffixIcon: suffix != null
              ? Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: suffix,
                )
              : null,
          suffixIconConstraints: const BoxConstraints(minHeight: 16, minWidth: 16),
        ),
      ),
    );
  }
}

class _AgreementRadio extends StatelessWidget {
  const _AgreementRadio({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 16,
      width: 16,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFF4ECDC4), width: 1),
        color: selected ? const Color(0xFF4ECDC4) : Colors.white,
      ),
      child: selected
          ? const Center(
              child: Icon(
                Icons.check,
                size: 10,
                color: Colors.white,
              ),
            )
          : null,
    );
  }
}
