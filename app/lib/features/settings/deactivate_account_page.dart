import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/widgets/im_app_bar.dart';
import '../auth/data/auth_repository.dart';
import '../auth/login_page.dart';
import 'widgets/confirm_action_dialog.dart';

typedef DeactivateAccountAction = Future<void> Function();

class DeactivateAccountPage extends StatefulWidget {
  const DeactivateAccountPage({super.key, this.deactivateAccount});

  final DeactivateAccountAction? deactivateAccount;

  @override
  State<DeactivateAccountPage> createState() => _DeactivateAccountPageState();
}

class _DeactivateAccountPageState extends State<DeactivateAccountPage> {
  bool _acknowledged = false;
  bool _submitting = false;

  Future<void> _deactivate() async {
    if (!_acknowledged || _submitting) return;
    final confirmed = await showConfirmActionDialog(
      context,
      title: '最终确认',
      message: '此操作无法撤销。请输入“注销”确认永久删除账号。',
      confirmLabel: '确认注销',
      confirmationKeyword: '注销',
    );
    if (!mounted || confirmed != true) return;

    setState(() => _submitting = true);
    try {
      await (widget.deactivateAccount ?? AuthRepository().deactivateAccount)();
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginPage()),
        (_) => false,
      );
    } on AuthException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('注销失败：$error')));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: ImAppBar(
        title: '注销账号',
        dense: true,
        leading: IconButton(
          tooltip: '返回',
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back),
        ),
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            Text(
              '注销后将永久删除以下数据',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.md),
            const _ImpactRow(text: '账号资料与登录凭证'),
            const _ImpactRow(text: '好友关系与群聊成员关系'),
            const _ImpactRow(text: '服务端保存的聊天数据'),
            const SizedBox(height: AppSpacing.lg),
            CheckboxListTile(
              key: const Key('deactivate-acknowledgement'),
              contentPadding: EdgeInsets.zero,
              value: _acknowledged,
              onChanged: (value) =>
                  setState(() => _acknowledged = value ?? false),
              title: const Text('我已了解注销影响且数据无法恢复'),
              controlAffinity: ListTileControlAffinity.leading,
            ),
            const SizedBox(height: AppSpacing.lg),
            SizedBox(
              height: AppControlSize.field,
              child: FilledButton(
                key: const Key('deactivate-account-submit'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.danger,
                ),
                onPressed: _acknowledged && !_submitting ? _deactivate : null,
                child: _submitting
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('注销账号'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ImpactRow extends StatelessWidget {
  const _ImpactRow({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        children: [
          const Icon(
            Icons.remove_circle_outline,
            size: 20,
            color: AppColors.danger,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}
