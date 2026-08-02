import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/widgets/im_app_bar.dart';
import '../../core/widgets/im_list_row.dart';
import '../../core/widgets/im_surface.dart';
import 'about_page.dart';
import 'account_security_page.dart';
import 'chat_settings_page.dart';
import 'privacy_policy_page.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: ImAppBar(
        title: '设置',
        dense: true,
        leading: IconButton(
          tooltip: '返回',
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.arrow_back),
        ),
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            _SettingsGroup(
              children: [
                _SettingsEntry(
                  icon: Icons.security_outlined,
                  title: '账号与安全',
                  subtitle: '密码与账号状态',
                  page: const AccountSecurityPage(),
                ),
                _SettingsEntry(
                  icon: Icons.chat_bubble_outline,
                  title: '聊天',
                  subtitle: '聊天背景、贴纸与本地存储',
                  page: const ChatSettingsPage(),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            _SettingsGroup(
              children: [
                _SettingsEntry(
                  icon: Icons.shield_outlined,
                  title: '隐私协议',
                  subtitle: '协议与数据使用说明',
                  page: const PrivacyPolicyPage(),
                ),
                _SettingsEntry(
                  icon: Icons.info_outline,
                  title: '关于 RedCode IM',
                  subtitle: '版本检查与意见反馈',
                  page: const AboutPage(),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsGroup extends StatelessWidget {
  const _SettingsGroup({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return ImSurface(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (var index = 0; index < children.length; index++) ...[
            children[index],
            if (index < children.length - 1)
              const Divider(height: 1, indent: 56),
          ],
        ],
      ),
    );
  }
}

class _SettingsEntry extends StatelessWidget {
  const _SettingsEntry({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.page,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget page;

  @override
  Widget build(BuildContext context) {
    return ImListRow(
      leading: SizedBox.square(
        dimension: 28,
        child: Icon(
          icon,
          size: 22,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right, size: 20),
      onTap: () =>
          Navigator.of(context).push(MaterialPageRoute(builder: (_) => page)),
      semanticLabel: title,
    );
  }
}
