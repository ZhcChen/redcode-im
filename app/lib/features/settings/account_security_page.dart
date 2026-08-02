import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/widgets/im_app_bar.dart';
import '../../core/widgets/im_list_row.dart';
import '../../core/widgets/im_surface.dart';
import 'change_password_page.dart';
import 'deactivate_account_page.dart';

class AccountSecurityPage extends StatelessWidget {
  const AccountSecurityPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: ImAppBar(
        title: '账号与安全',
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
            ImSurface(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  ImListRow(
                    key: const Key('change-password-entry'),
                    title: const Text('修改密码'),
                    subtitle: const Text('使用当前密码设置新密码'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const ChangePasswordPage(),
                      ),
                    ),
                  ),
                  const Divider(height: 1, indent: AppSpacing.md),
                  ImListRow(
                    key: const Key('deactivate-account-entry'),
                    title: const Text(
                      '注销账号',
                      style: TextStyle(color: AppColors.danger),
                    ),
                    subtitle: const Text('永久删除账号及关系数据'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const DeactivateAccountPage(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
