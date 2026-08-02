import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/widgets/im_app_bar.dart';
import '../auth/data/auth_repository.dart';

typedef ChangePasswordAction =
    Future<void> Function(String currentPassword, String newPassword);

String? validateNewPassword(String value) {
  if (value.length < 8) return '新密码至少 8 位';
  if (!RegExp(r'[A-Za-z]').hasMatch(value) || !RegExp(r'\d').hasMatch(value)) {
    return '新密码必须同时包含字母和数字';
  }
  return null;
}

class ChangePasswordPage extends StatefulWidget {
  const ChangePasswordPage({super.key, this.changePassword});

  final ChangePasswordAction? changePassword;

  @override
  State<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends State<ChangePasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _currentController = TextEditingController();
  final _newController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _submitting = false;
  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    _currentController.dispose();
    _newController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting || !(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _submitting = true);
    try {
      final action = widget.changePassword ?? _changePassword;
      await action(_currentController.text, _newController.text);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('密码已修改')));
      Navigator.of(context).pop();
    } on AuthException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('修改密码失败：$error')));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _changePassword(String current, String next) {
    return AuthRepository().changePassword(
      oldPassword: current,
      newPassword: next,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: ImAppBar(
        title: '修改密码',
        dense: true,
        leading: IconButton(
          tooltip: '返回',
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back),
        ),
      ),
      body: SafeArea(
        top: false,
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.md),
            children: [
              _PasswordField(
                key: const Key('current-password-field'),
                controller: _currentController,
                label: '当前密码',
                obscureText: _obscureCurrent,
                onToggle: () =>
                    setState(() => _obscureCurrent = !_obscureCurrent),
                validator: (value) => (value ?? '').isEmpty ? '请输入当前密码' : null,
              ),
              const SizedBox(height: AppSpacing.md),
              _PasswordField(
                key: const Key('new-password-field'),
                controller: _newController,
                label: '新密码',
                obscureText: _obscureNew,
                onToggle: () => setState(() => _obscureNew = !_obscureNew),
                validator: (value) => validateNewPassword(value ?? ''),
              ),
              const SizedBox(height: AppSpacing.md),
              _PasswordField(
                key: const Key('confirm-password-field'),
                controller: _confirmController,
                label: '确认新密码',
                obscureText: _obscureConfirm,
                onToggle: () =>
                    setState(() => _obscureConfirm = !_obscureConfirm),
                validator: (value) =>
                    value != _newController.text ? '两次输入的密码不一致' : null,
              ),
              const SizedBox(height: AppSpacing.xl),
              SizedBox(
                height: AppControlSize.field,
                child: FilledButton(
                  key: const Key('change-password-submit'),
                  onPressed: _submitting ? null : _submit,
                  child: _submitting
                      ? const SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('确认修改'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PasswordField extends StatelessWidget {
  const _PasswordField({
    super.key,
    required this.controller,
    required this.label,
    required this.obscureText,
    required this.onToggle,
    required this.validator,
  });

  final TextEditingController controller;
  final String label;
  final bool obscureText;
  final VoidCallback onToggle;
  final String? Function(String?) validator;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      autofillHints: const [AutofillHints.password],
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        suffixIcon: IconButton(
          tooltip: obscureText ? '显示密码' : '隐藏密码',
          onPressed: onToggle,
          icon: Icon(
            obscureText
                ? Icons.visibility_outlined
                : Icons.visibility_off_outlined,
          ),
        ),
      ),
    );
  }
}
